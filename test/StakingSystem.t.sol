// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
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
        dNFT.transferOwnership(owner);

        stakingSystem = new StakingSystem(dNFT, new RewardToken());
    }

    function test_StakeAsTokenOwner() public {
        dNFT.safeMint(user1);

        assertEq(dNFT.ownerOf(0), user1);
        vm.startPrank(user1);
        dNFT.approve(address(stakingSystem), 0);
        vm.expectEmit(true, true, true, true);
        emit StakingSystem.Staked(user1, 0);
        stakingSystem.stake(0);
        vm.stopPrank();
        (
            address tokenOwner,
            uint256 tokenDepositTime,
            uint256 tokenBlockNumber
        ) = stakingSystem.tokenIdMap(0);
        assertEq(tokenOwner, user1);
        assertEq(tokenDepositTime, block.timestamp);
        assertEq(tokenBlockNumber, block.number);
        assertEq(stakingSystem.stakedTotal(), 1);

        uint256[] memory stakedTokens = stakingSystem.getStakedTokenIds(user1);
        assertEq(stakedTokens.length, 1);
        assertEq(stakedTokens[0], 0);
    }

    function test_RevertUnstakeWhen_NotTokenOwner() public {
        dNFT.safeMint(user1);

        vm.startPrank(user1);
        dNFT.approve(address(stakingSystem), 0);
        stakingSystem.stake(0);
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert(StakingSystem.NotTokenOwner.selector);
        stakingSystem.unstake(0);
        vm.stopPrank();
    }

    function test_RevertUnstakeWhen_UnstakingPeriodNotYetPassed() public {
        dNFT.safeMint(user1);

        vm.startPrank(user1);
        dNFT.approve(address(stakingSystem), 0);
        stakingSystem.stake(0);
        vm.warp(block.timestamp + 2);
        vm.expectRevert(StakingSystem.UnstakingPeriodNotYetPassed.selector);
        stakingSystem.unstake(0);
        vm.stopPrank();
    }

    function test_UnstakeAfterUnstakingPeriod() public {
        dNFT.safeMint(user1);

        vm.startPrank(user1);
        dNFT.approve(address(stakingSystem), 0);
        stakingSystem.stake(0);
        vm.warp(block.timestamp + 7 days + 1); // Move forward in time

        vm.expectEmit(true, true, true, true);
        emit StakingSystem.Unstaked(user1, 0);
        stakingSystem.unstake(0);

        vm.stopPrank();

        (address tokenOwner, , ) = stakingSystem.tokenIdMap(1);
        assertEq(tokenOwner, address(0));
        assertEq(stakingSystem.stakedTotal(), 0);

        uint256[] memory stakedTokens = stakingSystem.getStakedTokenIds(user1);
        assertEq(stakedTokens.length, 0);
    }

    // function testClaimRewards() public {
    //     dNFT.safeMint(user1);

    //     vm.startPrank(user1);
    //     dNFT.approve(address(stakingSystem), 0);
    //     stakingSystem.stake(0);
    //     vm.warp(block.timestamp + 7 days + 1); // Move forward in time
    //     stakingSystem.unstake(00);

    //     uint256 reward = stakingSystem.updateReward(user1);
    //     assert(reward > 0);

    //     stakingSystem.claimReward(user1);

    //     uint256 rewardBalance = rewardToken.balanceOf(user1);
    //     assertEq(rewardBalance, reward);
    //     assertEq(stakingSystem.updateReward(user1), 0);

    //     vm.stopPrank();
    // }

    function testUpdateReward() public {
        dNFT.safeMint(user1);

        vm.startPrank(user1);
        dNFT.approve(address(stakingSystem), 0);

        stakingSystem.stake(0);

        vm.warp(block.timestamp + 8 days); // Move forward in time
        vm.roll(100);
        uint256 reward = stakingSystem.updateReward(user1);
        assertEq(reward, 99 * 1e18);

        vm.stopPrank();
    }
}

