// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal registry-like interface for plot owner resolution.
/// @dev Adjust later if your live Registry exposes a different read.
interface ICityRegistryLike {
    function ownerOfPlot(uint256 plotId) external view returns (address);
}