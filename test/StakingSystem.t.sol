// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {StakingSystem} from "../src/StakingSystem.sol";
import {RewardToken} from "../src/RewardToken.sol";
import {DNFT} from "../src/DNFT.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract StakingSystemTest is Test {
    StakingSystem stakingSystem;
    DNFT dNFT;
    RewardToken rewardToken;
    address owner;
    address user1;
    address user2;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);

        dNFT = new DNFT();
        rewardToken = new RewardToken();
        stakingSystem = new StakingSystem(dNFT, rewardToken);

        dNFT.transferOwnership(owner);
    }

    function test_UpdateUnstakingPeriod() public {
        assertEq(
            stakingSystem.unstakingPeriod(),
            7 days,
            "Unstaking period should be updated"
        );

        uint256 newPeriod = 14 days;

        vm.prank(owner);
        stakingSystem.updateUnstakingPeriod(newPeriod);

        assertEq(
            stakingSystem.unstakingPeriod(),
            newPeriod,
            "Unstaking period should be updated"
        );
    }

    function test_UpdateRewardRate() public {
        assertEq(
            stakingSystem.rewardRate(),
            1 ether,
            "Reward rate should be updated"
        );

        uint256 newRate = 2 ether;

        vm.prank(owner);
        stakingSystem.updateRewardRate(newRate);

        assertEq(
            stakingSystem.rewardRate(),
            newRate,
            "Reward rate should be updated"
        );
    }

    function test_GetUserStakedTokens() public {
        stakeNft(0);
        uint256[] memory stakedTokens = stakingSystem.getUserStakedTokens(
            user1
        );

        assertEq(stakedTokens.length, 1, "User1 should have 1 staked token");
        assertEq(stakedTokens[0], 0, "Staked token ID should be 0");
    }

    function test_StakeAsTokenOwner() public {
        dNFT.safeMint(user1);

        assertEq(dNFT.ownerOf(0), user1, "Minted token should belong to user1");

        vm.startPrank(user1);
        dNFT.approve(address(stakingSystem), 0);
        vm.expectEmit(true, true, true, true);
        emit StakingSystem.Staked(user1, 0);
        stakingSystem.stake(0);
        vm.stopPrank();

        (
            address tokenOwner,
            uint256 stakedBlock,
            uint256 unstakeRequestTime
        ) = stakingSystem.tokenData(0);

        assertEq(tokenOwner, user1, "Token owner should be user1");
        assertEq(
            stakedBlock,
            block.number,
            "Staked block should be the current block number"
        );
        assertEq(unstakeRequestTime, 0, "Unstake request time should be zero");
        assertEq(
            stakingSystem.stakedTotal(),
            1,
            "Total staked tokens should be 1"
        );

        uint256[] memory stakedTokens = stakingSystem.getUserStakedTokens(
            user1
        );
        assertEq(stakedTokens.length, 1, "User1 should have 2 staked tokens");
        assertEq(stakedTokens[0], 0, "First staked token ID should be 0");
    }

    function test_RequestUnstake() public {
        stakeNft(0);

        vm.stopPrank();
        (, , uint256 unstakeRequestTimeBefore) = stakingSystem.tokenData(0);

        assertEq(
            unstakeRequestTimeBefore,
            0,
            "Unstake request time should be set to current block timestamp"
        );

        vm.startPrank(user1);
        vm.expectEmit(true, true, true, true);
        emit StakingSystem.UnstakeRequested(user1, 0, block.timestamp);
        stakingSystem.requestUnstake(0);
        vm.stopPrank();

        (, , uint256 unstakeRequestTimeAfter) = stakingSystem.tokenData(0);

        assertEq(
            unstakeRequestTimeAfter,
            block.timestamp,
            "Unstake request time should be set to current block timestamp"
        );
    }

    function test_RevertRequestUnstake_NotTokenOwner() public {
        stakeNft(0);

        vm.startPrank(user2);
        vm.expectRevert(StakingSystem.NotTokenOwner.selector);
        stakingSystem.requestUnstake(0);
        vm.stopPrank();
    }

    function test_RevertUnstakeWhen_NotTokenOwner() public {
        stakeNft(0);

        vm.startPrank(user2);
        vm.expectRevert(StakingSystem.NotTokenOwner.selector);
        stakingSystem.unstake(0);
        vm.stopPrank();
    }

    function test_RevertUnstakeWhen_UnstakingRequestNotInitiated() public {
        stakeNft(0);
        vm.startPrank(user1);
        vm.warp(block.timestamp + 8 days);
        vm.expectRevert(StakingSystem.UnstakeRequestNotFound.selector);
        stakingSystem.unstake(0);
        vm.stopPrank();
    }

    function test_RevertUnstakeWhen_UnstakingPeriodNotYetPassed() public {
        stakeNft(0);

        vm.startPrank(user1);
        stakingSystem.requestUnstake(0);
        vm.warp(block.timestamp + 2);
        vm.expectRevert(StakingSystem.UnstakingPeriodNotYetPassed.selector);
        stakingSystem.unstake(0);
        vm.stopPrank();
    }

    function test_UnstakeAfterUnstakingPeriod() public {
        stakeNft(0);
        stakeNft(1);

        vm.startPrank(user1);
        stakingSystem.requestUnstake(0);
        vm.warp(block.timestamp + 8 days); // Move forward in time

        (address tokenOwnerBefore, , ) = stakingSystem.tokenData(0);
        assertEq(tokenOwnerBefore, user1, "Token owner should user1");
        assertEq(
            stakingSystem.stakedTotal(),
            2,
            "Total staked tokens should be 2"
        );

        vm.expectEmit(true, true, true, true);
        emit StakingSystem.Unstaked(user1, 0);
        stakingSystem.unstake(0);
        vm.stopPrank();

        (address tokenOwnerAfter, , ) = stakingSystem.tokenData(0);
        assertEq(
            tokenOwnerAfter,
            address(0),
            "Token owner should be reset to address(0)"
        );
        assertEq(
            stakingSystem.stakedTotal(),
            1,
            "Total staked tokens should be 0"
        );

        uint256[] memory stakedTokens = stakingSystem.getUserStakedTokens(
            user1
        );
        assertEq(stakedTokens.length, 1, "User1 should have 2 staked tokens");
    }

    function test_ClaimReward() public {
        stakeNft(0);

        vm.warp(block.timestamp + 8 days); // Move forward in time
        vm.roll(100);
        stakingSystem.claimReward(user1);

        uint256 reward = rewardToken.balanceOf(user1);
        assertEq(reward, 99 * 1e18, "Reward should be correctly calculated");

        (uint256 lastClaimedBlock, uint256 cumulativeReward) = stakingSystem
            .userInfo(user1);

        assertEq(
            lastClaimedBlock,
            block.number,
            "Last claimed block should be updated"
        );
        assertEq(
            cumulativeReward,
            0,
            "Cumulative reward should be reset to zero"
        );
    }

    function stakeNft(uint256 i) internal {
        dNFT.safeMint(user1);
        vm.startPrank(user1);
        dNFT.approve(address(stakingSystem), i);
        stakingSystem.stake(i);
        vm.stopPrank();
    }
}
