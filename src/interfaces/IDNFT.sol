// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IDNFT {
    function safeMint(address to) external;

    function ownerOf(uint256 tokenId) external view returns (address owner);

    function approve(address to, uint256 tokenId) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
}
