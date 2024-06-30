// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStakingSystem {
    function setTokensClaimable(bool _enabled) external;

    function getStakedTokenIds(address _user) external view returns (uint256[] memory tokenIds);

    function stake(uint256 tokenId) external;

    function unstake(uint256 _tokenId) external;

    function claimReward(address _user) external;

    function updateReward(address _user) external returns (uint256 reward);
}