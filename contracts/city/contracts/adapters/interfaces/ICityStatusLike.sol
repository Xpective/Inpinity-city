// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal status-like interface.
/// @dev Replace later if your live CityStatus uses different naming.
interface ICityStatusLike {
    function isPlotDormant(uint256 plotId) external view returns (bool);
    function isPlotDecayed(uint256 plotId) external view returns (bool);
    function isPlotLayerEligibleBlocked(uint256 plotId) external view returns (bool);
}