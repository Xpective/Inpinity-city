// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./CityBuildings.sol";
import "../libraries/CityErrors.sol";

contract BorderlineBuildings is CityBuildings {
    struct BorderlineBuilding {
        uint256 buildingId;
        bool exists;
        bool cooperative; // v1 immer true, später erweiterbar
    }

    mapping(uint256 => BorderlineBuilding) public buildingOfPlot;
    mapping(address => bool) public authorizedCallers;

    event BorderlineBuildingPlaced(
        uint256 indexed plotId,
        uint256 indexed buildingId,
        address indexed placer
    );

    modifier onlyAuthorized() {
        if (!(msg.sender == owner() || authorizedCallers[msg.sender])) {
            revert CityErrors.NotAuthorized();
        }
        _;
    }

    constructor(
        address initialOwner,
        address cityConfigAddress,
        address cityRegistryAddress,
        address cityLandAddress
    ) CityBuildings(initialOwner, cityConfigAddress, cityRegistryAddress, cityLandAddress) {}

    function setAuthorizedCaller(address caller, bool allowed) external onlyOwner {
        if (caller == address(0)) revert CityErrors.ZeroAddress();
        authorizedCallers[caller] = allowed;
    }

    function placeBuilding(uint256 plotId, uint256 buildingId) external onlyAuthorized {
        _requireValidPlotForBuilding(plotId, CityTypes.PlotType.Borderline);
        _requireEnabledDefinition(buildingId, CityTypes.PlotType.Borderline);

        if (buildingOfPlot[plotId].exists) revert CityErrors.InvalidValue();

        buildingOfPlot[plotId] = BorderlineBuilding({
            buildingId: buildingId,
            exists: true,
            cooperative: true
        });

        emit BorderlineBuildingPlaced(plotId, buildingId, msg.sender);
    }
}