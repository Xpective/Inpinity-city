// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ICityPlacementCoreAdapter
/// @notice Stable adapter interface for personal building placement policy.
/// @dev Hides unstable core contract signatures behind one normalized interface.
interface ICityPlacementCoreAdapter {
    function isPersonalPlot(uint256 plotId) external view returns (bool);

    function isPlotOwner(address user, uint256 plotId) external view returns (bool);

    function isPlotCompleted(uint256 plotId) external view returns (bool);

    function isPlotEligibleForPlacement(uint256 plotId) external view returns (bool);

    function isDistrictAllowedForPersonalBuilding(
        uint256 plotId,
        uint8 buildingType
    ) external view returns (bool);

    function isFactionAllowedForPersonalBuilding(
        address user,
        uint256 plotId,
        uint8 buildingType
    ) external view returns (bool);

    function getPlotFaction(uint256 plotId) external view returns (uint8);

    function getPlotDistrictKind(uint256 plotId) external view returns (uint8);

    function getPlotOwner(uint256 plotId) external view returns (address);
}