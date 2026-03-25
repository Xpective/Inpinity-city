/* FILE: contracts/city/contracts/libraries/CollectiveBuildingTypes.sol */
/* TYPE: collective building enums / structs / helper rules — NOT Personal, NOT NFT */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./CityBuildingTypes.sol";

/// @title CollectiveBuildingTypes
/// @notice Shared enums, structs and helper rules for Community / Borderline / Nexus buildings.
/// @dev Keeps the collective layer separate from PersonalBuildings and CityBuildingNFTV1.
///      All base resources 0..9 remain publicly tradable by default.
///      Crafted outputs (materia / enchantments / weapons / later crafted items) are restricted by default.
library CollectiveBuildingTypes {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint8 internal constant MAX_COLLECTIVE_LEVEL = 7;
    uint8 internal constant BASE_RESOURCE_SLOT_COUNT = 10;
    uint8 internal constant MAX_BASE_RESOURCE_ID = 9;

    /*//////////////////////////////////////////////////////////////
                                 ENUMS
    //////////////////////////////////////////////////////////////*/

    enum CommunityBuildingKind {
        None,
        FactionTreasury,
        GrandMarketHall,
        CivicBastion,
        AcademyArchive,
        CommonsGranary,
        ForgeworksFoundry
    }

    enum CommunityBuildingBranch {
        None,

        // FactionTreasury
        WarChestBranch,
        AetherReserveBranch,
        GrantOfficeBranch,

        // GrandMarketHall
        BazaarWing,
        AuctionWing,
        CommonsExchangeWing,

        // CivicBastion
        WatchGridBranch,
        ShieldRelayBranch,
        MercenaryLiaisonBranch,

        // AcademyArchive
        GreatLibraryBranch,
        BlueprintBranch,
        StrategicCommandBranch,

        // CommonsGranary
        FoodReserveBranch,
        HarvestExchangeBranch,
        PublicCommonsBranch,

        // ForgeworksFoundry
        IndustrialWorksBranch,
        ProjectFoundryBranch,
        MasterWorksBranch
    }

    enum BorderlineBuildingKind {
        None,
        BorderGatehouse,
        TreatyHall,
        NeutralExchangePost,
        JointWatchRelay,
        ConflictBufferTower,
        ReconstructionYard
    }

    enum BorderlineBuildingBranch {
        None,
        AccessControlBranch,
        TreatyBranch,
        NeutralTradeBranch,
        JointWatchBranch,
        BufferBranch,
        ReconstructionBranch
    }

    enum NexusBuildingKind {
        None,
        NexusCore,
        NexusSignalSpire,
        NexusArchive,
        NexusExchangeHub
    }

    enum NexusBuildingBranch {
        None,
        CoreBranch,
        SignalBranch,
        ArchiveBranch,
        ExchangeBranch
    }

    enum CollectiveCampaignState {
        None,
        Draft,
        Funding,
        Funded,
        Building,
        Failed,
        Cancelled,
        Closed
    }

    enum CollectiveBuildingState {
        None,
        Planned,
        Inactive,
        Active,
        Upgrading,
        Damaged,
        EmergencyLocked,
        Archived
    }

    enum CollectiveCustodyMode {
        None,
        ContractCustodied,
        GovernanceCustodied,
        CityCustodied
    }

    enum CollectiveGovernanceRole {
        None,
        Steward,
        Treasurer,
        Defender,
        Builder,
        MarketKeeper,
        Archivist
    }

    enum CollectiveContributionPermission {
        None,
        FactionOnly,
        DualFactionOnly,
        OpenCity
    }

    enum CollectiveMarketScope {
        None,
        FactionInternalGoods,
        DualFactionGoods,
        OpenCityResources,
        OpenCityGoods
    }

    enum CollectiveTreasuryMode {
        None,
        NonRaidable,
        RaidableProtected,
        RaidableOpen
    }

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct CollectiveIdentity {
        CityBuildingTypes.BuildingCategory category;
        CommunityBuildingKind communityKind;
        BorderlineBuildingKind borderlineKind;
        NexusBuildingKind nexusKind;
        uint8 level;
        uint8 primaryFaction;
        uint8 secondaryFaction;
        uint256 plotId;
        uint256 campaignId;
        uint64 createdAt;
        uint64 activatedAt;
        address custodyHolder;
        CollectiveCustodyMode custodyMode;
    }

    struct CollectiveGovernancePolicy {
        CollectiveContributionPermission contributionPermission;
        CollectiveMarketScope marketScope;
        CollectiveTreasuryMode treasuryMode;
        bool publicBaseResources;
        bool craftedItemsRestricted;
        bool emergencyShieldCapable;
        bool upgradeRequiresConsensus;
    }

    struct CollectiveFundingLedger {
        uint256[BASE_RESOURCE_SLOT_COUNT] targetAmounts;
        uint256[BASE_RESOURCE_SLOT_COUNT] raisedAmounts;
        uint32 contributorCount;
        CollectiveCampaignState campaignState;
        uint64 campaignOpenedAt;
        uint64 campaignClosedAt;
        uint64 fundedAt;
        uint64 activatedAt;
    }

    struct CollectiveCoreStats {
        uint32 totalUpgrades;
        uint32 prestigeScore;
        uint32 historyScore;
        uint32 totalContributors;
        uint32 totalGovernanceActions;
        uint32 totalDefenseActivations;
        uint32 totalMarketCycles;
        uint32 totalResearchCycles;
        uint32 totalTreasuryDeposits;
    }

    struct CollectiveTradePolicy {
        bool allowBaseResources;
        bool allowCraftedItems;
        bool allowMateria;
        bool allowEnchantments;
        bool allowWeapons;
        bool factionInternalCraftedOnly;
        bool dualFactionCraftedOnly;
    }

    /*//////////////////////////////////////////////////////////////
                              VALIDATION
    //////////////////////////////////////////////////////////////*/

    function isValidCollectiveLevel(uint8 level) internal pure returns (bool) {
        return level >= 1 && level <= MAX_COLLECTIVE_LEVEL;
    }

    function isValidCommunityKind(
        CommunityBuildingKind kind
    ) internal pure returns (bool) {
        return kind >= CommunityBuildingKind.FactionTreasury
            && kind <= CommunityBuildingKind.ForgeworksFoundry;
    }

    function isValidBorderlineKind(
        BorderlineBuildingKind kind
    ) internal pure returns (bool) {
        return kind >= BorderlineBuildingKind.BorderGatehouse
            && kind <= BorderlineBuildingKind.ReconstructionYard;
    }

    function isValidNexusKind(
        NexusBuildingKind kind
    ) internal pure returns (bool) {
        return kind >= NexusBuildingKind.NexusCore
            && kind <= NexusBuildingKind.NexusExchangeHub;
    }

    function isValidCommunityBranch(
        CommunityBuildingBranch branch
    ) internal pure returns (bool) {
        return branch >= CommunityBuildingBranch.WarChestBranch
            && branch <= CommunityBuildingBranch.MasterWorksBranch;
    }

    function isValidBorderlineBranch(
        BorderlineBuildingBranch branch
    ) internal pure returns (bool) {
        return branch >= BorderlineBuildingBranch.AccessControlBranch
            && branch <= BorderlineBuildingBranch.ReconstructionBranch;
    }

    function isValidNexusBranch(
        NexusBuildingBranch branch
    ) internal pure returns (bool) {
        return branch >= NexusBuildingBranch.CoreBranch
            && branch <= NexusBuildingBranch.ExchangeBranch;
    }

    function isCollectiveCategory(
        CityBuildingTypes.BuildingCategory category
    ) internal pure returns (bool) {
        return
            category == CityBuildingTypes.BuildingCategory.Community ||
            category == CityBuildingTypes.BuildingCategory.Borderline ||
            category == CityBuildingTypes.BuildingCategory.Nexus;
    }

    function isFactionGovernedCategory(
        CityBuildingTypes.BuildingCategory category
    ) internal pure returns (bool) {
        return category == CityBuildingTypes.BuildingCategory.Community;
    }

    function isDualFactionCategory(
        CityBuildingTypes.BuildingCategory category
    ) internal pure returns (bool) {
        return category == CityBuildingTypes.BuildingCategory.Borderline;
    }

    function isCitywideCategory(
        CityBuildingTypes.BuildingCategory category
    ) internal pure returns (bool) {
        return category == CityBuildingTypes.BuildingCategory.Nexus;
    }

    function supportsCrowdfunding(
        CityBuildingTypes.BuildingCategory category
    ) internal pure returns (bool) {
        return
            category == CityBuildingTypes.BuildingCategory.Community ||
            category == CityBuildingTypes.BuildingCategory.Borderline;
    }

    function requiresCustody(
        CityBuildingTypes.BuildingCategory category
    ) internal pure returns (bool) {
        return isCollectiveCategory(category);
    }

    function isPubliclyTradableBaseResource(
        uint8 resourceId
    ) internal pure returns (bool) {
        return resourceId <= MAX_BASE_RESOURCE_ID;
    }

    function areCraftedOutputsPublicByDefault() internal pure returns (bool) {
        return false;
    }

    /*//////////////////////////////////////////////////////////////
                         GOVERNANCE DEFAULTS
    //////////////////////////////////////////////////////////////*/

    function defaultGovernancePolicy(
        CityBuildingTypes.BuildingCategory category
    ) internal pure returns (CollectiveGovernancePolicy memory policy) {
        if (category == CityBuildingTypes.BuildingCategory.Community) {
            policy = CollectiveGovernancePolicy({
                contributionPermission: CollectiveContributionPermission.FactionOnly,
                marketScope: CollectiveMarketScope.FactionInternalGoods,
                treasuryMode: CollectiveTreasuryMode.RaidableProtected,
                publicBaseResources: true,
                craftedItemsRestricted: true,
                emergencyShieldCapable: true,
                upgradeRequiresConsensus: true
            });
        } else if (category == CityBuildingTypes.BuildingCategory.Borderline) {
            policy = CollectiveGovernancePolicy({
                contributionPermission: CollectiveContributionPermission.DualFactionOnly,
                marketScope: CollectiveMarketScope.DualFactionGoods,
                treasuryMode: CollectiveTreasuryMode.RaidableProtected,
                publicBaseResources: true,
                craftedItemsRestricted: true,
                emergencyShieldCapable: true,
                upgradeRequiresConsensus: true
            });
        } else if (category == CityBuildingTypes.BuildingCategory.Nexus) {
            policy = CollectiveGovernancePolicy({
                contributionPermission: CollectiveContributionPermission.OpenCity,
                marketScope: CollectiveMarketScope.OpenCityGoods,
                treasuryMode: CollectiveTreasuryMode.NonRaidable,
                publicBaseResources: true,
                craftedItemsRestricted: true,
                emergencyShieldCapable: true,
                upgradeRequiresConsensus: false
            });
        }
    }

    function defaultTradePolicy(
        CityBuildingTypes.BuildingCategory category
    ) internal pure returns (CollectiveTradePolicy memory policy) {
        policy.allowBaseResources = true;
        policy.allowCraftedItems = false;
        policy.allowMateria = false;
        policy.allowEnchantments = false;
        policy.allowWeapons = false;

        if (category == CityBuildingTypes.BuildingCategory.Community) {
            policy.factionInternalCraftedOnly = true;
            policy.dualFactionCraftedOnly = false;
        } else if (category == CityBuildingTypes.BuildingCategory.Borderline) {
            policy.factionInternalCraftedOnly = false;
            policy.dualFactionCraftedOnly = true;
        } else if (category == CityBuildingTypes.BuildingCategory.Nexus) {
            policy.factionInternalCraftedOnly = false;
            policy.dualFactionCraftedOnly = false;
        }
    }

    /*//////////////////////////////////////////////////////////////
                         FACTION ACCESS HELPERS
    //////////////////////////////////////////////////////////////*/

    function canOperateCommunityBuilding(
        uint8 actorFaction,
        uint8 buildingFaction
    ) internal pure returns (bool) {
        return actorFaction != 0 && actorFaction == buildingFaction;
    }

    function canOperateBorderlineBuilding(
        uint8 actorFaction,
        uint8 primaryFaction,
        uint8 secondaryFaction
    ) internal pure returns (bool) {
        return
            actorFaction != 0 &&
            (actorFaction == primaryFaction || actorFaction == secondaryFaction);
    }

    /*//////////////////////////////////////////////////////////////
                          BRANCH MATCHING RULES
    //////////////////////////////////////////////////////////////*/

    function communityBranchMatchesKind(
        CommunityBuildingKind kind,
        CommunityBuildingBranch branch
    ) internal pure returns (bool) {
        if (branch == CommunityBuildingBranch.None) return true;

        if (kind == CommunityBuildingKind.FactionTreasury) {
            return
                branch == CommunityBuildingBranch.WarChestBranch ||
                branch == CommunityBuildingBranch.AetherReserveBranch ||
                branch == CommunityBuildingBranch.GrantOfficeBranch;
        }

        if (kind == CommunityBuildingKind.GrandMarketHall) {
            return
                branch == CommunityBuildingBranch.BazaarWing ||
                branch == CommunityBuildingBranch.AuctionWing ||
                branch == CommunityBuildingBranch.CommonsExchangeWing;
        }

        if (kind == CommunityBuildingKind.CivicBastion) {
            return
                branch == CommunityBuildingBranch.WatchGridBranch ||
                branch == CommunityBuildingBranch.ShieldRelayBranch ||
                branch == CommunityBuildingBranch.MercenaryLiaisonBranch;
        }

        if (kind == CommunityBuildingKind.AcademyArchive) {
            return
                branch == CommunityBuildingBranch.GreatLibraryBranch ||
                branch == CommunityBuildingBranch.BlueprintBranch ||
                branch == CommunityBuildingBranch.StrategicCommandBranch;
        }

        if (kind == CommunityBuildingKind.CommonsGranary) {
            return
                branch == CommunityBuildingBranch.FoodReserveBranch ||
                branch == CommunityBuildingBranch.HarvestExchangeBranch ||
                branch == CommunityBuildingBranch.PublicCommonsBranch;
        }

        if (kind == CommunityBuildingKind.ForgeworksFoundry) {
            return
                branch == CommunityBuildingBranch.IndustrialWorksBranch ||
                branch == CommunityBuildingBranch.ProjectFoundryBranch ||
                branch == CommunityBuildingBranch.MasterWorksBranch;
        }

        return false;
    }

    function borderlineBranchMatchesKind(
        BorderlineBuildingKind kind,
        BorderlineBuildingBranch branch
    ) internal pure returns (bool) {
        if (branch == BorderlineBuildingBranch.None) return true;

        if (kind == BorderlineBuildingKind.BorderGatehouse) {
            return branch == BorderlineBuildingBranch.AccessControlBranch;
        }
        if (kind == BorderlineBuildingKind.TreatyHall) {
            return branch == BorderlineBuildingBranch.TreatyBranch;
        }
        if (kind == BorderlineBuildingKind.NeutralExchangePost) {
            return branch == BorderlineBuildingBranch.NeutralTradeBranch;
        }
        if (kind == BorderlineBuildingKind.JointWatchRelay) {
            return branch == BorderlineBuildingBranch.JointWatchBranch;
        }
        if (kind == BorderlineBuildingKind.ConflictBufferTower) {
            return branch == BorderlineBuildingBranch.BufferBranch;
        }
        if (kind == BorderlineBuildingKind.ReconstructionYard) {
            return branch == BorderlineBuildingBranch.ReconstructionBranch;
        }

        return false;
    }

    function nexusBranchMatchesKind(
        NexusBuildingKind kind,
        NexusBuildingBranch branch
    ) internal pure returns (bool) {
        if (branch == NexusBuildingBranch.None) return true;

        if (kind == NexusBuildingKind.NexusCore) {
            return branch == NexusBuildingBranch.CoreBranch;
        }
        if (kind == NexusBuildingKind.NexusSignalSpire) {
            return branch == NexusBuildingBranch.SignalBranch;
        }
        if (kind == NexusBuildingKind.NexusArchive) {
            return branch == NexusBuildingBranch.ArchiveBranch;
        }
        if (kind == NexusBuildingKind.NexusExchangeHub) {
            return branch == NexusBuildingBranch.ExchangeBranch;
        }

        return false;
    }

    /*//////////////////////////////////////////////////////////////
                         BRANCH LEVEL GATING
    //////////////////////////////////////////////////////////////*/

    function minLevelForCommunityBranch(
        CommunityBuildingBranch branch
    ) internal pure returns (uint8) {
        if (
            branch == CommunityBuildingBranch.WarChestBranch ||
            branch == CommunityBuildingBranch.BazaarWing ||
            branch == CommunityBuildingBranch.WatchGridBranch ||
            branch == CommunityBuildingBranch.GreatLibraryBranch ||
            branch == CommunityBuildingBranch.FoodReserveBranch ||
            branch == CommunityBuildingBranch.IndustrialWorksBranch
        ) {
            return 3;
        }

        if (
            branch == CommunityBuildingBranch.AetherReserveBranch ||
            branch == CommunityBuildingBranch.GrantOfficeBranch ||
            branch == CommunityBuildingBranch.AuctionWing ||
            branch == CommunityBuildingBranch.CommonsExchangeWing ||
            branch == CommunityBuildingBranch.ShieldRelayBranch ||
            branch == CommunityBuildingBranch.MercenaryLiaisonBranch ||
            branch == CommunityBuildingBranch.BlueprintBranch ||
            branch == CommunityBuildingBranch.StrategicCommandBranch ||
            branch == CommunityBuildingBranch.HarvestExchangeBranch ||
            branch == CommunityBuildingBranch.PublicCommonsBranch ||
            branch == CommunityBuildingBranch.ProjectFoundryBranch
        ) {
            return 5;
        }

        if (branch == CommunityBuildingBranch.MasterWorksBranch) {
            return 7;
        }

        return 1;
    }

    function minLevelForBorderlineBranch(
        BorderlineBuildingBranch branch
    ) internal pure returns (uint8) {
        if (
            branch == BorderlineBuildingBranch.AccessControlBranch ||
            branch == BorderlineBuildingBranch.TreatyBranch ||
            branch == BorderlineBuildingBranch.NeutralTradeBranch
        ) {
            return 3;
        }

        if (
            branch == BorderlineBuildingBranch.JointWatchBranch ||
            branch == BorderlineBuildingBranch.BufferBranch ||
            branch == BorderlineBuildingBranch.ReconstructionBranch
        ) {
            return 5;
        }

        return 1;
    }

    function minLevelForNexusBranch(
        NexusBuildingBranch branch
    ) internal pure returns (uint8) {
        if (
            branch == NexusBuildingBranch.CoreBranch ||
            branch == NexusBuildingBranch.SignalBranch
        ) {
            return 3;
        }

        if (
            branch == NexusBuildingBranch.ArchiveBranch ||
            branch == NexusBuildingBranch.ExchangeBranch
        ) {
            return 5;
        }

        return 1;
    }

    function canChooseCommunityBranch(
        CommunityBuildingKind kind,
        uint8 level,
        CommunityBuildingBranch branch
    ) internal pure returns (bool) {
        if (!isValidCommunityKind(kind)) return false;
        if (!isValidCollectiveLevel(level)) return false;
        if (!communityBranchMatchesKind(kind, branch)) return false;
        return level >= minLevelForCommunityBranch(branch);
    }

    function canChooseBorderlineBranch(
        BorderlineBuildingKind kind,
        uint8 level,
        BorderlineBuildingBranch branch
    ) internal pure returns (bool) {
        if (!isValidBorderlineKind(kind)) return false;
        if (!isValidCollectiveLevel(level)) return false;
        if (!borderlineBranchMatchesKind(kind, branch)) return false;
        return level >= minLevelForBorderlineBranch(branch);
    }

    function canChooseNexusBranch(
        NexusBuildingKind kind,
        uint8 level,
        NexusBuildingBranch branch
    ) internal pure returns (bool) {
        if (!isValidNexusKind(kind)) return false;
        if (!isValidCollectiveLevel(level)) return false;
        if (!nexusBranchMatchesKind(kind, branch)) return false;
        return level >= minLevelForNexusBranch(branch);
    }
}