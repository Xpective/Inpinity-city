// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/CityTypes.sol";
import "../libraries/CityErrors.sol";
import "../libraries/CityEvents.sol";
import "./CityConfig.sol";
import "./CityRegistry.sol";

contract CityStatus is Ownable {
    CityConfig public immutable cityConfig;
    CityRegistry public immutable cityRegistry;

    mapping(uint256 => uint64) public lastActivityAtOf;
    mapping(uint256 => uint64) public lastMaintenanceAtOf;
    mapping(uint256 => CityTypes.PlotStatus) public manualStatusOverrideOf;
    mapping(address => bool) public authorizedCallers;

    constructor(
        address initialOwner,
        address cityConfigAddress,
        address cityRegistryAddress
    ) Ownable(initialOwner) {
        if (
            initialOwner == address(0) ||
            cityConfigAddress == address(0) ||
            cityRegistryAddress == address(0)
        ) {
            revert CityErrors.ZeroAddress();
        }

        cityConfig = CityConfig(cityConfigAddress);
        cityRegistry = CityRegistry(cityRegistryAddress);
    }

    modifier onlyAuthorized() {
        if (!(msg.sender == owner() || authorizedCallers[msg.sender])) {
            revert CityErrors.NotPlotOwner();
        }
        _;
    }

    function setAuthorizedCaller(address caller, bool allowed) external onlyOwner {
        if (caller == address(0)) revert CityErrors.ZeroAddress();
        authorizedCallers[caller] = allowed;
    }

    function touchActivity(uint256 plotId) external onlyAuthorized {
        cityRegistry.getPlotCore(plotId);
        lastActivityAtOf[plotId] = uint64(block.timestamp);
    }

    function recordMaintenance(uint256 plotId) external onlyAuthorized {
        cityRegistry.getPlotCore(plotId);
        lastMaintenanceAtOf[plotId] = uint64(block.timestamp);
    }

    function setManualStatus(uint256 plotId, CityTypes.PlotStatus status) external onlyOwner {
        cityRegistry.getPlotCore(plotId);
        manualStatusOverrideOf[plotId] = status;

        emit CityEvents.PlotStatusUpdated(plotId, CityTypes.PlotStatus.None, status);
    }

    function clearManualStatus(uint256 plotId) external onlyOwner {
        cityRegistry.getPlotCore(plotId);
        delete manualStatusOverrideOf[plotId];
        emit CityEvents.ManualStatusCleared(plotId);
    }

    function getDerivedStatus(uint256 plotId) public view returns (CityTypes.PlotStatus) {
        cityRegistry.getPlotCore(plotId);

        CityTypes.PlotStatus overrideStatus = manualStatusOverrideOf[plotId];
        if (overrideStatus != CityTypes.PlotStatus.None) {
            return overrideStatus;
        }

        uint256 dormantDays = cityConfig.getUintConfig(keccak256("DORMANT_THRESHOLD_DAYS"));
        uint256 decayedDays = cityConfig.getUintConfig(keccak256("DECAYED_THRESHOLD_DAYS"));
        uint256 layerDays = cityConfig.getUintConfig(keccak256("LAYER_ELIGIBLE_THRESHOLD_DAYS"));

        uint256 latestSignal = _max(lastActivityAtOf[plotId], lastMaintenanceAtOf[plotId]);

        if (latestSignal == 0) {
            return CityTypes.PlotStatus.Reserved;
        }

        uint256 elapsed = block.timestamp - latestSignal;

        if (elapsed < dormantDays * 1 days) {
            return CityTypes.PlotStatus.Active;
        }
        if (elapsed < decayedDays * 1 days) {
            return CityTypes.PlotStatus.Dormant;
        }
        if (elapsed < layerDays * 1 days) {
            return CityTypes.PlotStatus.Decayed;
        }
        return CityTypes.PlotStatus.LayerEligible;
    }

    function isLayerEligible(uint256 plotId) external view returns (bool) {
        return getDerivedStatus(plotId) == CityTypes.PlotStatus.LayerEligible;
    }

    function _max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }
}