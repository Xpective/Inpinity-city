// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal districts-like interface.
/// @dev Replace with your final live read if different.
interface ICityDistrictsLike {
    function getPlotDistrictKind(uint256 plotId) external view returns (uint8);
    function getPlotFaction(uint256 plotId) external view returns (uint8);
    function isPersonalPlot(uint256 plotId) external view returns (bool);
    function plotExists(uint256 plotId) external view returns (bool);
}