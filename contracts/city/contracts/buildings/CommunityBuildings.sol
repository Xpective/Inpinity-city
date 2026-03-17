// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./CityBuildings.sol";

contract CommunityBuildings is CityBuildings {
    struct CommunityBuilding {
        uint256 buildingId;
        bool exists;
        bool active;
    }

    mapping(uint256 => CommunityBuilding) public buildingOfPlot;

    event CommunityBuildingPlanned(uint256 indexed plotId, uint256 indexed buildingId);
    event CommunityBuildingActivated(uint256 indexed plotId);

    constructor(
        address initialOwner,
        address cityConfigAddress,
        address cityRegistryAddress,
        address cityLandAddress
    ) CityBuildings(initialOwner, cityConfigAddress, cityRegistryAddress, cityLandAddress) {}

    function planBuilding(uint256 plotId, uint256 buildingId) external onlyOwner {
        _requireValidPlotForBuilding(plotId, CityTypes.PlotType.Community);
        _requireEnabledDefinition(buildingId, CityTypes.PlotType.Community);

        buildingOfPlot[plotId] = CommunityBuilding({
            buildingId: buildingId,
            exists: true,
            active: false
        });

        emit CommunityBuildingPlanned(plotId, buildingId);
    }

    function activateBuilding(uint256 plotId) external onlyOwner {
        if (!buildingOfPlot[plotId].exists) revert CityErrors.InvalidValue();
        buildingOfPlot[plotId].active = true;

        emit CommunityBuildingActivated(plotId);
    }
}