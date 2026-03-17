// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IFarmingV6 {
    struct FarmInfo {
        uint256 startTime;
        uint256 lastAccrualTime;
        uint256 lastClaimTime;
        uint256 boostExpiry;
        uint256 stopTime;
        bool isActive;
    }

    function startFarming(uint256 tokenId) external;
    function stopFarming(uint256 tokenId) external;
    function claimResources(uint256 tokenId) external;
    function buyBoost(uint256 tokenId, uint256 daysAmount) external;

    function getFarmState(uint256 tokenId) external view returns (FarmInfo memory);
    function getFarmStatusCode(uint256 tokenId) external view returns (uint8);
    function getFarmStatusCodeV6(uint256 tokenId) external view returns (uint8);

    function getPending(uint256 tokenId, uint8 resourceId) external view returns (uint256);
    function getAllPending(uint256 tokenId) external view returns (uint256[10] memory);
    function getClaimableResources(uint256 tokenId)
        external
        view
        returns (uint8[] memory ids, uint256[] memory amounts);

    function getBoostMultiplier(uint256 tokenId) external view returns (uint256);
    function isClaimMature(uint256 tokenId) external view returns (bool);
    function secondsUntilClaimable(uint256 tokenId) external view returns (uint256);

    function hasBoost(uint256 tokenId) external view returns (bool);
    function inpiToken() external view returns (address);
    function inpiPool() external view returns (address);
    function pitronePool() external view returns (address);
    function treasury() external view returns (address);
    function resourceToken() external view returns (address);
    function partnershipContract() external view returns (address);
    function inpinityNFT() external view returns (address);
}