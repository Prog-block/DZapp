// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DNFT
 * @dev A contract for a simple ERC721 non-fungible token with minting functionality.
 */
contract DNFT is ERC721, Ownable {
    uint256 private _tokenIdCounter;

    /**
     * @dev Initializes the DNFT contract, setting the name and symbol of the token.
     */
    constructor() ERC721("DNFT", "DNFT") Ownable(msg.sender) {}

    /**
     * @dev Returns the base URI for token metadata.
     * @return The base URI string.
     */
    function _baseURI() internal pure override returns (string memory) {
        return "ipfs::/ipfs_link/";
    }

    /**
     * @dev Safely mints a new DNFT token to the specified address.
     * @param to The address to mint the token to.
     */
    function safeMint(address to) public onlyOwner {
        _safeMint(to, _tokenIdCounter++);
    }
}