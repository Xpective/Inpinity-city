// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../libraries/CityBuildingTypes.sol";

interface ICityBuildingNFTView {
    function ownerOf(uint256 tokenId) external view returns (address);

    function getBuildingCore(
        uint256 buildingId
    ) external view returns (CityBuildingTypes.BuildingCore memory);

    function getBuildingState(
        uint256 buildingId
    ) external view returns (CityBuildingTypes.BuildingState);

    function isArchived(uint256 buildingId) external view returns (bool);
}