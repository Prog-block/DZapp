// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {RewardToken} from "./RewardToken.sol";
import {DNFT} from "./DNFT.sol";

contract StakingSystem is IERC721Receiver, ReentrancyGuard {
    // Constants
    uint256 public constant UNSTAKING_PERIOD = 7 days;
    uint256 public constant TOKEN = 10e18;
    uint256 public constant REWARD_RATE = 1 ether; // 1 RT per block

    // Immutable variables
    DNFT public immutable dNFT;
    RewardToken public immutable rewardToken;
    uint256 public immutable INITIAL_BLOCK_NUMBER;

    // State variables
    uint256 public stakedTotal;

    // Structs
    struct TokenData {
        address tokenOwner;
        uint256 tokenDepositTime;
        uint256 tokenBlockNumber;
    }

    // Mappings
    mapping(uint256 => TokenData) public tokenIdMap;
    mapping(address => uint256[]) public userTokenIds;
    mapping(address => uint256) public userClaimedReward;

    // Events
    event Staked(address indexed owner, uint256 amount);
    event Unstaked(address indexed owner, uint256 amount);

    // Custom Errors
    error NotTokenOwner();
    error UnstakingPeriodNotYetPassed();
    error NoRewardsYet();

    /**
     * @dev Initializes the contract setting the dNFT and rewardToken.
     * @param _dNFT The address of the dNFT contract.
     * @param _rewardToken The address of the reward token contract.
     */
    constructor(DNFT _dNFT, RewardToken _rewardToken) {
        dNFT = _dNFT;
        rewardToken = _rewardToken;
        INITIAL_BLOCK_NUMBER = block.number;
    }

    /**
     * @dev Returns the list of staked token IDs for a user.
     * @param _user The address of the user.
     * @return _tokenIds Array of staked token IDs.
     */
    function getStakedTokenIds(
        address _user
    ) external view returns (uint256[] memory _tokenIds) {
        return userTokenIds[_user];
    }

    /**
     * @dev Stakes a token.
     * @param _tokenId The ID of the token to stake.
     */
    function stake(uint256 _tokenId) external nonReentrant {
        _stake(msg.sender, _tokenId);
    }

    /**
     * @dev Unstakes a token.
     * @param _tokenId The ID of the token to unstake.
     */
    function unstake(uint256 _tokenId) public nonReentrant {
        TokenData memory tokenData = tokenIdMap[_tokenId];
        if (tokenData.tokenOwner != msg.sender) {
            revert NotTokenOwner();
        }
        if (block.timestamp - tokenData.tokenDepositTime <= UNSTAKING_PERIOD) {
            revert UnstakingPeriodNotYetPassed();
        }
        claimReward(msg.sender);
        _unstake(msg.sender, _tokenId);
    }

    /**
     * @dev Updates the reward for a user.
     * @param _user The address of the user.
     * @return reward The updated reward amount.
     */
    function updateReward(address _user) public view returns (uint256 reward) {
        uint256[] memory ids = userTokenIds[_user];
        for (uint256 i = 0; i < ids.length; i++) {
            reward +=
                (block.number - tokenIdMap[ids[i]].tokenBlockNumber) *
                REWARD_RATE;
        }
        reward -= userClaimedReward[_user];
    }

    /**
     * @dev Claims the reward for a user.
     * @param _user The address of the user.
     */
    function claimReward(address _user) private {
        uint256 reward = updateReward(_user);

        userClaimedReward[_user] += reward;
        rewardToken.mint(_user, reward);
    }

    /**
     * @dev Internal function to stake a token.
     * @param _user The address of the user.
     * @param _tokenId The ID of the token to stake.
     */
    function _stake(address _user, uint256 _tokenId) internal {
        dNFT.safeTransferFrom(_user, address(this), _tokenId);

        tokenIdMap[_tokenId] = TokenData(_user, block.timestamp, block.number);
        userTokenIds[_user].push(_tokenId);
        emit Staked(_user, _tokenId);
        stakedTotal++;
    }

    /**
     * @dev Internal function to unstake a token.
     * @param _user The address of the user.
     * @param _tokenId The ID of the token to unstake.
     */
    function _unstake(address _user, uint256 _tokenId) internal {
        delete tokenIdMap[_tokenId];
        uint256[] storage ids = userTokenIds[_user];
        uint256 idsLength = ids.length;

        for (uint i; i < idsLength; i++) {
            if (ids[i] == _tokenId) {
                // Swap the element with the last element
                ids[i] = ids[idsLength - 1];
                // Remove the last element
                ids.pop();
            }
        }
        stakedTotal--;

        dNFT.safeTransferFrom(address(this), _user, _tokenId);

        emit Unstaked(_user, _tokenId);
    }

    // function stakeBatch(uint256[] memory tokenIds) external nonReentrant {
    //     for (uint256 i = 0; i < tokenIds.length; i++) {
    //         _stake(msg.sender, tokenIds[i]);
    //     }
    // }

    // function unstakeBatch(uint256[] memory tokenIds) public {
    //     for (uint256 i = 0; i < tokenIds.length; i++) {
    //         if (tokenOwner[tokenIds[i]] == msg.sender) {
    //             _unstake(msg.sender, tokenIds[i]);
    //             claimReward(msg.sender, tokenIds[i]);
    //         }
    //     }
    // }

    // function unstakeAll() public {
    //     uint256[] memory tokenIds = stakers[msg.sender].tokenIds;
    //     for (uint256 i = 0; i < tokenIds.length; i++) {
    //         _unstake(msg.sender, tokenIds[i]);
    //     }
    //     claimReward(msg.sender);
    // }
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
