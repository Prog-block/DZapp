// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title RewardToken
 * @dev A contract for a simple ERC20 reward token.
 */
contract RewardToken is ERC20 {
    /**
     * @dev Initializes the RewardToken contract, setting the initial supply.
     */
    constructor() ERC20("Reward Token", "RT") {
        _mint(msg.sender, 1_000_000_000 * 10 ** decimals());
    }

    /**
     * @dev Mints a specified amount of tokens to the specified address.
     * @param to The address to mint tokens to.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
