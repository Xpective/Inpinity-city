// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title CityBuildingTypes
/// @notice Shared enums, structs, constants and helper functions for Inpinity City building systems.
/// @dev V1 focuses on Personal Buildings. Community / Borderline / Nexus contracts can reuse the shared types.
library CityBuildingTypes {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint8 internal constant MAX_BUILDING_LEVEL = 7;
    uint256 internal constant UNPLACED_PLOT_ID = 0;
    uint256 internal constant MAX_CUSTOM_NAME_LENGTH = 32;

    uint32 internal constant VERSION_TAG_V1 = 1;
    uint32 internal constant VERSION_TAG_V2 = 2;

    /*//////////////////////////////////////////////////////////////
                                 ENUMS
    //////////////////////////////////////////////////////////////*/

    /// @notice The 7 canonical personal building base types.
    enum PersonalBuildingType {
        None,
        Residence,
        FarmingHub,
        Forge,
        Warehouse,
        MarketStall,
        GuardTower,
        ResearchLab
    }

    /// @notice Shared category family for future non-tradable city assets.
    enum BuildingCategory {
        None,
        Personal,
        Community,
        Borderline,
        Nexus
    }

    /// @notice Internal building state only.
    /// @dev Plot lifecycle limitations are computed outside from CityStatus / placement layer.
    enum BuildingState {
        None,
        Unplaced,
        PlacedActive,
        PlacedPaused,
        PlacedDamaged,
        Archived
    }

    enum BuildingSpecialization {
        None,

        // Residence
        GalleryHouse,
        TrophyHall,

        // Forge
        WeaponForge,
        RelicForge,
        ComponentForge,
        MasterForge,

        // Warehouse
        ResourceVault,
        TradeDepot,
        FortressVault,
        MerchantVault,

        // Market Stall
        MerchantHouse,

        // Guard Tower
        RadarTower,
        DefenseTower,
        MercenaryTower,
        ShieldTower,

        // Research Lab
        MasterLab
    }

    enum FactionVariant {
        None,
        InpinityVariant,
        InphinityVariant
    }

    /// @notice Runtime mode after combining building state with plot lifecycle.
    enum EffectiveBuildingMode {
        None,
        Unplaced,
        Active,
        Paused,
        Damaged,
        Archived,
        PlotDormantLimited,
        PlotDecayedLimited,
        PlotLayerEligibleBlocked
    }

    /// @notice Usage channels for stats and later analytics / UE integration.
    enum BuildingUsageType {
        None,
        Visit,
        ShowcaseOpen,
        FarmingBoostActivation,
        FarmingBoostedClaim,
        Craft,
        UniqueCraft,
        RecipeCreate,
        EnchantmentCreate,
        MateriaCreate,
        StorageDeposit,
        StorageWithdraw,
        StorageYieldClaim,
        MarketListingCreate,
        MarketSale,
        AttackDetected,
        DefenseSupport,
        ResearchComplete,
        DiscoveryUnlock,

        // reserved for future systems
        BuildingFusion,
        BuildingEvolution,
        RentalStart,
        RentalEnd,
        QuestCompleted,
        AchievementUnlocked
    }

    enum ChronicleEventType {
        Mint,
        Transfer,
        Upgrade,
        Specialize,
        FactionVariantSet,
        Place,
        Unplace,
        Craft,
        Battle,
        Trade,
        Visit,
        Maintenance,
        Damage,
        Repair,
        Rental,
        QuestComplete,
        Achievement,
        VersionUpgrade,
        Fusion,
        Evolution,
        ArchiveMigration
    }

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct BuildingCore {
        BuildingCategory category;
        PersonalBuildingType buildingType;
        uint8 level;
        BuildingSpecialization specialization;
        FactionVariant factionVariant;
        uint64 mintedAt;
        address firstOwner;
    }

    struct BuildingMeta {
        string customName;
        uint32 versionTag;
        uint32 totalUses;
        uint32 totalTransfers;
        uint32 totalUpgrades;
        uint32 prestigeScore;
        uint32 historyScore;
    }

    struct BuildingPlacement {
        uint256 plotId;
        uint64 placedAt;
        uint64 lastPlacedAt;
        address placedBy;
    }

    struct BuildingUsageStats {
        // Residence
        uint32 visitorCount;
        uint32 showcasesOpened;

        // Farming Hub
        uint32 boostsActivated;
        uint32 boostedClaims;

        // Forge
        uint32 crafts;
        uint32 uniqueCrafts;
        uint32 recipesCreated;
        uint32 enchantmentsCreated;
        uint32 materiaCreated;

        // Warehouse
        uint256 totalStoredVolume;
        uint32 yieldClaims;

        // Market Stall
        uint32 listingsCreated;
        uint32 marketSales;

        // Guard Tower
        uint32 attacksDetected;
        uint32 defensesSupported;

        // Research Lab
        uint32 researchCompleted;
        uint32 discoveries;

        // future-safe counters
        uint32 fusionsPerformed;
        uint32 evolutions;
        uint32 rentalsCount;
        uint32 questsCompleted;
        uint32 achievementsUnlocked;
    }

    struct BuildingHistoryCounters {
        uint32 maintenanceActions;
        uint32 lifecycleInterruptions;
        uint32 publicSessions;
        uint32 specializationChanges;
        uint32 migrations;
        uint32 repairCount;
        uint32 damageEvents;
    }

    struct ChronicleEntry {
        ChronicleEventType eventType;
        uint32 eventData1;
        uint32 eventData2;
        address actor;
        uint64 timestamp;
        bytes32 extraData;
    }

    struct SetBonus {
        bytes32 setId;
        uint8 requiredBuildings;
        uint16 primaryBps;
        uint16 secondaryBps;
        string visualEffect;
    }

    struct BuildingSkin {
        string skinURI;
        string thumbnailURI;
        string shaderParams;
        uint32 equippedAt;
        bool isDefault;
    }

    /*//////////////////////////////////////////////////////////////
                              VALIDATION
    //////////////////////////////////////////////////////////////*/

    function isValidBaseType(PersonalBuildingType buildingType) internal pure returns (bool) {
        return buildingType >= PersonalBuildingType.Residence
            && buildingType <= PersonalBuildingType.ResearchLab;
    }

    function isValidPersonalCategory(BuildingCategory category) internal pure returns (bool) {
        return category == BuildingCategory.Personal;
    }

    function isValidLevel(uint8 level) internal pure returns (bool) {
        return level >= 1 && level <= MAX_BUILDING_LEVEL;
    }

    function isNameLengthValid(string memory name) internal pure returns (bool) {
        return bytes(name).length <= MAX_CUSTOM_NAME_LENGTH;
    }

    function isPlaced(BuildingPlacement memory placement) internal pure returns (bool) {
        return placement.plotId != UNPLACED_PLOT_ID;
    }

    function isPlacedState(BuildingState state_) internal pure returns (bool) {
        return state_ == BuildingState.PlacedActive
            || state_ == BuildingState.PlacedPaused
            || state_ == BuildingState.PlacedDamaged;
    }

    function isArchivedState(BuildingState state_) internal pure returns (bool) {
        return state_ == BuildingState.Archived;
    }

    function needsMigration(BuildingMeta memory meta) internal pure returns (bool) {
        return meta.versionTag < VERSION_TAG_V2;
    }

    /*//////////////////////////////////////////////////////////////
                        SPECIALIZATION RULE HELPERS
    //////////////////////////////////////////////////////////////*/

    function specializationMatchesType(
        PersonalBuildingType buildingType,
        BuildingSpecialization specialization
    ) internal pure returns (bool) {
        if (specialization == BuildingSpecialization.None) return true;

        if (buildingType == PersonalBuildingType.Residence) {
            return specialization == BuildingSpecialization.GalleryHouse
                || specialization == BuildingSpecialization.TrophyHall;
        }

        if (buildingType == PersonalBuildingType.Forge) {
            return specialization == BuildingSpecialization.WeaponForge
                || specialization == BuildingSpecialization.RelicForge
                || specialization == BuildingSpecialization.ComponentForge
                || specialization == BuildingSpecialization.MasterForge;
        }

        if (buildingType == PersonalBuildingType.Warehouse) {
            return specialization == BuildingSpecialization.ResourceVault
                || specialization == BuildingSpecialization.TradeDepot
                || specialization == BuildingSpecialization.FortressVault
                || specialization == BuildingSpecialization.MerchantVault;
        }

        if (buildingType == PersonalBuildingType.MarketStall) {
            return specialization == BuildingSpecialization.MerchantHouse;
        }

        if (buildingType == PersonalBuildingType.GuardTower) {
            return specialization == BuildingSpecialization.RadarTower
                || specialization == BuildingSpecialization.DefenseTower
                || specialization == BuildingSpecialization.MercenaryTower
                || specialization == BuildingSpecialization.ShieldTower;
        }

        if (buildingType == PersonalBuildingType.ResearchLab) {
            return specialization == BuildingSpecialization.MasterLab;
        }

        return false;
    }

    function minLevelForSpecialization(
        BuildingSpecialization specialization
    ) internal pure returns (uint8) {
        if (
            specialization == BuildingSpecialization.GalleryHouse
            || specialization == BuildingSpecialization.WeaponForge
            || specialization == BuildingSpecialization.RelicForge
            || specialization == BuildingSpecialization.ComponentForge
            || specialization == BuildingSpecialization.ResourceVault
            || specialization == BuildingSpecialization.RadarTower
            || specialization == BuildingSpecialization.DefenseTower
            || specialization == BuildingSpecialization.MasterLab
        ) {
            return 3;
        }

        if (
            specialization == BuildingSpecialization.TrophyHall
            || specialization == BuildingSpecialization.TradeDepot
            || specialization == BuildingSpecialization.MerchantHouse
            || specialization == BuildingSpecialization.MercenaryTower
            || specialization == BuildingSpecialization.ShieldTower
        ) {
            return 5;
        }

        if (
            specialization == BuildingSpecialization.FortressVault
            || specialization == BuildingSpecialization.MerchantVault
            || specialization == BuildingSpecialization.MasterForge
        ) {
            return 7;
        }

        return 1;
    }

    function canChooseSpecialization(
        PersonalBuildingType buildingType,
        uint8 level,
        BuildingSpecialization specialization
    ) internal pure returns (bool) {
        if (!isValidBaseType(buildingType)) return false;
        if (!isValidLevel(level)) return false;
        if (!specializationMatchesType(buildingType, specialization)) return false;
        return level >= minLevelForSpecialization(specialization);
    }

    /*//////////////////////////////////////////////////////////////
                         USAGE COUNTER HELPERS
    //////////////////////////////////////////////////////////////*/

    function incrementUsage(
        BuildingUsageStats storage stats,
        BuildingUsageType usageType,
        uint32 amount
    ) internal {
        if (amount == 0) return;

        if (usageType == BuildingUsageType.Visit) {
            stats.visitorCount += amount;
        } else if (usageType == BuildingUsageType.ShowcaseOpen) {
            stats.showcasesOpened += amount;
        } else if (usageType == BuildingUsageType.FarmingBoostActivation) {
            stats.boostsActivated += amount;
        } else if (usageType == BuildingUsageType.FarmingBoostedClaim) {
            stats.boostedClaims += amount;
        } else if (usageType == BuildingUsageType.Craft) {
            stats.crafts += amount;
        } else if (usageType == BuildingUsageType.UniqueCraft) {
            stats.uniqueCrafts += amount;
        } else if (usageType == BuildingUsageType.RecipeCreate) {
            stats.recipesCreated += amount;
        } else if (usageType == BuildingUsageType.EnchantmentCreate) {
            stats.enchantmentsCreated += amount;
        } else if (usageType == BuildingUsageType.MateriaCreate) {
            stats.materiaCreated += amount;
        } else if (usageType == BuildingUsageType.StorageYieldClaim) {
            stats.yieldClaims += amount;
        } else if (usageType == BuildingUsageType.MarketListingCreate) {
            stats.listingsCreated += amount;
        } else if (usageType == BuildingUsageType.MarketSale) {
            stats.marketSales += amount;
        } else if (usageType == BuildingUsageType.AttackDetected) {
            stats.attacksDetected += amount;
        } else if (usageType == BuildingUsageType.DefenseSupport) {
            stats.defensesSupported += amount;
        } else if (usageType == BuildingUsageType.ResearchComplete) {
            stats.researchCompleted += amount;
        } else if (usageType == BuildingUsageType.DiscoveryUnlock) {
            stats.discoveries += amount;
        } else if (usageType == BuildingUsageType.BuildingFusion) {
            stats.fusionsPerformed += amount;
        } else if (usageType == BuildingUsageType.BuildingEvolution) {
            stats.evolutions += amount;
        } else if (usageType == BuildingUsageType.RentalStart) {
            stats.rentalsCount += amount;
        } else if (usageType == BuildingUsageType.QuestCompleted) {
            stats.questsCompleted += amount;
        } else if (usageType == BuildingUsageType.AchievementUnlocked) {
            stats.achievementsUnlocked += amount;
        }
    }

    /*//////////////////////////////////////////////////////////////
                         TYPE-SPECIFIC HELPERS
    //////////////////////////////////////////////////////////////*/

    function supportsCustomName(PersonalBuildingType buildingType) internal pure returns (bool) {
        return buildingType != PersonalBuildingType.None;
    }

    function canHaveFactionVariant(PersonalBuildingType buildingType) internal pure returns (bool) {
        return buildingType == PersonalBuildingType.Residence
            || buildingType == PersonalBuildingType.Forge
            || buildingType == PersonalBuildingType.MarketStall
            || buildingType == PersonalBuildingType.GuardTower
            || buildingType == PersonalBuildingType.ResearchLab;
    }

    function isCreatorTierForge(BuildingCore memory core) internal pure returns (bool) {
        return core.category == BuildingCategory.Personal
            && core.buildingType == PersonalBuildingType.Forge
            && core.level >= 7
            && core.specialization == BuildingSpecialization.MasterForge;
    }

    function isResearchMaster(BuildingCore memory core) internal pure returns (bool) {
        return core.category == BuildingCategory.Personal
            && core.buildingType == PersonalBuildingType.ResearchLab
            && core.level >= 7
            && core.specialization == BuildingSpecialization.MasterLab;
    }
}