// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DNFT is ERC721, Ownable {
    constructor() ERC721("DNFT", "DNFT") Ownable(msg.sender) {}
    uint256 private _tokenIdCounter;

    function _baseURI() internal pure override returns (string memory) {
        return "ipfs::/ipfs_link/";
    }

    function safeMint(address to) public onlyOwner {
        _safeMint(to, _tokenIdCounter++);
    }

}
