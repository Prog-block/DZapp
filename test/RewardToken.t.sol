// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RewardToken} from "../src/RewardToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract RewardTokenTest is Test {
    RewardToken private rewardToken;
    address private owner = address(0x1);
    address private nonOwner = address(0x456);
    address private recipient = address(0x2);

    function setUp() public {
        vm.prank(owner);
        rewardToken = new RewardToken();
    }

    function testInitialSetup() public view {
        assertEq(
            rewardToken.name(),
            "Reward Token",
            "The contract name should be 'Reward Token'"
        );
        assertEq(
            rewardToken.symbol(),
            "RT",
            "The contract symbol should be 'RT'"
        );

        uint256 initialSupply = 1_000_000_000 * 10 ** rewardToken.decimals();

        assertEq(
            rewardToken.totalSupply(),
            initialSupply,
            "The initial supply should be 1,000,000,000 tokens"
        );
        assertEq(
            rewardToken.balanceOf(owner),
            initialSupply,
            "The owner's initial balance should be 1,000,000,000 tokens"
        );
    }

    function testMintingFunctionality() public {
        uint256 mintAmount = 1000 * 10 ** rewardToken.decimals();

        vm.prank(owner);
        rewardToken.mint(recipient, mintAmount);

        assertEq(
            rewardToken.balanceOf(recipient),
            mintAmount,
            "The recipient's balance should be 1000 tokens"
        );

        uint256 totalSupplyAfterMinting = rewardToken.totalSupply();
        uint256 expectedTotalSupply = 1_000_000_000 *
            10 ** rewardToken.decimals() +
            mintAmount;
        assertEq(
            totalSupplyAfterMinting,
            expectedTotalSupply,
            "The total supply should be updated correctly after minting"
        );
    }

}
