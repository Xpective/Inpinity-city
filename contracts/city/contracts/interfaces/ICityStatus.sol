// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../libraries/CityTypes.sol";

interface ICityStatus {
    function touchActivity(uint256 plotId) external;
    function recordMaintenance(uint256 plotId) external;
    function getDerivedStatus(uint256 plotId) external view returns (CityTypes.PlotStatus);
    function isLayerEligible(uint256 plotId) external view returns (bool);
}