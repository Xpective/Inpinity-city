/* FILE: contracts/city/contracts/interfaces/ICityBuildingNFTView.sol */
/* TYPE: minimal NFT read-only view interface — NOT PersonalBuildings */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../libraries/CityBuildingTypes.sol";

/// @title ICityBuildingNFTView
/// @notice Minimal read-only NFT view interface for placement-adjacent contracts and adapters.
interface ICityBuildingNFTView {
    function ownerOf(uint256 tokenId) external view returns (address);

    function getBuildingCore(
        uint256 buildingId
    ) external view returns (CityBuildingTypes.BuildingCore memory);

    function getBuildingState(
        uint256 buildingId
    ) external view returns (CityBuildingTypes.BuildingState);

    function isArchived(uint256 buildingId) external view returns (bool);

    function isMigrationPrepared(uint256 buildingId) external view returns (bool);
}