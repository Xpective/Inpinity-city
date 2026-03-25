/* FILE: contracts/city/contracts/buildings/CityBuildingFunctionRegistry.sol */
/* TYPE: building function matrix / read layer — NOT NFT, NOT PersonalBuildings */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

import "../libraries/CityBuildingTypes.sol";
import "../interfaces/buildings/ICityBuildingFunctionRegistry.sol";

/*//////////////////////////////////////////////////////////////
                        DEPENDENCY INTERFACES
//////////////////////////////////////////////////////////////*/

interface ICityBuildingNFTV1FunctionRead {
    function getBuildingCore(
        uint256 buildingId
    ) external view returns (CityBuildingTypes.BuildingCore memory);

    function isArchived(uint256 buildingId) external view returns (bool);

    function isMigrationPrepared(uint256 buildingId) external view returns (bool);

    function ownerOf(uint256 tokenId) external view returns (address);
}

interface ICityBuildingPlacementFunctionRead {
    function getPlacementSummary(
        uint256 buildingId
    )
        external
        view
        returns (
            uint256 plotId,
            bool placed,
            bool prepared,
            bool archived,
            uint64 placedAt,
            uint64 lastPlacedAt,
            address placedBy
        );
}

interface ICityBuildingPlacementProvenanceRead {
    function getFirstPlacementSnapshot(
        uint256 buildingId
    )
        external
        view
        returns (
            uint256 firstPlotId,
            uint8 firstFaction,
            uint8 firstDistrictKind,
            uint64 firstPlacedTimestamp
        );
}

/*//////////////////////////////////////////////////////////////
                    CITY BUILDING FUNCTION REGISTRY
//////////////////////////////////////////////////////////////*/

contract CityBuildingFunctionRegistry is
    AccessControl,
    Pausable,
    ICityBuildingFunctionRegistry
{
    bytes32 public constant REGISTRY_ADMIN_ROLE = keccak256("REGISTRY_ADMIN_ROLE");

    uint32 internal constant FLAG_LEVEL_7 = 1 << 0;
    uint32 internal constant FLAG_SPECIALIZED = 1 << 1;
    uint32 internal constant FLAG_CURRENTLY_PLACED = 1 << 2;
    uint32 internal constant FLAG_HAS_PLACEMENT_HISTORY = 1 << 3;
    uint32 internal constant FLAG_HAS_FIRST_PLACEMENT = 1 << 4;
    uint32 internal constant FLAG_HAS_FIRST_FACTION = 1 << 5;
    uint32 internal constant FLAG_HAS_FIRST_DISTRICT = 1 << 6;
    uint32 internal constant FLAG_FACTION_VARIANT = 1 << 7;
    uint32 internal constant FLAG_FIRST_OWNER_SET = 1 << 8;
    uint32 internal constant FLAG_MINTED_TIMESTAMP_SET = 1 << 9;
    uint32 internal constant FLAG_LEGACY_READY = 1 << 10;
    uint32 internal constant FLAG_MASTER_TIER = 1 << 11;

    error ZeroAddress();
    error InvalidBuildingNFT();
    error InvalidPlacement();
    error InvalidBuildingType();
    error InvalidBuildingCategory();
    error BuildingArchived();
    error BuildingPreparedForMigration();

    event BuildingNFTSet(address indexed buildingNFT, address indexed executor);
    event PlacementSet(address indexed placement, address indexed executor);

    ICityBuildingNFTV1FunctionRead public buildingNFT;
    ICityBuildingPlacementFunctionRead public placement;

    constructor(
        address buildingNFT_,
        address placement_,
        address admin_
    ) {
        if (buildingNFT_ == address(0) || placement_ == address(0) || admin_ == address(0)) {
            revert ZeroAddress();
        }
        if (buildingNFT_.code.length == 0) revert InvalidBuildingNFT();
        if (placement_.code.length == 0) revert InvalidPlacement();

        buildingNFT = ICityBuildingNFTV1FunctionRead(buildingNFT_);
        placement = ICityBuildingPlacementFunctionRead(placement_);

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(REGISTRY_ADMIN_ROLE, admin_);
    }

    function pause() external onlyRole(REGISTRY_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(REGISTRY_ADMIN_ROLE) {
        _unpause();
    }

    function setBuildingNFT(address buildingNFT_) external onlyRole(REGISTRY_ADMIN_ROLE) {
        if (buildingNFT_ == address(0)) revert ZeroAddress();
        if (buildingNFT_.code.length == 0) revert InvalidBuildingNFT();

        buildingNFT = ICityBuildingNFTV1FunctionRead(buildingNFT_);
        emit BuildingNFTSet(buildingNFT_, msg.sender);
    }

    function setPlacement(address placement_) external onlyRole(REGISTRY_ADMIN_ROLE) {
        if (placement_ == address(0)) revert ZeroAddress();
        if (placement_.code.length == 0) revert InvalidPlacement();

        placement = ICityBuildingPlacementFunctionRead(placement_);
        emit PlacementSet(placement_, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                              MAIN PROFILE
    //////////////////////////////////////////////////////////////*/

    function getFunctionProfile(
        uint256 buildingId
    ) external view override returns (FunctionProfile memory p) {
        _requireActivePersonalBuilding(buildingId);

        CityBuildingTypes.BuildingCore memory core = buildingNFT.getBuildingCore(buildingId);

        p.buildingType = core.buildingType;
        p.specialization = core.specialization;
        p.level = core.level;

        p.evolutionBranch = _deriveEvolutionBranch(core.buildingType, core.specialization);
        p.functionTier = _deriveFunctionTier(core.level);
        p.craftTier = _deriveCraftTier(core.level);
        p.techTier = _deriveTechTier(core.level);
        p.defenseTier = _deriveDefenseTier(core.level);
        p.marketTier = _deriveMarketTier(core.level);
        p.vaultTier = _deriveVaultTier(core.level);
        p.visualTier = _deriveVisualTier(core.level);
        p.provenanceFlags = _deriveProvenanceFlags(buildingId, core);

        // Per-building neutral defaults
        p.fullSetEligible = core.level >= 4;

        if (core.buildingType == CityBuildingTypes.PersonalBuildingType.Residence) {
            ResidenceProfile memory rp = _buildResidenceProfile(core);
            p.showcaseSlots = rp.showcaseSlots;
            p.archiveSlots = rp.archiveSlots;
            p.prestigePresentationBps = rp.prestigePresentationBps;
            p.legacyFlag = rp.legacyFlag;
        } else if (core.buildingType == CityBuildingTypes.PersonalBuildingType.FarmingHub) {
            FarmingHubProfile memory fp = _buildFarmingHubProfile(core);
            p.farmingBoostBps = fp.farmingBoostBps;
            p.boostDurationBps = fp.boostDurationBps;
            p.claimWindowBonusBps = fp.claimWindowBonusBps;
        } else if (core.buildingType == CityBuildingTypes.PersonalBuildingType.Forge) {
            ForgeProfile memory fp2 = _buildForgeProfile(core);
            p.craftTier = fp2.craftTier;
            p.craftCostReductionBps = fp2.craftCostReductionBps;
            p.craftProvenanceBonusBps = fp2.craftProvenanceBonusBps;
            p.outputQualityBps = fp2.outputQualityBps;
        } else if (core.buildingType == CityBuildingTypes.PersonalBuildingType.Warehouse) {
            WarehouseProfile memory wp = _buildWarehouseProfile(core);
            p.vaultTier = wp.vaultTier;
        } else if (core.buildingType == CityBuildingTypes.PersonalBuildingType.MarketStall) {
            MarketStallProfile memory mp = _buildMarketStallProfile(core);
            p.listingCap = mp.listingCap;
            p.allowedCategoryMask = mp.allowedCategoryMask;
            p.marketFeeReductionBps = mp.marketFeeReductionBps;
            p.premiumVisibilityBps = mp.premiumVisibilityBps;
            p.provenancePremium = mp.provenancePremium;
        } else if (core.buildingType == CityBuildingTypes.PersonalBuildingType.GuardTower) {
            GuardTowerProfile memory gp = _buildGuardTowerProfile(core);
            p.defenseBps = gp.defenseBps;
            p.warehouseProtectionBps = gp.warehouseProtectionBps;
            p.raidMitigationBps = gp.raidMitigationBps;
            p.radarTier = gp.radarTier;
            p.shieldTier = gp.shieldTier;
        } else if (core.buildingType == CityBuildingTypes.PersonalBuildingType.ResearchLab) {
            ResearchLabProfile memory rp2 = _buildResearchLabProfile(core);
            p.discoveryMask = rp2.discoveryMask;
            p.blueprintUnlockTier = rp2.blueprintUnlockTier;
            p.enchantPrep = rp2.enchantPrep;
            p.materiaPrep = rp2.materiaPrep;
            p.forgeSynergyBps = rp2.forgeSynergyBps;
        }
    }

    /*//////////////////////////////////////////////////////////////
                         PER-BUILDING READS
    //////////////////////////////////////////////////////////////*/

    function getResidenceProfile(
        uint256 buildingId
    ) external view override returns (ResidenceProfile memory) {
        CityBuildingTypes.BuildingCore memory core = _requireSpecificType(
            buildingId,
            CityBuildingTypes.PersonalBuildingType.Residence
        );
        return _buildResidenceProfile(core);
    }

    function getFarmingHubProfile(
        uint256 buildingId
    ) external view override returns (FarmingHubProfile memory) {
        CityBuildingTypes.BuildingCore memory core = _requireSpecificType(
            buildingId,
            CityBuildingTypes.PersonalBuildingType.FarmingHub
        );
        return _buildFarmingHubProfile(core);
    }

    function getForgeProfile(
        uint256 buildingId
    ) external view override returns (ForgeProfile memory) {
        CityBuildingTypes.BuildingCore memory core = _requireSpecificType(
            buildingId,
            CityBuildingTypes.PersonalBuildingType.Forge
        );
        return _buildForgeProfile(core);
    }

    function getWarehouseProfile(
        uint256 buildingId
    ) external view override returns (WarehouseProfile memory) {
        CityBuildingTypes.BuildingCore memory core = _requireSpecificType(
            buildingId,
            CityBuildingTypes.PersonalBuildingType.Warehouse
        );
        return _buildWarehouseProfile(core);
    }

    function getMarketStallProfile(
        uint256 buildingId
    ) external view override returns (MarketStallProfile memory) {
        CityBuildingTypes.BuildingCore memory core = _requireSpecificType(
            buildingId,
            CityBuildingTypes.PersonalBuildingType.MarketStall
        );
        return _buildMarketStallProfile(core);
    }

    function getGuardTowerProfile(
        uint256 buildingId
    ) external view override returns (GuardTowerProfile memory) {
        CityBuildingTypes.BuildingCore memory core = _requireSpecificType(
            buildingId,
            CityBuildingTypes.PersonalBuildingType.GuardTower
        );
        return _buildGuardTowerProfile(core);
    }

    function getResearchLabProfile(
        uint256 buildingId
    ) external view override returns (ResearchLabProfile memory) {
        CityBuildingTypes.BuildingCore memory core = _requireSpecificType(
            buildingId,
            CityBuildingTypes.PersonalBuildingType.ResearchLab
        );
        return _buildResearchLabProfile(core);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL BUILDERS
    //////////////////////////////////////////////////////////////*/

    function _buildResidenceProfile(
        CityBuildingTypes.BuildingCore memory core
    ) internal pure returns (ResidenceProfile memory p) {
        p.level = core.level;
        p.specialization = core.specialization;

        if (core.level == 1) {
            p.showcaseSlots = 2;
            p.archiveSlots = 0;
            p.prestigePresentationBps = 0;
        } else if (core.level == 2) {
            p.showcaseSlots = 4;
            p.archiveSlots = 0;
            p.prestigePresentationBps = 100;
        } else if (core.level == 3) {
            p.showcaseSlots = 6;
            p.archiveSlots = 2;
            p.prestigePresentationBps = 200;
        } else if (core.level == 4) {
            p.showcaseSlots = 8;
            p.archiveSlots = 3;
            p.prestigePresentationBps = 350;
        } else if (core.level == 5) {
            p.showcaseSlots = 10;
            p.archiveSlots = 4;
            p.prestigePresentationBps = 500;
            p.legacyFlag = true;
        } else if (core.level == 6) {
            p.showcaseSlots = 12;
            p.archiveSlots = 5;
            p.prestigePresentationBps = 700;
            p.legacyFlag = true;
            p.galleryBranchPrep = true;
        } else {
            p.showcaseSlots = 14;
            p.archiveSlots = 6;
            p.prestigePresentationBps = 1000;
            p.legacyFlag = true;
            p.galleryBranchPrep = true;
            p.trophyBranchPrep = true;
        }

        if (core.specialization == CityBuildingTypes.BuildingSpecialization.GalleryHouse) {
            p.showcaseSlots += 2;
            p.galleryBranchPrep = true;
            p.prestigePresentationBps += 75;
        } else if (core.specialization == CityBuildingTypes.BuildingSpecialization.TrophyHall) {
            p.archiveSlots += 2;
            p.trophyBranchPrep = true;
            p.legacyFlag = true;
            p.prestigePresentationBps += 125;
        }
    }

    function _buildFarmingHubProfile(
        CityBuildingTypes.BuildingCore memory core
    ) internal pure returns (FarmingHubProfile memory p) {
        p.level = core.level;
        p.specialization = core.specialization;

        p.farmingBoostBps = uint32(core.level) * 200;
        p.boostDurationBps = uint32(core.level) * 100;
        p.claimWindowBonusBps = core.level >= 4 ? uint32(core.level - 3) * 100 : 0;
        p.chainBonusBps = core.level >= 5 ? uint32(core.level - 4) * 150 : 0;
    }

    function _buildForgeProfile(
        CityBuildingTypes.BuildingCore memory core
    ) internal pure returns (ForgeProfile memory p) {
        p.level = core.level;
        p.specialization = core.specialization;

        p.craftTier = _deriveCraftTier(core.level);
        p.recipeTier = _deriveCraftTier(core.level);
        p.craftCostReductionBps = uint32(core.level) * 75;
        p.craftProvenanceBonusBps = core.level >= 3 ? uint32(core.level - 2) * 100 : 0;
        p.outputQualityBps = core.level >= 5 ? uint32(core.level - 4) * 125 : 0;

        if (core.specialization == CityBuildingTypes.BuildingSpecialization.WeaponForge) {
            p.outputQualityBps += 75;
        } else if (core.specialization == CityBuildingTypes.BuildingSpecialization.RelicForge) {
            p.craftProvenanceBonusBps += 100;
        } else if (core.specialization == CityBuildingTypes.BuildingSpecialization.ComponentForge) {
            p.craftCostReductionBps += 75;
        } else if (core.specialization == CityBuildingTypes.BuildingSpecialization.MasterForge) {
            p.craftTier += 1;
            p.recipeTier += 1;
            p.craftCostReductionBps += 100;
            p.craftProvenanceBonusBps += 150;
            p.outputQualityBps += 200;
        }
    }

    function _buildWarehouseProfile(
        CityBuildingTypes.BuildingCore memory core
    ) internal pure returns (WarehouseProfile memory p) {
        p.level = core.level;
        p.specialization = core.specialization;
        p.vaultTier = _deriveVaultTier(core.level);
        p.capacityTier = _deriveVaultTier(core.level);

        if (core.level == 1) {
            p.reserveBuckets = 1;
            p.protectedBuckets = 1;
            p.raidableBuckets = 1;
            p.repairFlag = false;
            p.decayFlag = false;
        } else if (core.level == 2) {
            p.reserveBuckets = 2;
            p.protectedBuckets = 1;
            p.raidableBuckets = 2;
            p.repairFlag = false;
            p.decayFlag = false;
        } else if (core.level == 3) {
            p.reserveBuckets = 3;
            p.protectedBuckets = 1;
            p.raidableBuckets = 2;
            p.repairFlag = true;
            p.decayFlag = true;
        } else if (core.level == 4) {
            p.reserveBuckets = 4;
            p.protectedBuckets = 1;
            p.raidableBuckets = 3;
            p.repairFlag = true;
            p.decayFlag = true;
        } else if (core.level == 5) {
            p.reserveBuckets = 5;
            p.protectedBuckets = 2;
            p.raidableBuckets = 3;
            p.repairFlag = true;
            p.decayFlag = true;
        } else if (core.level == 6) {
            p.reserveBuckets = 6;
            p.protectedBuckets = 2;
            p.raidableBuckets = 4;
            p.repairFlag = true;
            p.decayFlag = true;
        } else {
            p.reserveBuckets = 8;
            p.protectedBuckets = 3;
            p.raidableBuckets = 4;
            p.repairFlag = true;
            p.decayFlag = true;
        }

        if (core.specialization == CityBuildingTypes.BuildingSpecialization.ResourceVault) {
            p.protectedBuckets += 1;
        } else if (core.specialization == CityBuildingTypes.BuildingSpecialization.TradeDepot) {
            p.reserveBuckets += 1;
        } else if (core.specialization == CityBuildingTypes.BuildingSpecialization.FortressVault) {
            p.protectedBuckets += 1;
            if (p.raidableBuckets > 0) p.raidableBuckets -= 1;
        } else if (core.specialization == CityBuildingTypes.BuildingSpecialization.MerchantVault) {
            p.reserveBuckets += 1;
            p.protectedBuckets += 1;
        }
    }

    function _buildMarketStallProfile(
        CityBuildingTypes.BuildingCore memory core
    ) internal pure returns (MarketStallProfile memory p) {
        p.level = core.level;
        p.specialization = core.specialization;

        if (core.level == 1) {
            p.listingCap = 3;
            p.allowedCategoryMask = 1;
            p.marketFeeReductionBps = 0;
            p.premiumVisibilityBps = 0;
        } else if (core.level == 2) {
            p.listingCap = 5;
            p.allowedCategoryMask = 3;
            p.marketFeeReductionBps = 100;
            p.premiumVisibilityBps = 50;
        } else if (core.level == 3) {
            p.listingCap = 8;
            p.allowedCategoryMask = 7;
            p.marketFeeReductionBps = 200;
            p.premiumVisibilityBps = 100;
        } else if (core.level == 4) {
            p.listingCap = 12;
            p.allowedCategoryMask = 15;
            p.marketFeeReductionBps = 300;
            p.premiumVisibilityBps = 150;
        } else if (core.level == 5) {
            p.listingCap = 16;
            p.allowedCategoryMask = 31;
            p.marketFeeReductionBps = 400;
            p.premiumVisibilityBps = 250;
        } else if (core.level == 6) {
            p.listingCap = 20;
            p.allowedCategoryMask = 63;
            p.marketFeeReductionBps = 550;
            p.premiumVisibilityBps = 400;
            p.provenancePremium = true;
        } else {
            p.listingCap = 25;
            p.allowedCategoryMask = type(uint32).max;
            p.marketFeeReductionBps = 750;
            p.premiumVisibilityBps = 600;
            p.provenancePremium = true;
        }

        if (core.specialization == CityBuildingTypes.BuildingSpecialization.MerchantHouse) {
            p.marketFeeReductionBps += 100;
            p.premiumVisibilityBps += 100;
        } else if (core.specialization == CityBuildingTypes.BuildingSpecialization.TradeDepot) {
            p.listingCap += 3;
            p.allowedCategoryMask = type(uint32).max;
            p.marketFeeReductionBps += 75;
        } else if (core.specialization == CityBuildingTypes.BuildingSpecialization.MerchantVault) {
            p.listingCap += 2;
            p.premiumVisibilityBps += 150;
            p.provenancePremium = true;
        }
    }

    function _buildGuardTowerProfile(
        CityBuildingTypes.BuildingCore memory core
    ) internal pure returns (GuardTowerProfile memory p) {
        p.level = core.level;
        p.specialization = core.specialization;

        p.defenseBps = uint32(core.level) * 250;
        p.warehouseProtectionBps = core.level >= 3 ? uint32(core.level - 2) * 200 : 0;
        p.raidMitigationBps = core.level >= 4 ? uint32(core.level - 3) * 175 : 0;
        p.radarTier = core.level >= 5 ? uint8(core.level - 4) : 0;
        p.shieldTier = core.level >= 6 ? uint8(core.level - 5) : 0;

        if (core.specialization == CityBuildingTypes.BuildingSpecialization.RadarTower) {
            p.radarTier += 1;
        } else if (core.specialization == CityBuildingTypes.BuildingSpecialization.DefenseTower) {
            p.defenseBps += 200;
            p.warehouseProtectionBps += 100;
        } else if (core.specialization == CityBuildingTypes.BuildingSpecialization.MercenaryTower) {
            p.defenseBps += 100;
            p.raidMitigationBps += 150;
        } else if (core.specialization == CityBuildingTypes.BuildingSpecialization.ShieldTower) {
            p.shieldTier += 1;
            p.raidMitigationBps += 250;
            p.warehouseProtectionBps += 150;
        }
    }

    function _buildResearchLabProfile(
        CityBuildingTypes.BuildingCore memory core
    ) internal pure returns (ResearchLabProfile memory p) {
        p.level = core.level;
        p.specialization = core.specialization;

        p.techTier = _deriveTechTier(core.level);
        p.discoveryMask = _deriveDiscoveryMask(core.level);
        p.blueprintUnlockTier = core.level >= 3 ? core.level - 2 : 0;
        p.enchantPrep = core.level >= 5;
        p.materiaPrep = core.level >= 5;
        p.forgeSynergyBps = core.level >= 2 ? uint32(core.level - 1) * 150 : 0;

        if (core.specialization == CityBuildingTypes.BuildingSpecialization.MasterLab) {
            p.techTier += 1;
            p.blueprintUnlockTier += 1;
            p.forgeSynergyBps += 200;
            p.enchantPrep = true;
            p.materiaPrep = true;
        }
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL DERIVATIONS
    //////////////////////////////////////////////////////////////*/

    function _deriveFunctionTier(uint8 level) internal pure returns (uint8) {
        if (level >= 7) return 4;
        if (level >= 5) return 3;
        if (level >= 3) return 2;
        return 1;
    }

    function _deriveCraftTier(uint8 level) internal pure returns (uint8) {
        if (level >= 7) return 4;
        if (level >= 5) return 3;
        if (level >= 3) return 2;
        return 1;
    }

    function _deriveTechTier(uint8 level) internal pure returns (uint8) {
        if (level >= 7) return 4;
        if (level >= 5) return 3;
        if (level >= 3) return 2;
        return 1;
    }

    function _deriveDefenseTier(uint8 level) internal pure returns (uint8) {
        if (level >= 7) return 4;
        if (level >= 5) return 3;
        if (level >= 3) return 2;
        return 1;
    }

    function _deriveMarketTier(uint8 level) internal pure returns (uint8) {
        if (level >= 7) return 4;
        if (level >= 5) return 3;
        if (level >= 3) return 2;
        return 1;
    }

    function _deriveVaultTier(uint8 level) internal pure returns (uint8) {
        if (level >= 7) return 4;
        if (level >= 5) return 3;
        if (level >= 3) return 2;
        return 1;
    }

    function _deriveVisualTier(uint8 level) internal pure returns (uint8) {
        if (level >= 7) return 4;
        if (level >= 5) return 3;
        if (level >= 3) return 2;
        return 1;
    }

    function _deriveDiscoveryMask(uint8 level) internal pure returns (uint32) {
        if (level == 0) return 0;
        if (level == 1) return 1;
        if (level == 2) return 3;
        if (level == 3) return 7;
        if (level == 4) return 15;
        if (level == 5) return 31;
        if (level == 6) return 63;
        return 127;
    }

    function _deriveEvolutionBranch(
        CityBuildingTypes.PersonalBuildingType buildingType,
        CityBuildingTypes.BuildingSpecialization specialization
    ) internal pure returns (uint8) {
        if (specialization != CityBuildingTypes.BuildingSpecialization.None) {
            return uint8(specialization);
        }
        return uint8(buildingType);
    }

    function _deriveProvenanceFlags(
        uint256 buildingId,
        CityBuildingTypes.BuildingCore memory core
    ) internal view returns (uint32 flags) {
        if (core.level >= 7) flags |= FLAG_LEVEL_7;
        if (core.specialization != CityBuildingTypes.BuildingSpecialization.None) flags |= FLAG_SPECIALIZED;
        if (core.factionVariant != CityBuildingTypes.FactionVariant.None) flags |= FLAG_FACTION_VARIANT;
        if (core.firstOwner != address(0)) flags |= FLAG_FIRST_OWNER_SET;
        if (core.mintedAt != 0) flags |= FLAG_MINTED_TIMESTAMP_SET;

        (
            uint256 plotId,
            bool placed,
            ,
            ,
            uint64 placedAt,
            uint64 lastPlacedAt,
            address placedBy
        ) = placement.getPlacementSummary(buildingId);

        if (placed && plotId != 0) flags |= FLAG_CURRENTLY_PLACED;
        if (placedAt != 0 || lastPlacedAt != 0 || placedBy != address(0)) {
            flags |= FLAG_HAS_PLACEMENT_HISTORY;
        }

        if (core.level >= 5) flags |= FLAG_LEGACY_READY;
        if (core.level >= 7) flags |= FLAG_MASTER_TIER;

        if (address(placement).code.length > 0) {
            try ICityBuildingPlacementProvenanceRead(address(placement)).getFirstPlacementSnapshot(buildingId) returns (
                uint256 firstPlotId,
                uint8 firstFaction,
                uint8 firstDistrictKind,
                uint64 firstPlacedTimestamp
            ) {
                if (firstPlotId != 0 || firstPlacedTimestamp != 0) flags |= FLAG_HAS_FIRST_PLACEMENT;
                if (firstFaction != 0) flags |= FLAG_HAS_FIRST_FACTION;
                if (firstDistrictKind != 0) flags |= FLAG_HAS_FIRST_DISTRICT;
            } catch {
                // optional provenance extension not available on older placement contracts
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL GUARDS
    //////////////////////////////////////////////////////////////*/

    function _requireActivePersonalBuilding(uint256 buildingId) internal view {
        if (buildingNFT.isArchived(buildingId)) revert BuildingArchived();
        if (buildingNFT.isMigrationPrepared(buildingId)) revert BuildingPreparedForMigration();

        CityBuildingTypes.BuildingCore memory core = buildingNFT.getBuildingCore(buildingId);
        if (core.category != CityBuildingTypes.BuildingCategory.Personal) revert InvalidBuildingCategory();
        if (!CityBuildingTypes.isValidBaseType(core.buildingType)) revert InvalidBuildingType();
    }

    function _requireSpecificType(
        uint256 buildingId,
        CityBuildingTypes.PersonalBuildingType expectedType
    ) internal view returns (CityBuildingTypes.BuildingCore memory core) {
        if (buildingNFT.isArchived(buildingId)) revert BuildingArchived();
        if (buildingNFT.isMigrationPrepared(buildingId)) revert BuildingPreparedForMigration();

        core = buildingNFT.getBuildingCore(buildingId);
        if (core.category != CityBuildingTypes.BuildingCategory.Personal) revert InvalidBuildingCategory();
        if (core.buildingType != expectedType) revert InvalidBuildingType();
    }
}