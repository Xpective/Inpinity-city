// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./CityBuildings.sol";

contract PersonalBuildings is CityBuildings {
    struct PersonalBuilding {
        uint256 buildingId;
        uint256 level;
        bool exists;
    }

    mapping(uint256 => PersonalBuilding) public buildingOfPlot;

    event PersonalBuildingPlaced(uint256 indexed plotId, uint256 indexed buildingId);
    event PersonalBuildingUpgraded(uint256 indexed plotId, uint256 newLevel);

    constructor(
        address initialOwner,
        address cityConfigAddress,
        address cityRegistryAddress,
        address cityLandAddress
    ) CityBuildings(initialOwner, cityConfigAddress, cityRegistryAddress, cityLandAddress) {}

    function placeBuilding(uint256 plotId, uint256 buildingId) external {
        CityTypes.PlotCore memory plot = cityRegistry.getPlotCore(plotId);
        _requireValidPlotForBuilding(plotId, CityTypes.PlotType.Personal);
        _requireEnabledDefinition(buildingId, CityTypes.PlotType.Personal);

        if (plot.owner != msg.sender) revert CityErrors.NotPlotOwner();
        if (buildingOfPlot[plotId].exists) revert CityErrors.InvalidValue();

        buildingOfPlot[plotId] = PersonalBuilding({
            buildingId: buildingId,
            level: 1,
            exists: true
        });

        emit PersonalBuildingPlaced(plotId, buildingId);
    }

    function upgradeBuilding(uint256 plotId) external {
        CityTypes.PlotCore memory plot = cityRegistry.getPlotCore(plotId);
        if (plot.owner != msg.sender) revert CityErrors.NotPlotOwner();
        if (!buildingOfPlot[plotId].exists) revert CityErrors.InvalidValue();

        buildingOfPlot[plotId].level += 1;
        emit PersonalBuildingUpgraded(plotId, buildingOfPlot[plotId].level);
    }
}