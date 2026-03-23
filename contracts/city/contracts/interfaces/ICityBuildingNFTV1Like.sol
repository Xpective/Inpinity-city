// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../libraries/CityBuildingTypes.sol";

/// @title ICityBuildingNFTV1Like
/// @notice Minimales Schreib-/Leseinterface für Placement- und Logic-Contracts.
interface ICityBuildingNFTV1Like {
    function ownerOf(uint256 tokenId) external view returns (address);

    function getBuildingCore(
        uint256 buildingId
    ) external view returns (CityBuildingTypes.BuildingCore memory);

    function getBuildingMeta(
        uint256 buildingId
    ) external view returns (CityBuildingTypes.BuildingMeta memory);

    function getBuildingState(
        uint256 buildingId
    ) external view returns (CityBuildingTypes.BuildingState);

    function isArchived(uint256 buildingId) external view returns (bool);

    function isMigrationPrepared(uint256 buildingId) external view returns (bool);

    function setPlaced(uint256 buildingId, bool placed) external;
}