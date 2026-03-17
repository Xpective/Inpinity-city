// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./CityTypes.sol";

library CityEvents {
    event ConfigInitialized(address indexed admin);
    event CoreAddressSet(bytes32 indexed key, address indexed value);
    event UintConfigSet(bytes32 indexed key, uint256 value);

    event CityKeyTokenSet(address indexed user, uint256 indexed tokenId);
    event FactionChosen(address indexed user, CityTypes.Faction indexed faction);

    event PersonalPlotReserved(
        address indexed owner,
        uint256 indexed plotId,
        uint8 indexed slotIndex,
        CityTypes.Faction faction
    );

    event CommunityPlotReserved(
        uint256 indexed plotId,
        CityTypes.CommunityBuildingKind indexed buildingKind
    );

    event PlotStatusUpdated(
        uint256 indexed plotId,
        CityTypes.PlotStatus oldStatus,
        CityTypes.PlotStatus newStatus
    );

    event PlotOwnerTransferred(
        uint256 indexed plotId,
        address indexed oldOwner,
        address indexed newOwner
    );

    event QubiqContributed(
        uint256 indexed plotId,
        uint32 indexed x,
        uint32 indexed y,
        address contributor,
        uint256 oil,
        uint256 lemons,
        uint256 iron
    );

    event QubiqCompleted(
        uint256 indexed plotId,
        uint32 indexed x,
        uint32 indexed y,
        bool usedAether
    );

    event AetherUsed(
        uint256 indexed plotId,
        uint32 indexed x,
        uint32 indexed y,
        address user
    );

    event PlotHistoryInitialized(
        uint256 indexed plotId,
        address indexed firstBuilder,
        CityTypes.Faction indexed faction,
        bool genesisEra
    );

    event OwnershipTransferRecorded(uint256 indexed plotId, uint32 transferCount);
    event LayerAdded(uint256 indexed plotId, uint32 newLayerCount);
    event AetherUseRecorded(uint256 indexed plotId, uint32 totalAetherUses);

    event ManualStatusCleared(uint256 indexed plotId);
}