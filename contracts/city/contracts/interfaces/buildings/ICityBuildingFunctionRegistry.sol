// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../contracts/city/libraries/CityBuildingTypes.sol";

interface ICityBuildingFunctionRegistry {
    struct FunctionProfile {
        CityBuildingTypes.PersonalBuildingType buildingType;
        CityBuildingTypes.BuildingSpecialization specialization;
        uint8 level;

        uint8 evolutionBranch;
        uint8 functionTier;
        uint8 craftTier;
        uint8 techTier;
        uint8 defenseTier;
        uint8 marketTier;
        uint8 vaultTier;
        uint8 visualTier;

        uint32 prestigePresentationBps;
        uint32 farmingBoostBps;
        uint32 boostDurationBps;
        uint32 claimWindowBonusBps;

        uint32 craftCostReductionBps;
        uint32 craftProvenanceBonusBps;
        uint32 outputQualityBps;

        uint32 marketFeeReductionBps;
        uint32 premiumVisibilityBps;

        uint32 defenseBps;
        uint32 warehouseProtectionBps;
        uint32 raidMitigationBps;
        uint32 forgeSynergyBps;

        uint32 discoveryMask;
        uint32 allowedCategoryMask;
        uint32 provenanceFlags;

        uint16 showcaseSlots;
        uint16 archiveSlots;
        uint16 listingCap;

        uint8 radarTier;
        uint8 shieldTier;
        uint8 blueprintUnlockTier;

        bool legacyFlag;
        bool enchantPrep;
        bool materiaPrep;
        bool provenancePremium;
        bool fullSetEligible;
    }

    struct ResidenceProfile {
        uint8 level;
        CityBuildingTypes.BuildingSpecialization specialization;
        uint16 showcaseSlots;
        uint16 archiveSlots;
        uint32 prestigePresentationBps;
        bool legacyFlag;
        bool galleryBranchPrep;
        bool trophyBranchPrep;
    }

    struct FarmingHubProfile {
        uint8 level;
        CityBuildingTypes.BuildingSpecialization specialization;
        uint32 farmingBoostBps;
        uint32 boostDurationBps;
        uint32 claimWindowBonusBps;
        uint32 chainBonusBps;
    }

    struct ForgeProfile {
        uint8 level;
        CityBuildingTypes.BuildingSpecialization specialization;
        uint8 craftTier;
        uint8 recipeTier;
        uint32 craftCostReductionBps;
        uint32 craftProvenanceBonusBps;
        uint32 outputQualityBps;
    }

    struct WarehouseProfile {
        uint8 level;
        CityBuildingTypes.BuildingSpecialization specialization;
        uint8 vaultTier;
        uint8 capacityTier;
        uint32 reserveBuckets;
        uint32 protectedBuckets;
        uint32 raidableBuckets;
        bool repairFlag;
        bool decayFlag;
    }

    struct MarketStallProfile {
        uint8 level;
        CityBuildingTypes.BuildingSpecialization specialization;
        uint16 listingCap;
        uint32 allowedCategoryMask;
        uint32 marketFeeReductionBps;
        uint32 premiumVisibilityBps;
        bool provenancePremium;
    }

    struct GuardTowerProfile {
        uint8 level;
        CityBuildingTypes.BuildingSpecialization specialization;
        uint32 defenseBps;
        uint32 warehouseProtectionBps;
        uint32 raidMitigationBps;
        uint8 radarTier;
        uint8 shieldTier;
    }

    struct ResearchLabProfile {
        uint8 level;
        CityBuildingTypes.BuildingSpecialization specialization;
        uint8 techTier;
        uint32 discoveryMask;
        uint8 blueprintUnlockTier;
        bool enchantPrep;
        bool materiaPrep;
        uint32 forgeSynergyBps;
    }

    function getFunctionProfile(uint256 buildingId) external view returns (FunctionProfile memory);
    function getResidenceProfile(uint256 buildingId) external view returns (ResidenceProfile memory);
    function getFarmingHubProfile(uint256 buildingId) external view returns (FarmingHubProfile memory);
    function getForgeProfile(uint256 buildingId) external view returns (ForgeProfile memory);
    function getWarehouseProfile(uint256 buildingId) external view returns (WarehouseProfile memory);
    function getMarketStallProfile(uint256 buildingId) external view returns (MarketStallProfile memory);
    function getGuardTowerProfile(uint256 buildingId) external view returns (GuardTowerProfile memory);
    function getResearchLabProfile(uint256 buildingId) external view returns (ResearchLabProfile memory);
}