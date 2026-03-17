// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./CityTypes.sol";

library LayerLogic {
    function canBecomeLayerEligible(
        CityTypes.PlotStatus status
    ) internal pure returns (bool) {
        return status == CityTypes.PlotStatus.Decayed ||
               status == CityTypes.PlotStatus.LayerEligible;
    }

    function isInactiveStatus(
        CityTypes.PlotStatus status
    ) internal pure returns (bool) {
        return status == CityTypes.PlotStatus.Dormant ||
               status == CityTypes.PlotStatus.Decayed ||
               status == CityTypes.PlotStatus.LayerEligible;
    }

    function nextLayerCount(uint32 currentLayerCount) internal pure returns (uint32) {
        return currentLayerCount + 1;
    }

    function historicScoreForNewLayer(uint32 currentLayerCount) internal pure returns (uint32) {
        return 10 + currentLayerCount;
    }
}