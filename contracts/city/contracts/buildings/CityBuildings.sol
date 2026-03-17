// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/CityTypes.sol";
import "../libraries/CityErrors.sol";
import "../interfaces/ICityLand.sol";
import "../core/CityRegistry.sol";
import "../core/CityConfig.sol";

abstract contract CityBuildings is Ownable {
    struct BuildingDefinition {
        uint256 id;
        string name;
        CityTypes.PlotType allowedPlotType;
        uint256 oilCost;
        uint256 lemonsCost;
        uint256 ironCost;
        uint256 goldCost;
        bool enabled;
    }

    CityConfig public immutable cityConfig;
    CityRegistry public immutable cityRegistry;
    ICityLand public cityLand;

    mapping(uint256 => BuildingDefinition) internal _buildingDefinitions;

    event BuildingDefinitionSet(
        uint256 indexed buildingId,
        string name,
        CityTypes.PlotType allowedPlotType,
        bool enabled
    );

    constructor(
        address initialOwner,
        address cityConfigAddress,
        address cityRegistryAddress,
        address cityLandAddress
    ) Ownable(initialOwner) {
        if (
            initialOwner == address(0) ||
            cityConfigAddress == address(0) ||
            cityRegistryAddress == address(0) ||
            cityLandAddress == address(0)
        ) {
            revert CityErrors.ZeroAddress();
        }

        cityConfig = CityConfig(cityConfigAddress);
        cityRegistry = CityRegistry(cityRegistryAddress);
        cityLand = ICityLand(cityLandAddress);
    }

    function setBuildingDefinition(
        uint256 buildingId,
        string calldata name,
        CityTypes.PlotType allowedPlotType,
        uint256 oilCost,
        uint256 lemonsCost,
        uint256 ironCost,
        uint256 goldCost,
        bool enabled
    ) external onlyOwner {
        if (buildingId == 0) revert CityErrors.InvalidValue();
        if (bytes(name).length == 0) revert CityErrors.InvalidValue();
        if (allowedPlotType == CityTypes.PlotType.None) revert CityErrors.InvalidPlotType();

        _buildingDefinitions[buildingId] = BuildingDefinition({
            id: buildingId,
            name: name,
            allowedPlotType: allowedPlotType,
            oilCost: oilCost,
            lemonsCost: lemonsCost,
            ironCost: ironCost,
            goldCost: goldCost,
            enabled: enabled
        });

        emit BuildingDefinitionSet(buildingId, name, allowedPlotType, enabled);
    }

    function getBuildingDefinition(uint256 buildingId)
        external
        view
        returns (BuildingDefinition memory)
    {
        return _buildingDefinitions[buildingId];
    }

    function _requireValidPlotForBuilding(uint256 plotId, CityTypes.PlotType expectedType) internal view {
        CityTypes.PlotCore memory plot = cityRegistry.getPlotCore(plotId);

        if (plot.plotType != expectedType) revert CityErrors.InvalidPlotType();
        if (!cityLand.isPlotFullyCompleted(plotId)) revert CityErrors.InvalidValue();
    }

    function _requireEnabledDefinition(uint256 buildingId, CityTypes.PlotType expectedType)
        internal
        view
        returns (BuildingDefinition memory def)
    {
        def = _buildingDefinitions[buildingId];
        if (!def.enabled) revert CityErrors.InvalidValue();
        if (def.allowedPlotType != expectedType) revert CityErrors.InvalidPlotType();
    }
}