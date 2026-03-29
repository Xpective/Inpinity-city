// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../libraries/CityTypes.sol";

interface ICityRegistryRead {
    function getPlotCore(uint256 plotId) external view returns (CityTypes.PlotCore memory);
}
