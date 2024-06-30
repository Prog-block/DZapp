// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DNFT} from "../src/DNFT.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DNFTTest is Test {
    DNFT private dNFT;
    address private owner = address(0x123);
    address private nonOwner = address(0x456);

    function setUp() public {
        // Labeling the addresses for better logging
        vm.label(owner, "Owner");
        vm.label(nonOwner, "NonOwner");

        // Deploy the contract
        dNFT = new DNFT();
        dNFT.transferOwnership(owner);
    }

    function test_SafeMintByOwner() public {
        // Start a prank from the owner address
        vm.prank(owner);
        dNFT.safeMint(owner);

        // Assert that the token has been minted
        assertEq(dNFT.balanceOf(owner), 1);
        assertEq(dNFT.ownerOf(0), owner);
    }
    function test_RevertSafeMintWhen_CallerNonOwner() public {
        // Check initial conditions before attempting mint
        assertEq(dNFT.balanceOf(nonOwner), 0);

        // Start a prank from the non-owner address
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                nonOwner
            )
        );
        vm.prank(nonOwner);
        dNFT.safeMint(nonOwner);

        // Verify that no token was minted to the nonOwner
        assertEq(dNFT.balanceOf(nonOwner), 0);
    }

}
