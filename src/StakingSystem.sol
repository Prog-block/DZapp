// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {RewardToken} from "./RewardToken.sol";
import {DNFT} from "./DNFT.sol";

/**
 * @title StakingSystem
 * @dev A contract for staking ERC721 tokens and earning rewards.
 */
contract StakingSystem is IERC721Receiver, ReentrancyGuard, Ownable {
    // Immutable variables
    DNFT public immutable dNFT;
    RewardToken public immutable rewardToken;
    uint256 public immutable INITIAL_BLOCK_NUMBER;

    // State variables
    uint256 public stakedTotal;
    uint256 public unstakingPeriod = 7 days;
    uint256 public rewardRate = 1 ether; // 1 RT per block

    // Structs
    struct TokenData {
        address tokenOwner;
        uint256 stakedBlock;
        uint256 unstakeRequestTime;
    }

    struct UserInfo {
        uint256 lastClaimedBlock;
        uint256 cumulativeReward;
        uint256[] tokenIds;
    }

    // Mappings
    mapping(uint256 => TokenData) public tokenData;
    mapping(address => UserInfo) private userInfo;

    // Events
    event Staked(address indexed owner, uint256 tokenId);
    event UnstakeRequested(
        address indexed owner,
        uint256 tokenId,
        uint256 requestTime
    );
    event Unstaked(address indexed owner, uint256 tokenId);
    event RewardClaimed(address indexed user, uint256 reward);

    // Custom Errors
    error NotTokenOwner();
    error UnstakingPeriodNotYetPassed();
    error UnstakeRequestNotFound();

    /**
     * @dev Initializes the contract with DNFT and RewardToken instances.
     * @param _dNFT The DNFT contract instance.
     * @param _rewardToken The RewardToken contract instance.
     */
    constructor(DNFT _dNFT, RewardToken _rewardToken) Ownable(msg.sender) {
        dNFT = _dNFT;
        rewardToken = _rewardToken;
        INITIAL_BLOCK_NUMBER = block.number;
    }

    /**
     * @dev Updates the unstaking period.
     * @param _newPeriod The new unstaking period in seconds.
     */
    function updateUnstakingPeriod(uint256 _newPeriod) external onlyOwner {
        unstakingPeriod = _newPeriod;
    }

    /**
     * @dev Updates the reward rate.
     * @param _newRate The new reward rate per block.
     */
    function updateRewardRate(uint256 _newRate) external onlyOwner {
        rewardRate = _newRate;
    }

    /**
     * @dev Gets the list of staked token IDs for a user.
     * @param user The address of the user.
     * @return _tokenIds Array of staked token IDs.
     */
    function getUserStakedTokens(
        address user
    ) external view returns (uint256[] memory) {
        return userInfo[user].tokenIds;
    }

    /**
     * @dev Stakes an ERC721 token.
     * @param tokenId The ID of the token to stake.
     */
    function stake(uint256 tokenId) external {
        dNFT.safeTransferFrom(msg.sender, address(this), tokenId);

        tokenData[tokenId] = TokenData({
            tokenOwner: msg.sender,
            stakedBlock: block.number,
            unstakeRequestTime: 0
        });

        userInfo[msg.sender].tokenIds.push(tokenId);

        stakedTotal++;
        emit Staked(msg.sender, tokenId);
    }

    /**
     * @dev Requests to unstake an ERC721 token.
     * @param tokenId The ID of the token to unstake.
     */
    function requestUnstake(uint256 tokenId) external {
        TokenData storage data = tokenData[tokenId];

        if (data.tokenOwner != msg.sender) {
            revert NotTokenOwner();
        }

        data.unstakeRequestTime = block.timestamp;
        emit UnstakeRequested(msg.sender, tokenId, block.timestamp);
    }

    /**
     * @dev Unstakes an ERC721 token after the unstaking period has passed.
     * @param tokenId The ID of the token to unstake.
     */
    function unstake(uint256 tokenId) external {
        TokenData memory data = tokenData[tokenId];

        if (data.tokenOwner != msg.sender) {
            revert NotTokenOwner();
        }
        if (data.unstakeRequestTime == 0) {
            revert UnstakeRequestNotFound();
        }
        if (block.timestamp - data.unstakeRequestTime <= unstakingPeriod) {
            revert UnstakingPeriodNotYetPassed();
        }

        claimReward(msg.sender);
        _unstake(tokenId);
    }

    /**
     * @dev Claims the accumulated reward for a user.
     * @param claimer The address of the user claiming the reward.
     */
    function claimReward(address claimer) public {
        _updateReward(claimer);
        uint256 reward = userInfo[claimer].cumulativeReward;

        if (reward > 0) {
            userInfo[claimer].cumulativeReward = 0;
            rewardToken.mint(claimer, reward);
            emit RewardClaimed(claimer, reward);
        }
    }

    /**
     * @dev Updates the reward accumulation for a user.
     * @param user The address of the user.
     */
    function _updateReward(address user) internal {
        uint256 reward = _calculateReward(user);
        if (reward > 0) {
            userInfo[user].cumulativeReward += reward;
            userInfo[user].lastClaimedBlock = block.number;
        }
    }

    /**
     * @dev Calculates the pending reward for a user.
     * @param user The address of the user.
     * @return reward The pending reward amount.
     */
    function _calculateReward(address user) internal view returns (uint256) {
        uint256 reward = 0;
        UserInfo memory userDetail = userInfo[user];
        uint256 lastClaimed = userDetail.lastClaimedBlock;
        uint256 currentBlock = block.number;
        uint256 tokenIdsLength = userDetail.tokenIds.length;

        for (uint256 i = 0; i < tokenIdsLength; ) {
            uint256 tokenId = userDetail.tokenIds[i];
            uint256 startBlock = tokenData[tokenId].stakedBlock > lastClaimed
                ? tokenData[tokenId].stakedBlock
                : lastClaimed;
            reward += (currentBlock - startBlock) * rewardRate;

            unchecked {
                i++;
            }
        }

        return reward;
    }

    /**
     * @dev Performs the unstaking of an ERC721 token.
     * @param tokenId The ID of the token to unstake.
     */
    function _unstake(uint256 tokenId) private nonReentrant {
        address user = tokenData[tokenId].tokenOwner;

        uint256[] memory tokens = userInfo[user].tokenIds;
        uint256 tokensLength = tokens.length;

        for (uint256 i = 0; i < tokensLength; ) {
            if (tokens[i] == tokenId) {
                userInfo[user].tokenIds[i] = tokens[tokens.length - 1];
                userInfo[user].tokenIds.pop();
                break;
            }
            unchecked {
                i++;
            }
        }

        delete tokenData[tokenId];
        stakedTotal--;

        dNFT.safeTransferFrom(address(this), user, tokenId);
        emit Unstaked(user, tokenId);
    }

    /**
     * @dev Standard ERC721 receiver function.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
