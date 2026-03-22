// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../interfaces/buildings/ICityPlacementCoreAdapter.sol";

contract CityPlacementReadAdapter {
    ICityPlacementCoreAdapter public immutable coreAdapter;

    struct PlotPlacementView {
        uint256 plotId;
        address owner;
        bool personalPlot;
        bool completed;
        bool eligible;
        uint8 faction;
        uint8 districtKind;
    }

    constructor(address coreAdapter_) {
        require(coreAdapter_ != address(0), "adapter=0");
        coreAdapter = ICityPlacementCoreAdapter(coreAdapter_);
    }

    function getPlotPlacementView(
        uint256 plotId
    ) external view returns (PlotPlacementView memory) {
        return PlotPlacementView({
            plotId: plotId,
            owner: coreAdapter.getPlotOwner(plotId),
            personalPlot: coreAdapter.isPersonalPlot(plotId),
            completed: coreAdapter.isPlotCompleted(plotId),
            eligible: coreAdapter.isPlotEligibleForPlacement(plotId),
            faction: coreAdapter.getPlotFaction(plotId),
            districtKind: coreAdapter.getPlotDistrictKind(plotId)
        });
    }
}