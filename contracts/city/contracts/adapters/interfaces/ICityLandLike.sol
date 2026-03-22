// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal land-like interface for plot completion checks.
interface ICityLandLike {
    function isPlotFullyCompleted(uint256 plotId) external view returns (bool);
}