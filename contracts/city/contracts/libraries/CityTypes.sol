// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library CityTypes {
    enum PlotType {
        None,
        Personal,
        Community,
        Borderline
    }

    enum Faction {
        None,
        Inpinity,
        Inphinity,
        Neutral
    }

    enum PlotStatus {
        None,
        Reserved,
        Active,
        Dormant,
        Decayed,
        LayerEligible
    }

    enum CommunityBuildingKind {
        None,
        Marketplace,
        TownHall,
        PoliceStation,
        ResearchCenter,
        GrandForge,
        EnergyCore,
        TreasuryVault,
        TransitGate,
        MedicalBay,
        BlueprintHall
    }

    struct PlotSlot {
        uint256 plotId;
        bool occupied;
    }

    struct PlotCore {
        uint256 id;
        PlotType plotType;
        Faction faction;
        PlotStatus status;
        address owner;
        uint32 width;
        uint32 height;
        uint64 createdAt;
        bool exists;
    }

    struct PlotHistory {
        address firstBuilder;
        uint32 layerCount;
        uint64 lastStatusChangeAt;
        uint64 lastActivityAt;
        uint32 ownershipTransfers;
        uint32 aetherUses;
    }
}