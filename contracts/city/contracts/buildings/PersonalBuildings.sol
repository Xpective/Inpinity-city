/* FILE: contracts/city/contracts/buildings/PersonalBuildings.sol */
/* TYPE: personal buildings orchestrator / user-facing logic layer — NOT NFT */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "../libraries/CityBuildingTypes.sol";
import "../interfaces/ICityBuildingNFTV1Like.sol";
import "../interfaces/buildings/ICityBuildingFunctionRegistry.sol";
import "../interfaces/buildings/ICityBuildingVault.sol";
import "../interfaces/buildings/ICityBuildingVaultYield.sol";

/*//////////////////////////////////////////////////////////////
                        EXTERNAL INTERFACES
//////////////////////////////////////////////////////////////*/

interface ICityBuildingNFTV1PersonalLogic is ICityBuildingNFTV1Like {
    function mintBuilding(
        address to,
        CityBuildingTypes.PersonalBuildingType buildingType,
        uint32 versionTag
    ) external returns (uint256 buildingId);

    function upgradeBuilding(uint256 buildingId, uint8 newLevel) external;

    function specializeBuilding(
        uint256 buildingId,
        CityBuildingTypes.BuildingSpecialization newSpecialization
    ) external;

    function addPrestigeScore(uint256 buildingId, uint32 amount) external;

    function addHistoryScore(uint256 buildingId, uint32 amount) external;

    function recordUsage(
        uint256 buildingId,
        CityBuildingTypes.BuildingUsageType usageType,
        uint32 amount
    ) external;
}

interface ICityBuildingPlacementPersonalRead {
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

interface IPersonalBuildingResourceAdapter {
    function burnResourceBundle(
        address from,
        uint256[10] calldata amounts,
        bytes32 reason
    ) external;
}

interface IPersonalBuildingPitAdapter {
    function collectPitFee(
        address from,
        uint256 amount,
        bytes32 reason
    ) external;
}

interface IPersonalBuildingTechAdapter {
    function canUpgradeBuilding(
        address owner,
        uint256 buildingId,
        CityBuildingTypes.BuildingCore calldata core,
        uint8 targetLevel
    ) external view returns (bool allowed, bytes32 reasonCode);

    function canSpecializeBuilding(
        address owner,
        uint256 buildingId,
        CityBuildingTypes.BuildingCore calldata core,
        CityBuildingTypes.BuildingSpecialization specialization
    ) external view returns (bool allowed, bytes32 reasonCode);
}

interface IPersonalBuildingStatusHookAdapter {
    function touchPlotActivity(uint256 plotId) external;
}

interface IPersonalBuildingMintPlotAdapter {
    function getMintPlotInfo(
        uint256 plotId
    )
        external
        view
        returns (
            address owner,
            bool exists,
            bool completed,
            bool personalPlot,
            bool eligible,
            uint8 districtKind,
            uint8 faction
        );
}

interface IPersonalBuildingsVaultRead is ICityBuildingVault, ICityBuildingVaultYield {
    function getRecommendedWarehouseVaultProfile(
        uint256 buildingId
    )
        external
        view
        returns (
            uint8 vaultTier,
            uint8 defenseTier,
            uint32 vaultCapBps,
            uint32 defenseBps,
            uint32 raidMitigationBps,
            bool decayPrepared,
            bool repairPrepared,
            bool raidEligibleByLevel
        );

    function getRecommendedWarehouseBuckets(
        uint256 buildingId
    )
        external
        view
        returns (
            uint32 reserveBuckets,
            uint32 protectedBuckets,
            uint32 raidableBuckets
        );
}

/*//////////////////////////////////////////////////////////////
                         PERSONAL BUILDINGS
//////////////////////////////////////////////////////////////*/

contract PersonalBuildings is AccessControl, Pausable, ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                                 ROLES
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant LOGIC_ADMIN_ROLE = keccak256("LOGIC_ADMIN_ROLE");
    bytes32 public constant CONFIG_ROLE = keccak256("CONFIG_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint8 public constant RESOURCE_SLOT_COUNT = 10;
    uint32 public constant DEFAULT_VERSION_TAG = CityBuildingTypes.VERSION_TAG_V1;
    uint256 public constant MAX_BATCH_SET = 100;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error InvalidBuildingNFT();
    error InvalidPlacement();
    error InvalidResourceAdapter();
    error InvalidPitAdapter();
    error InvalidTechAdapter();
    error InvalidStatusHookAdapter();
    error InvalidMintPlotAdapter();
    error InvalidFunctionRegistry();
    error InvalidVault();

    error InvalidBuildingCategory();
    error InvalidBuildingType();
    error InvalidLevel();
    error InvalidSpecialization();
    error InvalidVersionTag();
    error InvalidConfig();
    error InvalidResourceId();
    error MaxLevelReached();

    error NotBuildingOwner();
    error BuildingArchived();
    error BuildingPreparedForMigration();
    error BuildingStateNotUpgradeable();
    error BuildingStateNotSpecializable();
    error NoStateChange();

    error UpgradeCooldownActive(uint64 readyAt);
    error UpgradeNotConfigured();
    error SpecializationNotConfigured();
    error MintNotConfigured();
    error TechRequirementFailed(bytes32 reasonCode);

    error MintAdapterNotSet();
    error PlotNotFound();
    error PlotNotCompleted();
    error PlotNotPersonal();
    error PlotNotEligibleForMint();
    error PlotOwnerMismatch();
    error PlotMintAlreadyUsed();
    error InvalidPlotId();

    error NoIdsProvided();
    error BatchLengthMismatch();
    error BatchTooLarge(uint256 provided, uint256 maxAllowed);
    error FunctionRegistryNotSet();
    error VaultNotSet();
    error NotWarehouseBuilding();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event BuildingNFTSet(address indexed buildingNFT, address indexed executor);
    event PlacementSet(address indexed placement, address indexed executor);
    event ResourceAdapterSet(address indexed adapter, address indexed executor);
    event PitAdapterSet(address indexed adapter, address indexed executor);
    event TechAdapterSet(address indexed adapter, address indexed executor);
    event StatusHookAdapterSet(address indexed adapter, address indexed executor);
    event MintPlotAdapterSet(address indexed adapter, address indexed executor);
    event FunctionRegistrySet(address indexed registry, address indexed executor);
    event VaultSet(address indexed vault, address indexed executor);

    event MintCostConfigured(
        CityBuildingTypes.PersonalBuildingType indexed buildingType,
        uint256[10] resourceAmounts,
        uint256 pitFee,
        uint32 prestigeReward,
        uint32 historyReward,
        bool configured,
        address indexed executor
    );

    event UpgradeCostConfigured(
        CityBuildingTypes.PersonalBuildingType indexed buildingType,
        uint8 indexed targetLevel,
        uint256[10] resourceAmounts,
        uint256 pitFee,
        uint64 cooldown,
        uint32 prestigeReward,
        uint32 historyReward,
        bool configured,
        address indexed executor
    );

    event SpecializationCostConfigured(
        CityBuildingTypes.BuildingSpecialization indexed specialization,
        uint256[10] resourceAmounts,
        uint256 pitFee,
        uint32 prestigeReward,
        uint32 historyReward,
        bool configured,
        address indexed executor
    );

    event PlotMintEntitlementUpdated(
        uint256 indexed plotId,
        bool used,
        uint256 indexed buildingId,
        address indexed executor
    );

    event LastUpgradeExecutionAtUpdated(
        uint256 indexed buildingId,
        uint64 lastExecutionAt,
        address indexed executor
    );

    event PersonalBuildingMintedThroughLogic(
        uint256 indexed buildingId,
        uint256 indexed plotId,
        CityBuildingTypes.PersonalBuildingType indexed buildingType,
        address owner,
        uint64 mintedAt
    );

    event BuildingUpgradedThroughLogic(
        uint256 indexed buildingId,
        CityBuildingTypes.PersonalBuildingType indexed buildingType,
        uint8 oldLevel,
        uint8 newLevel,
        address indexed owner,
        uint64 executedAt
    );

    event BuildingSpecializedThroughLogic(
        uint256 indexed buildingId,
        CityBuildingTypes.PersonalBuildingType indexed buildingType,
        CityBuildingTypes.BuildingSpecialization indexed specialization,
        address owner,
        uint64 executedAt
    );

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    ICityBuildingNFTV1PersonalLogic public buildingNFT;
    ICityBuildingPlacementPersonalRead public placement;

    IPersonalBuildingResourceAdapter public resourceAdapter;
    IPersonalBuildingPitAdapter public pitAdapter;
    IPersonalBuildingTechAdapter public techAdapter;
    IPersonalBuildingStatusHookAdapter public statusHookAdapter;
    IPersonalBuildingMintPlotAdapter public mintPlotAdapter;

    ICityBuildingFunctionRegistry public functionRegistry;
    IPersonalBuildingsVaultRead public vault;

    struct MintCostConfig {
        uint256[10] resourceAmounts;
        uint256 pitFee;
        uint32 prestigeReward;
        uint32 historyReward;
        bool configured;
    }

    struct UpgradeCostConfig {
        uint256[10] resourceAmounts;
        uint256 pitFee;
        uint64 cooldown;
        uint32 prestigeReward;
        uint32 historyReward;
        bool configured;
    }

    struct SpecializationCostConfig {
        uint256[10] resourceAmounts;
        uint256 pitFee;
        uint32 prestigeReward;
        uint32 historyReward;
        bool configured;
    }

    mapping(uint8 => MintCostConfig) private _mintConfigs;
    mapping(uint8 => mapping(uint8 => UpgradeCostConfig)) private _upgradeConfigs;
    mapping(uint8 => SpecializationCostConfig) private _specializationConfigs;

    mapping(uint256 => uint64) public lastUpgradeExecutionAt;
    mapping(uint256 => bool) public plotMintUsed;
    mapping(uint256 => uint256) public mintedBuildingIdByPlot;

    /*//////////////////////////////////////////////////////////////
                               SYNERGY TYPES
    //////////////////////////////////////////////////////////////*/

    struct PersonalSetProgress {
        bool hasResidence;
        bool hasFarmingHub;
        bool hasForge;
        bool hasWarehouse;
        bool hasMarketStall;
        bool hasGuardTower;
        bool hasResearchLab;
        uint8 uniqueCount;
        bool fullSetBonus;
    }

    struct SynergyFlags {
        bool residenceMarket;
        bool farmingWarehouse;
        bool forgeResearch;
        bool warehouseMarket;
        bool guardResearch;
        bool guardMarket;
        bool residenceResearch;
        bool forgeWarehouse;
        bool forgeMarket;
        bool warehouseGuardCore;
        bool tradeFortressCore;
        bool fullSet;
    }

    struct SynergyBonuses {
        uint32 residencePrestigePresentationBpsBonus;

        uint32 farmingClaimWindowBonusBpsBonus;
        uint32 farmingChainBonusBpsBonus;

        uint32 forgeCraftCostReductionBpsBonus;
        uint32 forgeCraftProvenanceBonusBpsBonus;
        uint32 forgeOutputQualityBpsBonus;

        uint32 warehouseReserveBucketsBonus;
        uint32 warehouseProtectedBucketsBonus;
        uint32 warehouseRaidableBucketsReduction;
        uint32 warehouseProtectionBpsBonus;
        uint32 warehouseRaidMitigationBpsBonus;

        uint16 marketListingCapBonus;
        uint32 marketFeeReductionBpsBonus;
        uint32 marketPremiumVisibilityBpsBonus;
        bool marketProvenancePremiumBonus;

        uint32 guardDefenseBpsBonus;
        uint32 guardWarehouseProtectionBpsBonus;
        uint32 guardRaidMitigationBpsBonus;
        uint8 guardRadarTierBonus;
        uint8 guardShieldTierBonus;

        uint32 researchForgeSynergyBpsBonus;
        uint8 researchBlueprintUnlockTierBonus;

        bool fullSet;
        uint32 fullSetPrestigePresentationBpsBonus;
        uint32 fullSetForgeSynergyBpsBonus;
        uint32 fullSetMarketFeeReductionBpsBonus;
        uint32 fullSetWarehouseProtectionBpsBonus;
        uint32 fullSetClaimWindowBonusBpsBonus;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address buildingNFT_,
        address placement_,
        address resourceAdapter_,
        address pitAdapter_,
        address techAdapter_,
        address statusHookAdapter_,
        address mintPlotAdapter_,
        address functionRegistry_,
        address vault_,
        address admin_
    ) {
        if (admin_ == address(0)) revert ZeroAddress();
        if (buildingNFT_ == address(0)) revert ZeroAddress();
        if (placement_ == address(0)) revert ZeroAddress();

        if (buildingNFT_.code.length == 0) revert InvalidBuildingNFT();
        if (placement_.code.length == 0) revert InvalidPlacement();
        if (resourceAdapter_ != address(0) && resourceAdapter_.code.length == 0) revert InvalidResourceAdapter();
        if (pitAdapter_ != address(0) && pitAdapter_.code.length == 0) revert InvalidPitAdapter();
        if (techAdapter_ != address(0) && techAdapter_.code.length == 0) revert InvalidTechAdapter();
        if (statusHookAdapter_ != address(0) && statusHookAdapter_.code.length == 0) revert InvalidStatusHookAdapter();
        if (mintPlotAdapter_ != address(0) && mintPlotAdapter_.code.length == 0) revert InvalidMintPlotAdapter();
        if (functionRegistry_ != address(0) && functionRegistry_.code.length == 0) revert InvalidFunctionRegistry();
        if (vault_ != address(0) && vault_.code.length == 0) revert InvalidVault();

        buildingNFT = ICityBuildingNFTV1PersonalLogic(buildingNFT_);
        placement = ICityBuildingPlacementPersonalRead(placement_);
        resourceAdapter = IPersonalBuildingResourceAdapter(resourceAdapter_);
        pitAdapter = IPersonalBuildingPitAdapter(pitAdapter_);
        techAdapter = IPersonalBuildingTechAdapter(techAdapter_);
        statusHookAdapter = IPersonalBuildingStatusHookAdapter(statusHookAdapter_);
        mintPlotAdapter = IPersonalBuildingMintPlotAdapter(mintPlotAdapter_);
        functionRegistry = ICityBuildingFunctionRegistry(functionRegistry_);
        vault = IPersonalBuildingsVaultRead(vault_);

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(LOGIC_ADMIN_ROLE, admin_);
        _grantRole(CONFIG_ROLE, admin_);
        _grantRole(OPERATOR_ROLE, admin_);
    }

    /*//////////////////////////////////////////////////////////////
                               ADMIN
    //////////////////////////////////////////////////////////////*/

    function pause() external onlyRole(LOGIC_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(LOGIC_ADMIN_ROLE) {
        _unpause();
    }

    function setBuildingNFT(address buildingNFT_) external onlyRole(LOGIC_ADMIN_ROLE) {
        if (buildingNFT_ == address(0)) revert ZeroAddress();
        if (buildingNFT_.code.length == 0) revert InvalidBuildingNFT();

        buildingNFT = ICityBuildingNFTV1PersonalLogic(buildingNFT_);
        emit BuildingNFTSet(buildingNFT_, msg.sender);
    }

    function setPlacement(address placement_) external onlyRole(LOGIC_ADMIN_ROLE) {
        if (placement_ == address(0)) revert ZeroAddress();
        if (placement_.code.length == 0) revert InvalidPlacement();

        placement = ICityBuildingPlacementPersonalRead(placement_);
        emit PlacementSet(placement_, msg.sender);
    }

    function setResourceAdapter(address adapter_) external onlyRole(LOGIC_ADMIN_ROLE) {
        if (adapter_ == address(0)) {
            resourceAdapter = IPersonalBuildingResourceAdapter(address(0));
        } else {
            if (adapter_.code.length == 0) revert InvalidResourceAdapter();
            resourceAdapter = IPersonalBuildingResourceAdapter(adapter_);
        }

        emit ResourceAdapterSet(adapter_, msg.sender);
    }

    function setPitAdapter(address adapter_) external onlyRole(LOGIC_ADMIN_ROLE) {
        if (adapter_ == address(0)) {
            pitAdapter = IPersonalBuildingPitAdapter(address(0));
        } else {
            if (adapter_.code.length == 0) revert InvalidPitAdapter();
            pitAdapter = IPersonalBuildingPitAdapter(adapter_);
        }

        emit PitAdapterSet(adapter_, msg.sender);
    }

    function setTechAdapter(address adapter_) external onlyRole(LOGIC_ADMIN_ROLE) {
        if (adapter_ == address(0)) {
            techAdapter = IPersonalBuildingTechAdapter(address(0));
        } else {
            if (adapter_.code.length == 0) revert InvalidTechAdapter();
            techAdapter = IPersonalBuildingTechAdapter(adapter_);
        }

        emit TechAdapterSet(adapter_, msg.sender);
    }

    function setStatusHookAdapter(address adapter_) external onlyRole(LOGIC_ADMIN_ROLE) {
        if (adapter_ == address(0)) {
            statusHookAdapter = IPersonalBuildingStatusHookAdapter(address(0));
        } else {
            if (adapter_.code.length == 0) revert InvalidStatusHookAdapter();
            statusHookAdapter = IPersonalBuildingStatusHookAdapter(adapter_);
        }

        emit StatusHookAdapterSet(adapter_, msg.sender);
    }

    function setMintPlotAdapter(address adapter_) external onlyRole(LOGIC_ADMIN_ROLE) {
        if (adapter_ == address(0)) {
            mintPlotAdapter = IPersonalBuildingMintPlotAdapter(address(0));
        } else {
            if (adapter_.code.length == 0) revert InvalidMintPlotAdapter();
            mintPlotAdapter = IPersonalBuildingMintPlotAdapter(adapter_);
        }

        emit MintPlotAdapterSet(adapter_, msg.sender);
    }

    function setFunctionRegistry(address registry_) external onlyRole(LOGIC_ADMIN_ROLE) {
        if (registry_ == address(0)) {
            functionRegistry = ICityBuildingFunctionRegistry(address(0));
        } else {
            if (registry_.code.length == 0) revert InvalidFunctionRegistry();
            functionRegistry = ICityBuildingFunctionRegistry(registry_);
        }

        emit FunctionRegistrySet(registry_, msg.sender);
    }

    function setVault(address vault_) external onlyRole(LOGIC_ADMIN_ROLE) {
        if (vault_ == address(0)) {
            vault = IPersonalBuildingsVaultRead(address(0));
        } else {
            if (vault_.code.length == 0) revert InvalidVault();
            vault = IPersonalBuildingsVaultRead(vault_);
        }

        emit VaultSet(vault_, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                             CONFIG SETTERS
    //////////////////////////////////////////////////////////////*/

    function setMintCostConfig(
        CityBuildingTypes.PersonalBuildingType buildingType,
        uint256[10] calldata resourceAmounts,
        uint256 pitFee,
        uint32 prestigeReward,
        uint32 historyReward,
        bool configured
    ) external onlyRole(CONFIG_ROLE) {
        if (!CityBuildingTypes.isValidBaseType(buildingType)) revert InvalidBuildingType();

        _mintConfigs[uint8(buildingType)] = MintCostConfig({
            resourceAmounts: resourceAmounts,
            pitFee: pitFee,
            prestigeReward: prestigeReward,
            historyReward: historyReward,
            configured: configured
        });

        emit MintCostConfigured(
            buildingType,
            resourceAmounts,
            pitFee,
            prestigeReward,
            historyReward,
            configured,
            msg.sender
        );
    }

    function setUpgradeCostConfig(
        CityBuildingTypes.PersonalBuildingType buildingType,
        uint8 targetLevel,
        uint256[10] calldata resourceAmounts,
        uint256 pitFee,
        uint64 cooldown,
        uint32 prestigeReward,
        uint32 historyReward,
        bool configured
    ) external onlyRole(CONFIG_ROLE) {
        if (!CityBuildingTypes.isValidBaseType(buildingType)) revert InvalidBuildingType();
        if (!CityBuildingTypes.isValidLevel(targetLevel) || targetLevel <= 1) revert InvalidLevel();

        _upgradeConfigs[uint8(buildingType)][targetLevel] = UpgradeCostConfig({
            resourceAmounts: resourceAmounts,
            pitFee: pitFee,
            cooldown: cooldown,
            prestigeReward: prestigeReward,
            historyReward: historyReward,
            configured: configured
        });

        emit UpgradeCostConfigured(
            buildingType,
            targetLevel,
            resourceAmounts,
            pitFee,
            cooldown,
            prestigeReward,
            historyReward,
            configured,
            msg.sender
        );
    }

    function setSpecializationCostConfig(
        CityBuildingTypes.BuildingSpecialization specialization,
        uint256[10] calldata resourceAmounts,
        uint256 pitFee,
        uint32 prestigeReward,
        uint32 historyReward,
        bool configured
    ) external onlyRole(CONFIG_ROLE) {
        if (specialization == CityBuildingTypes.BuildingSpecialization.None) {
            revert InvalidSpecialization();
        }

        _specializationConfigs[uint8(specialization)] = SpecializationCostConfig({
            resourceAmounts: resourceAmounts,
            pitFee: pitFee,
            prestigeReward: prestigeReward,
            historyReward: historyReward,
            configured: configured
        });

        emit SpecializationCostConfigured(
            specialization,
            resourceAmounts,
            pitFee,
            prestigeReward,
            historyReward,
            configured,
            msg.sender
        );
    }

    /*//////////////////////////////////////////////////////////////
                           OPERATOR / RECOVERY
    //////////////////////////////////////////////////////////////*/

    function setPlotMintUsage(
        uint256 plotId,
        bool used,
        uint256 buildingId
    ) external onlyRole(OPERATOR_ROLE) {
        if (plotId == 0) revert InvalidPlotId();

        plotMintUsed[plotId] = used;
        mintedBuildingIdByPlot[plotId] = used ? buildingId : 0;

        emit PlotMintEntitlementUpdated(plotId, used, mintedBuildingIdByPlot[plotId], msg.sender);
    }

    function batchSetPlotMintUsage(
        uint256[] calldata plotIds,
        bool[] calldata usedFlags,
        uint256[] calldata buildingIds
    ) external onlyRole(OPERATOR_ROLE) {
        uint256 len = plotIds.length;
        if (len != usedFlags.length || len != buildingIds.length) revert BatchLengthMismatch();
        if (len > MAX_BATCH_SET) revert BatchTooLarge(len, MAX_BATCH_SET);

        for (uint256 i = 0; i < len; i++) {
            if (plotIds[i] == 0) revert InvalidPlotId();

            plotMintUsed[plotIds[i]] = usedFlags[i];
            mintedBuildingIdByPlot[plotIds[i]] = usedFlags[i] ? buildingIds[i] : 0;

            emit PlotMintEntitlementUpdated(
                plotIds[i],
                usedFlags[i],
                mintedBuildingIdByPlot[plotIds[i]],
                msg.sender
            );
        }
    }

    function setLastUpgradeExecutionAt(
        uint256 buildingId,
        uint64 ts
    ) external onlyRole(OPERATOR_ROLE) {
        lastUpgradeExecutionAt[buildingId] = ts;
        emit LastUpgradeExecutionAtUpdated(buildingId, ts, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                           PLAYER MINT FLOW
    //////////////////////////////////////////////////////////////*/

    function mintPersonalBuildingForOwnedPlot(
        uint256 plotId,
        CityBuildingTypes.PersonalBuildingType buildingType,
        uint32 versionTag
    ) external whenNotPaused nonReentrant returns (uint256 buildingId) {
        if (!CityBuildingTypes.isValidBaseType(buildingType)) revert InvalidBuildingType();
        if (address(mintPlotAdapter) == address(0)) revert MintAdapterNotSet();
        if (plotId == 0) revert PlotNotFound();
        if (plotMintUsed[plotId]) revert PlotMintAlreadyUsed();

        (
            address plotOwner,
            bool exists,
            bool completed,
            bool personalPlot,
            bool eligible,
            uint8 districtKind,
            uint8 faction
        ) = mintPlotAdapter.getMintPlotInfo(plotId);

        districtKind;
        faction;

        if (!exists) revert PlotNotFound();
        if (plotOwner != msg.sender) revert PlotOwnerMismatch();
        if (!completed) revert PlotNotCompleted();
        if (!personalPlot) revert PlotNotPersonal();
        if (!eligible) revert PlotNotEligibleForMint();

        MintCostConfig memory cfg = _mintConfigs[uint8(buildingType)];
        if (!cfg.configured) revert MintNotConfigured();

        bytes32 reason = _mintReason(plotId, buildingType);

        _consumeResources(msg.sender, cfg.resourceAmounts, reason);
        _collectPitFee(msg.sender, cfg.pitFee, reason);

        uint32 effectiveVersionTag = versionTag == 0 ? DEFAULT_VERSION_TAG : versionTag;
        if (
            effectiveVersionTag != CityBuildingTypes.VERSION_TAG_V1 &&
            effectiveVersionTag != CityBuildingTypes.VERSION_TAG_V2
        ) revert InvalidVersionTag();

        buildingId = buildingNFT.mintBuilding(
            msg.sender,
            buildingType,
            effectiveVersionTag
        );

        plotMintUsed[plotId] = true;
        mintedBuildingIdByPlot[plotId] = buildingId;

        if (cfg.prestigeReward > 0) {
            buildingNFT.addPrestigeScore(buildingId, cfg.prestigeReward);
        }

        if (cfg.historyReward > 0) {
            buildingNFT.addHistoryScore(buildingId, cfg.historyReward);
        }

        _recordMintUsage(buildingId, buildingType);
        _touchPlotActivityIfPossible(plotId);

        emit PersonalBuildingMintedThroughLogic(
            buildingId,
            plotId,
            buildingType,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    /*//////////////////////////////////////////////////////////////
                           USER ACTIONS
    //////////////////////////////////////////////////////////////*/

    function upgradeBuilding(
        uint256 buildingId
    ) external whenNotPaused nonReentrant {
        _requireBuildingOwner(buildingId);
        _requireBuildingMutable(buildingId);

        CityBuildingTypes.BuildingCore memory core = buildingNFT.getBuildingCore(buildingId);

        if (core.category != CityBuildingTypes.BuildingCategory.Personal) revert InvalidBuildingCategory();
        if (!CityBuildingTypes.isValidBaseType(core.buildingType)) revert InvalidBuildingType();
        if (!CityBuildingTypes.isValidLevel(core.level)) revert InvalidLevel();
        if (core.level >= CityBuildingTypes.MAX_BUILDING_LEVEL) revert MaxLevelReached();

        CityBuildingTypes.BuildingState state_ = buildingNFT.getBuildingState(buildingId);
        if (
            state_ == CityBuildingTypes.BuildingState.None ||
            state_ == CityBuildingTypes.BuildingState.Archived
        ) {
            revert BuildingStateNotUpgradeable();
        }

        uint8 targetLevel = core.level + 1;
        UpgradeCostConfig memory cfg = _upgradeConfigs[uint8(core.buildingType)][targetLevel];
        if (!cfg.configured) revert UpgradeNotConfigured();

        uint64 lastExec = lastUpgradeExecutionAt[buildingId];
        if (cfg.cooldown > 0 && lastExec > 0) {
            uint64 readyAt_ = lastExec + cfg.cooldown;
            if (block.timestamp < readyAt_) revert UpgradeCooldownActive(readyAt_);
        }

        if (address(techAdapter) != address(0)) {
            (bool allowed, bytes32 reasonCode) = techAdapter.canUpgradeBuilding(
                msg.sender,
                buildingId,
                core,
                targetLevel
            );
            if (!allowed) revert TechRequirementFailed(reasonCode);
        }

        bytes32 reason = _upgradeReason(buildingId, targetLevel);

        _consumeResources(msg.sender, cfg.resourceAmounts, reason);
        _collectPitFee(msg.sender, cfg.pitFee, reason);

        uint8 oldLevel = core.level;
        buildingNFT.upgradeBuilding(buildingId, targetLevel);
        lastUpgradeExecutionAt[buildingId] = uint64(block.timestamp);

        if (cfg.prestigeReward > 0) {
            buildingNFT.addPrestigeScore(buildingId, cfg.prestigeReward);
        }

        if (cfg.historyReward > 0) {
            buildingNFT.addHistoryScore(buildingId, cfg.historyReward);
        }

        _recordLevelUsage(buildingId, core.buildingType, targetLevel);
        _touchPlacementActivityIfPossible(buildingId);

        emit BuildingUpgradedThroughLogic(
            buildingId,
            core.buildingType,
            oldLevel,
            targetLevel,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    function specializeBuilding(
        uint256 buildingId,
        CityBuildingTypes.BuildingSpecialization specialization
    ) external whenNotPaused nonReentrant {
        _requireBuildingOwner(buildingId);
        _requireBuildingMutable(buildingId);

        if (specialization == CityBuildingTypes.BuildingSpecialization.None) revert InvalidSpecialization();

        CityBuildingTypes.BuildingCore memory core = buildingNFT.getBuildingCore(buildingId);

        if (core.category != CityBuildingTypes.BuildingCategory.Personal) revert InvalidBuildingCategory();
        if (!CityBuildingTypes.isValidBaseType(core.buildingType)) revert InvalidBuildingType();
        if (!CityBuildingTypes.canChooseSpecialization(core.buildingType, core.level, specialization)) {
            revert InvalidSpecialization();
        }
        if (core.specialization == specialization) revert NoStateChange();

        CityBuildingTypes.BuildingState state_ = buildingNFT.getBuildingState(buildingId);
        if (
            state_ == CityBuildingTypes.BuildingState.None ||
            state_ == CityBuildingTypes.BuildingState.Archived
        ) {
            revert BuildingStateNotSpecializable();
        }

        SpecializationCostConfig memory cfg = _specializationConfigs[uint8(specialization)];
        if (!cfg.configured) revert SpecializationNotConfigured();

        if (address(techAdapter) != address(0)) {
            (bool allowed, bytes32 reasonCode) = techAdapter.canSpecializeBuilding(
                msg.sender,
                buildingId,
                core,
                specialization
            );
            if (!allowed) revert TechRequirementFailed(reasonCode);
        }

        bytes32 reason = _specializationReason(buildingId, specialization);

        _consumeResources(msg.sender, cfg.resourceAmounts, reason);
        _collectPitFee(msg.sender, cfg.pitFee, reason);

        buildingNFT.specializeBuilding(buildingId, specialization);

        if (cfg.prestigeReward > 0) {
            buildingNFT.addPrestigeScore(buildingId, cfg.prestigeReward);
        }

        if (cfg.historyReward > 0) {
            buildingNFT.addHistoryScore(buildingId, cfg.historyReward);
        }

        _recordSpecializationUsage(buildingId, specialization);
        _touchPlacementActivityIfPossible(buildingId);

        emit BuildingSpecializedThroughLogic(
            buildingId,
            core.buildingType,
            specialization,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    /*//////////////////////////////////////////////////////////////
                                  READS
    //////////////////////////////////////////////////////////////*/

    function getMintQuote(
        CityBuildingTypes.PersonalBuildingType buildingType
    )
        external
        view
        returns (
            uint256[10] memory resourceAmounts,
            uint256 pitFee,
            uint32 prestigeReward,
            uint32 historyReward,
            bool configured
        )
    {
        MintCostConfig memory cfg = _mintConfigs[uint8(buildingType)];
        return (
            cfg.resourceAmounts,
            cfg.pitFee,
            cfg.prestigeReward,
            cfg.historyReward,
            cfg.configured
        );
    }

    function getUpgradeQuote(
        uint256 buildingId
    )
        external
        view
        returns (
            CityBuildingTypes.PersonalBuildingType buildingType,
            uint8 currentLevel,
            uint8 targetLevel,
            uint256[10] memory resourceAmounts,
            uint256 pitFee,
            uint64 cooldown,
            uint64 lastExec,
            uint64 readyAt,
            uint32 prestigeReward,
            uint32 historyReward,
            bool configured
        )
    {
        CityBuildingTypes.BuildingCore memory core = buildingNFT.getBuildingCore(buildingId);

        buildingType = core.buildingType;
        currentLevel = core.level;

        if (!CityBuildingTypes.isValidLevel(currentLevel) || currentLevel >= CityBuildingTypes.MAX_BUILDING_LEVEL) {
            targetLevel = currentLevel;
            return (
                buildingType,
                currentLevel,
                targetLevel,
                resourceAmounts,
                0,
                0,
                0,
                0,
                0,
                0,
                false
            );
        }

        targetLevel = currentLevel + 1;

        UpgradeCostConfig memory cfg = _upgradeConfigs[uint8(buildingType)][targetLevel];
        if (!cfg.configured) {
            return (
                buildingType,
                currentLevel,
                targetLevel,
                resourceAmounts,
                0,
                0,
                0,
                0,
                0,
                0,
                false
            );
        }

        lastExec = lastUpgradeExecutionAt[buildingId];
        readyAt = cfg.cooldown == 0
            ? uint64(block.timestamp)
            : (lastExec == 0 ? uint64(block.timestamp) : lastExec + cfg.cooldown);

        return (
            buildingType,
            currentLevel,
            targetLevel,
            cfg.resourceAmounts,
            cfg.pitFee,
            cfg.cooldown,
            lastExec,
            readyAt,
            cfg.prestigeReward,
            cfg.historyReward,
            cfg.configured
        );
    }

    function getSpecializationQuote(
        CityBuildingTypes.BuildingSpecialization specialization
    )
        external
        view
        returns (
            uint256[10] memory resourceAmounts,
            uint256 pitFee,
            uint32 prestigeReward,
            uint32 historyReward,
            bool configured
        )
    {
        SpecializationCostConfig memory cfg = _specializationConfigs[uint8(specialization)];
        return (
            cfg.resourceAmounts,
            cfg.pitFee,
            cfg.prestigeReward,
            cfg.historyReward,
            cfg.configured
        );
    }

    function getMintEntitlementStatus(
        uint256 plotId
    )
        external
        view
        returns (
            bool used,
            uint256 mintedBuildingId,
            address owner,
            bool exists,
            bool completed,
            bool personalPlot,
            bool eligible,
            uint8 districtKind,
            uint8 faction
        )
    {
        used = plotMintUsed[plotId];
        mintedBuildingId = mintedBuildingIdByPlot[plotId];

        if (address(mintPlotAdapter) == address(0)) {
            return (used, mintedBuildingId, address(0), false, false, false, false, 0, 0);
        }

        (
            owner,
            exists,
            completed,
            personalPlot,
            eligible,
            districtKind,
            faction
        ) = mintPlotAdapter.getMintPlotInfo(plotId);
    }

    function getPlacementSnapshot(
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
        )
    {
        return placement.getPlacementSummary(buildingId);
    }

    function getPersonalSetProgress(
        address owner,
        uint256[] calldata buildingIds
    ) external view returns (PersonalSetProgress memory progress) {
        if (buildingIds.length == 0) revert NoIdsProvided();
        return _buildPersonalSetProgress(owner, buildingIds);
    }

    function evaluateSynergies(
        address owner,
        uint256[] calldata buildingIds,
        uint8 minimumLevel
    ) external view returns (SynergyFlags memory s) {
        if (buildingIds.length == 0) revert NoIdsProvided();

        (
            bool hasResidence,
            bool hasFarmingHub,
            bool hasForge,
            bool hasWarehouse,
            bool hasMarketStall,
            bool hasGuardTower,
            bool hasResearchLab
        ) = _scanSynergyPresence(owner, buildingIds, minimumLevel);

        s.residenceMarket = minimumLevel >= 2 && hasResidence && hasMarketStall;
        s.farmingWarehouse = minimumLevel >= 2 && hasFarmingHub && hasWarehouse;
        s.forgeResearch = minimumLevel >= 2 && hasForge && hasResearchLab;
        s.warehouseMarket = minimumLevel >= 2 && hasWarehouse && hasMarketStall;
        s.guardResearch = minimumLevel >= 2 && hasGuardTower && hasResearchLab;
        s.guardMarket = minimumLevel >= 2 && hasGuardTower && hasMarketStall;
        s.residenceResearch = minimumLevel >= 2 && hasResidence && hasResearchLab;
        s.forgeWarehouse = minimumLevel >= 2 && hasForge && hasWarehouse;
        s.forgeMarket = minimumLevel >= 2 && hasForge && hasMarketStall;
        s.warehouseGuardCore = minimumLevel >= 3 && hasWarehouse && hasGuardTower;
        s.tradeFortressCore = minimumLevel >= 3 && hasWarehouse && hasMarketStall && hasGuardTower;
        s.fullSet =
            minimumLevel >= 4 &&
            hasResidence &&
            hasFarmingHub &&
            hasForge &&
            hasWarehouse &&
            hasMarketStall &&
            hasGuardTower &&
            hasResearchLab;
    }

    function getSynergyBonuses(
        address owner,
        uint256[] calldata buildingIds,
        uint8 minimumLevel
    ) external view returns (SynergyBonuses memory bonuses) {
        return _calculateSynergyBonuses(owner, buildingIds, minimumLevel);
    }

    function getMintCostConfig(
        CityBuildingTypes.PersonalBuildingType buildingType
    ) external view returns (MintCostConfig memory) {
        return _mintConfigs[uint8(buildingType)];
    }

    function getUpgradeCostConfig(
        CityBuildingTypes.PersonalBuildingType buildingType,
        uint8 targetLevel
    ) external view returns (UpgradeCostConfig memory) {
        return _upgradeConfigs[uint8(buildingType)][targetLevel];
    }

    function getSpecializationCostConfig(
        CityBuildingTypes.BuildingSpecialization specialization
    ) external view returns (SpecializationCostConfig memory) {
        return _specializationConfigs[uint8(specialization)];
    }

    function getBuildingFunctionProfile(
        uint256 buildingId
    ) external view returns (ICityBuildingFunctionRegistry.FunctionProfile memory) {
        if (address(functionRegistry) == address(0)) revert FunctionRegistryNotSet();
        return functionRegistry.getFunctionProfile(buildingId);
    }

    function getFunctionProfileWithSynergies(
        uint256 buildingId,
        uint256[] calldata allBuildingIdsOfOwner,
        uint8 minSynergyLevel
    ) external view returns (ICityBuildingFunctionRegistry.FunctionProfile memory profile) {
        if (address(functionRegistry) == address(0)) revert FunctionRegistryNotSet();

        profile = functionRegistry.getFunctionProfile(buildingId);

        address owner = buildingNFT.ownerOf(buildingId);
        SynergyBonuses memory bonuses = _calculateSynergyBonuses(
            owner,
            allBuildingIdsOfOwner,
            minSynergyLevel
        );

        if (profile.buildingType == CityBuildingTypes.PersonalBuildingType.Residence) {
            profile.prestigePresentationBps +=
                bonuses.residencePrestigePresentationBpsBonus +
                bonuses.fullSetPrestigePresentationBpsBonus;
        } else if (profile.buildingType == CityBuildingTypes.PersonalBuildingType.FarmingHub) {
            profile.claimWindowBonusBps +=
                bonuses.farmingClaimWindowBonusBpsBonus +
                bonuses.fullSetClaimWindowBonusBpsBonus;
        } else if (profile.buildingType == CityBuildingTypes.PersonalBuildingType.Forge) {
            profile.craftCostReductionBps += bonuses.forgeCraftCostReductionBpsBonus;
            profile.craftProvenanceBonusBps += bonuses.forgeCraftProvenanceBonusBpsBonus;
            profile.outputQualityBps += bonuses.forgeOutputQualityBpsBonus;
        } else if (profile.buildingType == CityBuildingTypes.PersonalBuildingType.Warehouse) {
            profile.warehouseProtectionBps +=
                bonuses.warehouseProtectionBpsBonus +
                bonuses.fullSetWarehouseProtectionBpsBonus;
            profile.raidMitigationBps += bonuses.warehouseRaidMitigationBpsBonus;
        } else if (profile.buildingType == CityBuildingTypes.PersonalBuildingType.MarketStall) {
            profile.listingCap += bonuses.marketListingCapBonus;
            profile.marketFeeReductionBps +=
                bonuses.marketFeeReductionBpsBonus +
                bonuses.fullSetMarketFeeReductionBpsBonus;
            profile.premiumVisibilityBps += bonuses.marketPremiumVisibilityBpsBonus;
            if (bonuses.marketProvenancePremiumBonus) {
                profile.provenancePremium = true;
            }
        } else if (profile.buildingType == CityBuildingTypes.PersonalBuildingType.GuardTower) {
            profile.defenseBps += bonuses.guardDefenseBpsBonus;
            profile.warehouseProtectionBps +=
                bonuses.guardWarehouseProtectionBpsBonus +
                bonuses.fullSetWarehouseProtectionBpsBonus;
            profile.raidMitigationBps += bonuses.guardRaidMitigationBpsBonus;
            profile.radarTier += bonuses.guardRadarTierBonus;
            profile.shieldTier += bonuses.guardShieldTierBonus;
        } else if (profile.buildingType == CityBuildingTypes.PersonalBuildingType.ResearchLab) {
            profile.forgeSynergyBps +=
                bonuses.researchForgeSynergyBpsBonus +
                bonuses.fullSetForgeSynergyBpsBonus;
            profile.blueprintUnlockTier += bonuses.researchBlueprintUnlockTierBonus;
        }

        if (bonuses.fullSet) {
            profile.fullSetEligible = true;
        }
    }

    function getResidenceProfile(
        uint256 buildingId
    ) external view returns (ICityBuildingFunctionRegistry.ResidenceProfile memory) {
        if (address(functionRegistry) == address(0)) revert FunctionRegistryNotSet();
        return functionRegistry.getResidenceProfile(buildingId);
    }

    function getResidenceProfileWithSynergies(
        uint256 buildingId,
        uint256[] calldata allBuildingIdsOfOwner,
        uint8 minSynergyLevel
    ) external view returns (ICityBuildingFunctionRegistry.ResidenceProfile memory profile) {
        if (address(functionRegistry) == address(0)) revert FunctionRegistryNotSet();

        profile = functionRegistry.getResidenceProfile(buildingId);

        address owner = buildingNFT.ownerOf(buildingId);
        SynergyBonuses memory bonuses = _calculateSynergyBonuses(
            owner,
            allBuildingIdsOfOwner,
            minSynergyLevel
        );

        profile.prestigePresentationBps +=
            bonuses.residencePrestigePresentationBpsBonus +
            bonuses.fullSetPrestigePresentationBpsBonus;
    }

    function getFarmingHubProfile(
        uint256 buildingId
    ) external view returns (ICityBuildingFunctionRegistry.FarmingHubProfile memory) {
        if (address(functionRegistry) == address(0)) revert FunctionRegistryNotSet();
        return functionRegistry.getFarmingHubProfile(buildingId);
    }

    function getFarmingHubProfileWithSynergies(
        uint256 buildingId,
        uint256[] calldata allBuildingIdsOfOwner,
        uint8 minSynergyLevel
    ) external view returns (ICityBuildingFunctionRegistry.FarmingHubProfile memory profile) {
        if (address(functionRegistry) == address(0)) revert FunctionRegistryNotSet();

        profile = functionRegistry.getFarmingHubProfile(buildingId);

        address owner = buildingNFT.ownerOf(buildingId);
        SynergyBonuses memory bonuses = _calculateSynergyBonuses(
            owner,
            allBuildingIdsOfOwner,
            minSynergyLevel
        );

        profile.claimWindowBonusBps +=
            bonuses.farmingClaimWindowBonusBpsBonus +
            bonuses.fullSetClaimWindowBonusBpsBonus;
        profile.chainBonusBps += bonuses.farmingChainBonusBpsBonus;
    }

    function getForgeProfile(
        uint256 buildingId
    ) external view returns (ICityBuildingFunctionRegistry.ForgeProfile memory) {
        if (address(functionRegistry) == address(0)) revert FunctionRegistryNotSet();
        return functionRegistry.getForgeProfile(buildingId);
    }

    function getForgeProfileWithSynergies(
        uint256 buildingId,
        uint256[] calldata allBuildingIdsOfOwner,
        uint8 minSynergyLevel
    ) external view returns (ICityBuildingFunctionRegistry.ForgeProfile memory profile) {
        if (address(functionRegistry) == address(0)) revert FunctionRegistryNotSet();

        profile = functionRegistry.getForgeProfile(buildingId);

        address owner = buildingNFT.ownerOf(buildingId);
        SynergyBonuses memory bonuses = _calculateSynergyBonuses(
            owner,
            allBuildingIdsOfOwner,
            minSynergyLevel
        );

        profile.craftCostReductionBps += bonuses.forgeCraftCostReductionBpsBonus;
        profile.craftProvenanceBonusBps += bonuses.forgeCraftProvenanceBonusBpsBonus;
        profile.outputQualityBps += bonuses.forgeOutputQualityBpsBonus;
    }

    function getWarehouseProfile(
        uint256 buildingId
    ) external view returns (ICityBuildingFunctionRegistry.WarehouseProfile memory) {
        if (address(functionRegistry) == address(0)) revert FunctionRegistryNotSet();
        return functionRegistry.getWarehouseProfile(buildingId);
    }

    function getWarehouseProfileWithSynergies(
        uint256 buildingId,
        uint256[] calldata allBuildingIdsOfOwner,
        uint8 minSynergyLevel
    ) external view returns (ICityBuildingFunctionRegistry.WarehouseProfile memory profile) {
        if (address(functionRegistry) == address(0)) revert FunctionRegistryNotSet();

        profile = functionRegistry.getWarehouseProfile(buildingId);

        address owner = buildingNFT.ownerOf(buildingId);
        SynergyBonuses memory bonuses = _calculateSynergyBonuses(
            owner,
            allBuildingIdsOfOwner,
            minSynergyLevel
        );

        profile.reserveBuckets += bonuses.warehouseReserveBucketsBonus;
        profile.protectedBuckets += bonuses.warehouseProtectedBucketsBonus;

        if (bonuses.warehouseRaidableBucketsReduction != 0) {
            if (profile.raidableBuckets > bonuses.warehouseRaidableBucketsReduction) {
                profile.raidableBuckets -= bonuses.warehouseRaidableBucketsReduction;
            } else {
                profile.raidableBuckets = 0;
            }
        }
    }

    function getMarketStallProfile(
        uint256 buildingId
    ) external view returns (ICityBuildingFunctionRegistry.MarketStallProfile memory) {
        if (address(functionRegistry) == address(0)) revert FunctionRegistryNotSet();
        return functionRegistry.getMarketStallProfile(buildingId);
    }

    function getMarketStallProfileWithSynergies(
        uint256 buildingId,
        uint256[] calldata allBuildingIdsOfOwner,
        uint8 minSynergyLevel
    ) external view returns (ICityBuildingFunctionRegistry.MarketStallProfile memory profile) {
        if (address(functionRegistry) == address(0)) revert FunctionRegistryNotSet();

        profile = functionRegistry.getMarketStallProfile(buildingId);

        address owner = buildingNFT.ownerOf(buildingId);
        SynergyBonuses memory bonuses = _calculateSynergyBonuses(
            owner,
            allBuildingIdsOfOwner,
            minSynergyLevel
        );

        profile.listingCap += bonuses.marketListingCapBonus;
        profile.marketFeeReductionBps +=
            bonuses.marketFeeReductionBpsBonus +
            bonuses.fullSetMarketFeeReductionBpsBonus;
        profile.premiumVisibilityBps += bonuses.marketPremiumVisibilityBpsBonus;

        if (bonuses.marketProvenancePremiumBonus) {
            profile.provenancePremium = true;
        }
    }

    function getGuardTowerProfile(
        uint256 buildingId
    ) external view returns (ICityBuildingFunctionRegistry.GuardTowerProfile memory) {
        if (address(functionRegistry) == address(0)) revert FunctionRegistryNotSet();
        return functionRegistry.getGuardTowerProfile(buildingId);
    }

    function getGuardTowerProfileWithSynergies(
        uint256 buildingId,
        uint256[] calldata allBuildingIdsOfOwner,
        uint8 minSynergyLevel
    ) external view returns (ICityBuildingFunctionRegistry.GuardTowerProfile memory profile) {
        if (address(functionRegistry) == address(0)) revert FunctionRegistryNotSet();

        profile = functionRegistry.getGuardTowerProfile(buildingId);

        address owner = buildingNFT.ownerOf(buildingId);
        SynergyBonuses memory bonuses = _calculateSynergyBonuses(
            owner,
            allBuildingIdsOfOwner,
            minSynergyLevel
        );

        profile.defenseBps += bonuses.guardDefenseBpsBonus;
        profile.warehouseProtectionBps +=
            bonuses.guardWarehouseProtectionBpsBonus +
            bonuses.fullSetWarehouseProtectionBpsBonus;
        profile.raidMitigationBps += bonuses.guardRaidMitigationBpsBonus;
        profile.radarTier += bonuses.guardRadarTierBonus;
        profile.shieldTier += bonuses.guardShieldTierBonus;
    }

    function getResearchLabProfile(
        uint256 buildingId
    ) external view returns (ICityBuildingFunctionRegistry.ResearchLabProfile memory) {
        if (address(functionRegistry) == address(0)) revert FunctionRegistryNotSet();
        return functionRegistry.getResearchLabProfile(buildingId);
    }

    function getResearchLabProfileWithSynergies(
        uint256 buildingId,
        uint256[] calldata allBuildingIdsOfOwner,
        uint8 minSynergyLevel
    ) external view returns (ICityBuildingFunctionRegistry.ResearchLabProfile memory profile) {
        if (address(functionRegistry) == address(0)) revert FunctionRegistryNotSet();

        profile = functionRegistry.getResearchLabProfile(buildingId);

        address owner = buildingNFT.ownerOf(buildingId);
        SynergyBonuses memory bonuses = _calculateSynergyBonuses(
            owner,
            allBuildingIdsOfOwner,
            minSynergyLevel
        );

        profile.forgeSynergyBps +=
            bonuses.researchForgeSynergyBpsBonus +
            bonuses.fullSetForgeSynergyBpsBonus;
        profile.blueprintUnlockTier += bonuses.researchBlueprintUnlockTierBonus;
    }

    function getWarehouseVaultProfile(
        uint256 buildingId
    ) external view returns (ICityBuildingVault.WarehouseVaultProfile memory) {
        _requireWarehouseVault(buildingId);
        return vault.getWarehouseVaultProfile(buildingId);
    }

    function getWarehouseVaultResourceState(
        uint256 buildingId,
        uint8 resourceId
    ) external view returns (ICityBuildingVault.VaultResourceState memory) {
        _requireWarehouseVault(buildingId);
        if (resourceId >= RESOURCE_SLOT_COUNT) revert InvalidResourceId();

        return vault.getWarehouseVaultResourceState(buildingId, resourceId);
    }

    function isWarehouseVaultEnabled(
        uint256 buildingId
    ) external view returns (bool) {
        _requireWarehouseVault(buildingId);
        return vault.isWarehouseVaultEnabled(buildingId);
    }

    function getWarehouseVaultDefenseProfile(
        uint256 buildingId
    )
        external
        view
        returns (
            uint8 defenseTier,
            uint32 defenseBps,
            uint32 raidMitigationBps,
            uint32 damageBps
        )
    {
        _requireWarehouseVault(buildingId);
        return vault.getWarehouseVaultDefenseProfile(buildingId);
    }

    function getWarehouseVaultTotals(
        uint256 buildingId
    )
        external
        view
        returns (
            uint256 totalStored,
            uint256 totalReserved,
            uint256 totalProtected,
            uint256 totalRaidable
        )
    {
        _requireWarehouseVault(buildingId);
        return vault.getWarehouseVaultTotals(buildingId);
    }

    function getBuildingDurabilityState(
        uint256 buildingId
    )
        external
        view
        returns (
            uint8 decayState,
            uint8 repairState,
            uint32 damageBps,
            bool repairRequired,
            uint64 lastDecayCheckAt,
            uint64 lastRepairAt
        )
    {
        _requireWarehouseVault(buildingId);
        return vault.getBuildingDurabilityState(buildingId);
    }

    function getRecommendedWarehouseVaultProfile(
        uint256 buildingId
    )
        external
        view
        returns (
            uint8 vaultTier,
            uint8 defenseTier,
            uint32 vaultCapBps,
            uint32 defenseBps,
            uint32 raidMitigationBps,
            bool decayPrepared,
            bool repairPrepared,
            bool raidEligibleByLevel
        )
    {
        _requireWarehouseVault(buildingId);
        return vault.getRecommendedWarehouseVaultProfile(buildingId);
    }

    function getRecommendedWarehouseBuckets(
        uint256 buildingId
    )
        external
        view
        returns (
            uint32 reserveBuckets,
            uint32 protectedBuckets,
            uint32 raidableBuckets
        )
    {
        _requireWarehouseVault(buildingId);
        return vault.getRecommendedWarehouseBuckets(buildingId);
    }

    function getResourceYieldConfig(
        uint8 resourceId
    )
        external
        view
        returns (
            uint32 sevenDayBaseBps,
            uint32 thirtyDayBaseBps,
            bool enabled
        )
    {
        if (address(vault) == address(0)) revert VaultNotSet();
        if (resourceId >= RESOURCE_SLOT_COUNT) revert InvalidResourceId();

        return vault.getResourceYieldConfig(resourceId);
    }

    function getWarehouseYieldPosition(
        uint256 buildingId,
        uint8 resourceId
    )
        external
        view
        returns (
            uint256 amount,
            uint256 protectionShiftedAmount,
            uint64 startedAt,
            uint64 maturityAt,
            uint8 lockMode,
            uint32 effectiveYieldBps,
            bool active,
            bool matured,
            uint256 previewYieldAmount
        )
    {
        _requireWarehouseVault(buildingId);
        if (resourceId >= RESOURCE_SLOT_COUNT) revert InvalidResourceId();

        return vault.getWarehouseYieldPosition(buildingId, resourceId);
    }

    function previewWarehouseYieldSettlement(
        uint256 buildingId,
        uint8 resourceId
    )
        external
        view
        returns (
            uint256 principalAmount,
            uint256 yieldAmount,
            bool matured,
            uint64 maturityAt
        )
    {
        _requireWarehouseVault(buildingId);
        if (resourceId >= RESOURCE_SLOT_COUNT) revert InvalidResourceId();

        return vault.previewWarehouseYieldSettlement(buildingId, resourceId);
    }

    function isWarehouseYieldEligible(
        uint256 buildingId
    ) external view returns (bool) {
        _requireWarehouseVault(buildingId);
        return vault.isWarehouseYieldEligible(buildingId);
    }

    function getEffectiveWarehouseYieldBps(
        uint256 buildingId,
        uint8 resourceId,
        uint8 lockMode
    ) external view returns (uint32) {
        _requireWarehouseVault(buildingId);
        if (resourceId >= RESOURCE_SLOT_COUNT) revert InvalidResourceId();

        return vault.getEffectiveWarehouseYieldBps(buildingId, resourceId, lockMode);
    }

    /*//////////////////////////////////////////////////////////////
                               INTERNALS
    //////////////////////////////////////////////////////////////*/

    function _requireBuildingOwner(uint256 buildingId) internal view {
        if (buildingNFT.ownerOf(buildingId) != msg.sender) revert NotBuildingOwner();
    }

    function _requireBuildingMutable(uint256 buildingId) internal view {
        if (buildingNFT.isArchived(buildingId)) revert BuildingArchived();
        if (buildingNFT.isMigrationPrepared(buildingId)) revert BuildingPreparedForMigration();
    }

    function _requireWarehouseVault(uint256 buildingId) internal view {
        if (address(vault) == address(0)) revert VaultNotSet();

        CityBuildingTypes.BuildingCore memory core = buildingNFT.getBuildingCore(buildingId);
        if (core.buildingType != CityBuildingTypes.PersonalBuildingType.Warehouse) {
            revert NotWarehouseBuilding();
        }
    }

    function _consumeResources(
        address from,
        uint256[10] memory amounts,
        bytes32 reason
    ) internal {
        bool hasCost;
        for (uint256 i = 0; i < RESOURCE_SLOT_COUNT; i++) {
            if (amounts[i] != 0) {
                hasCost = true;
                break;
            }
        }

        if (!hasCost) return;
        if (address(resourceAdapter) == address(0)) revert InvalidConfig();

        resourceAdapter.burnResourceBundle(from, amounts, reason);
    }

    function _collectPitFee(
        address from,
        uint256 amount,
        bytes32 reason
    ) internal {
        if (amount == 0) return;
        if (address(pitAdapter) == address(0)) revert InvalidConfig();

        pitAdapter.collectPitFee(from, amount, reason);
    }

    function _touchPlotActivityIfPossible(uint256 plotId) internal {
        if (address(statusHookAdapter) == address(0)) return;
        if (plotId == 0) return;

        statusHookAdapter.touchPlotActivity(plotId);
    }

    function _touchPlacementActivityIfPossible(uint256 buildingId) internal {
        if (address(statusHookAdapter) == address(0)) return;

        (
            uint256 plotId,
            bool placed,
            ,
            ,
            ,
            ,
            address placedBy
        ) = placement.getPlacementSummary(buildingId);

        placedBy;

        if (placed && plotId != 0) {
            statusHookAdapter.touchPlotActivity(plotId);
        }
    }

    function _recordMintUsage(
        uint256 buildingId,
        CityBuildingTypes.PersonalBuildingType buildingType
    ) internal {
        if (buildingType == CityBuildingTypes.PersonalBuildingType.Residence) {
            buildingNFT.recordUsage(buildingId, CityBuildingTypes.BuildingUsageType.Visit, 1);
        } else if (buildingType == CityBuildingTypes.PersonalBuildingType.FarmingHub) {
            buildingNFT.recordUsage(buildingId, CityBuildingTypes.BuildingUsageType.FarmingBoostActivation, 1);
        } else if (buildingType == CityBuildingTypes.PersonalBuildingType.Forge) {
            buildingNFT.recordUsage(buildingId, CityBuildingTypes.BuildingUsageType.Craft, 1);
        } else if (buildingType == CityBuildingTypes.PersonalBuildingType.Warehouse) {
            buildingNFT.recordUsage(buildingId, CityBuildingTypes.BuildingUsageType.StorageDeposit, 1);
        } else if (buildingType == CityBuildingTypes.PersonalBuildingType.MarketStall) {
            buildingNFT.recordUsage(buildingId, CityBuildingTypes.BuildingUsageType.MarketListingCreate, 1);
        } else if (buildingType == CityBuildingTypes.PersonalBuildingType.GuardTower) {
            buildingNFT.recordUsage(buildingId, CityBuildingTypes.BuildingUsageType.DefenseSupport, 1);
        } else if (buildingType == CityBuildingTypes.PersonalBuildingType.ResearchLab) {
            buildingNFT.recordUsage(buildingId, CityBuildingTypes.BuildingUsageType.ResearchComplete, 1);
        }
    }

    function _recordLevelUsage(
        uint256 buildingId,
        CityBuildingTypes.PersonalBuildingType buildingType,
        uint8 targetLevel
    ) internal {
        if (buildingType == CityBuildingTypes.PersonalBuildingType.FarmingHub) {
            buildingNFT.recordUsage(buildingId, CityBuildingTypes.BuildingUsageType.FarmingBoostActivation, 1);
        } else if (buildingType == CityBuildingTypes.PersonalBuildingType.Forge) {
            if (targetLevel >= 7) {
                buildingNFT.recordUsage(buildingId, CityBuildingTypes.BuildingUsageType.BuildingEvolution, 1);
            } else {
                buildingNFT.recordUsage(buildingId, CityBuildingTypes.BuildingUsageType.Craft, 1);
            }
        } else if (buildingType == CityBuildingTypes.PersonalBuildingType.Warehouse) {
            buildingNFT.recordUsage(buildingId, CityBuildingTypes.BuildingUsageType.StorageYieldClaim, 1);
        } else if (buildingType == CityBuildingTypes.PersonalBuildingType.MarketStall) {
            buildingNFT.recordUsage(buildingId, CityBuildingTypes.BuildingUsageType.MarketListingCreate, 1);
        } else if (buildingType == CityBuildingTypes.PersonalBuildingType.GuardTower) {
            buildingNFT.recordUsage(buildingId, CityBuildingTypes.BuildingUsageType.DefenseSupport, 1);
        } else if (buildingType == CityBuildingTypes.PersonalBuildingType.ResearchLab) {
            buildingNFT.recordUsage(buildingId, CityBuildingTypes.BuildingUsageType.ResearchComplete, 1);
        } else if (buildingType == CityBuildingTypes.PersonalBuildingType.Residence) {
            buildingNFT.recordUsage(buildingId, CityBuildingTypes.BuildingUsageType.Visit, 1);
        }
    }

    function _recordSpecializationUsage(
        uint256 buildingId,
        CityBuildingTypes.BuildingSpecialization specialization
    ) internal {
        if (
            specialization == CityBuildingTypes.BuildingSpecialization.WeaponForge ||
            specialization == CityBuildingTypes.BuildingSpecialization.RelicForge ||
            specialization == CityBuildingTypes.BuildingSpecialization.ComponentForge ||
            specialization == CityBuildingTypes.BuildingSpecialization.MasterForge
        ) {
            buildingNFT.recordUsage(buildingId, CityBuildingTypes.BuildingUsageType.RecipeCreate, 1);
        } else if (specialization == CityBuildingTypes.BuildingSpecialization.MasterLab) {
            buildingNFT.recordUsage(buildingId, CityBuildingTypes.BuildingUsageType.DiscoveryUnlock, 1);
        } else if (
            specialization == CityBuildingTypes.BuildingSpecialization.RadarTower ||
            specialization == CityBuildingTypes.BuildingSpecialization.DefenseTower ||
            specialization == CityBuildingTypes.BuildingSpecialization.MercenaryTower ||
            specialization == CityBuildingTypes.BuildingSpecialization.ShieldTower
        ) {
            buildingNFT.recordUsage(buildingId, CityBuildingTypes.BuildingUsageType.DefenseSupport, 1);
        } else if (
            specialization == CityBuildingTypes.BuildingSpecialization.MerchantHouse ||
            specialization == CityBuildingTypes.BuildingSpecialization.TradeDepot ||
            specialization == CityBuildingTypes.BuildingSpecialization.MerchantVault
        ) {
            buildingNFT.recordUsage(buildingId, CityBuildingTypes.BuildingUsageType.MarketSale, 1);
        } else if (
            specialization == CityBuildingTypes.BuildingSpecialization.GalleryHouse ||
            specialization == CityBuildingTypes.BuildingSpecialization.TrophyHall
        ) {
            buildingNFT.recordUsage(buildingId, CityBuildingTypes.BuildingUsageType.ShowcaseOpen, 1);
        }
    }

    function _buildPersonalSetProgress(
        address owner,
        uint256[] calldata buildingIds
    ) internal view returns (PersonalSetProgress memory progress) {
        uint256 len = buildingIds.length;

        for (uint256 i = 0; i < len; i++) {
            uint256 buildingId = buildingIds[i];

            if (buildingNFT.ownerOf(buildingId) != owner) continue;
            if (buildingNFT.isArchived(buildingId)) continue;
            if (buildingNFT.isMigrationPrepared(buildingId)) continue;

            CityBuildingTypes.BuildingCore memory core = buildingNFT.getBuildingCore(buildingId);
            if (core.category != CityBuildingTypes.BuildingCategory.Personal) continue;

            if (core.buildingType == CityBuildingTypes.PersonalBuildingType.Residence && !progress.hasResidence) {
                progress.hasResidence = true;
                progress.uniqueCount += 1;
            } else if (core.buildingType == CityBuildingTypes.PersonalBuildingType.FarmingHub && !progress.hasFarmingHub) {
                progress.hasFarmingHub = true;
                progress.uniqueCount += 1;
            } else if (core.buildingType == CityBuildingTypes.PersonalBuildingType.Forge && !progress.hasForge) {
                progress.hasForge = true;
                progress.uniqueCount += 1;
            } else if (core.buildingType == CityBuildingTypes.PersonalBuildingType.Warehouse && !progress.hasWarehouse) {
                progress.hasWarehouse = true;
                progress.uniqueCount += 1;
            } else if (core.buildingType == CityBuildingTypes.PersonalBuildingType.MarketStall && !progress.hasMarketStall) {
                progress.hasMarketStall = true;
                progress.uniqueCount += 1;
            } else if (core.buildingType == CityBuildingTypes.PersonalBuildingType.GuardTower && !progress.hasGuardTower) {
                progress.hasGuardTower = true;
                progress.uniqueCount += 1;
            } else if (core.buildingType == CityBuildingTypes.PersonalBuildingType.ResearchLab && !progress.hasResearchLab) {
                progress.hasResearchLab = true;
                progress.uniqueCount += 1;
            }
        }

        progress.fullSetBonus =
            progress.hasResidence &&
            progress.hasFarmingHub &&
            progress.hasForge &&
            progress.hasWarehouse &&
            progress.hasMarketStall &&
            progress.hasGuardTower &&
            progress.hasResearchLab;
    }

    function _scanSynergyPresence(
        address owner,
        uint256[] calldata buildingIds,
        uint8 minimumLevel
    )
        internal
        view
        returns (
            bool hasResidence,
            bool hasFarmingHub,
            bool hasForge,
            bool hasWarehouse,
            bool hasMarketStall,
            bool hasGuardTower,
            bool hasResearchLab
        )
    {
        uint256 len = buildingIds.length;

        for (uint256 i = 0; i < len; i++) {
            uint256 buildingId = buildingIds[i];

            if (buildingNFT.ownerOf(buildingId) != owner) continue;
            if (buildingNFT.isArchived(buildingId)) continue;
            if (buildingNFT.isMigrationPrepared(buildingId)) continue;

            CityBuildingTypes.BuildingCore memory core = buildingNFT.getBuildingCore(buildingId);
            if (core.category != CityBuildingTypes.BuildingCategory.Personal) continue;
            if (core.level < minimumLevel) continue;

            if (core.buildingType == CityBuildingTypes.PersonalBuildingType.Residence) hasResidence = true;
            else if (core.buildingType == CityBuildingTypes.PersonalBuildingType.FarmingHub) hasFarmingHub = true;
            else if (core.buildingType == CityBuildingTypes.PersonalBuildingType.Forge) hasForge = true;
            else if (core.buildingType == CityBuildingTypes.PersonalBuildingType.Warehouse) hasWarehouse = true;
            else if (core.buildingType == CityBuildingTypes.PersonalBuildingType.MarketStall) hasMarketStall = true;
            else if (core.buildingType == CityBuildingTypes.PersonalBuildingType.GuardTower) hasGuardTower = true;
            else if (core.buildingType == CityBuildingTypes.PersonalBuildingType.ResearchLab) hasResearchLab = true;
        }
    }

    function _calculateSynergyBonuses(
        address owner,
        uint256[] calldata buildingIds,
        uint8 minimumLevel
    ) internal view returns (SynergyBonuses memory bonuses) {
        if (buildingIds.length == 0) return bonuses;

        (
            bool hasResidence,
            bool hasFarmingHub,
            bool hasForge,
            bool hasWarehouse,
            bool hasMarketStall,
            bool hasGuardTower,
            bool hasResearchLab
        ) = _scanSynergyPresence(owner, buildingIds, minimumLevel);

        bool miniCombos = minimumLevel >= 2;
        bool coreCombos = minimumLevel >= 3;
        bool fullSetActive =
            minimumLevel >= 4 &&
            hasResidence &&
            hasFarmingHub &&
            hasForge &&
            hasWarehouse &&
            hasMarketStall &&
            hasGuardTower &&
            hasResearchLab;

        if (miniCombos && hasResidence && hasMarketStall) {
            bonuses.residencePrestigePresentationBpsBonus += 100;
            bonuses.marketPremiumVisibilityBpsBonus += 100;

            if (minimumLevel >= 3) {
                bonuses.marketProvenancePremiumBonus = true;
            }
        }

        if (miniCombos && hasFarmingHub && hasWarehouse) {
            bonuses.farmingChainBonusBpsBonus += 150;
            bonuses.warehouseReserveBucketsBonus += 1;
        }

        if (miniCombos && hasForge && hasResearchLab) {
            bonuses.forgeCraftProvenanceBonusBpsBonus += 100;
            bonuses.forgeOutputQualityBpsBonus += 75;
            bonuses.researchForgeSynergyBpsBonus += 200;
        }

        if (miniCombos && hasWarehouse && hasMarketStall) {
            bonuses.marketListingCapBonus += 2;
            bonuses.marketFeeReductionBpsBonus += 75;
            bonuses.warehouseReserveBucketsBonus += 1;
        }

        if (miniCombos && hasGuardTower && hasResearchLab) {
            bonuses.guardRadarTierBonus += 1;
            bonuses.guardDefenseBpsBonus += 100;
            bonuses.guardRaidMitigationBpsBonus += 100;
            bonuses.researchBlueprintUnlockTierBonus += 1;
        }

        if (miniCombos && hasGuardTower && hasMarketStall) {
            bonuses.marketFeeReductionBpsBonus += 50;
            bonuses.marketPremiumVisibilityBpsBonus += 50;
        }

        if (miniCombos && hasResidence && hasResearchLab) {
            bonuses.residencePrestigePresentationBpsBonus += 100;
        }

        if (miniCombos && hasForge && hasWarehouse) {
            bonuses.forgeCraftCostReductionBpsBonus += 75;
            bonuses.warehouseReserveBucketsBonus += 1;
        }

        if (miniCombos && hasForge && hasMarketStall) {
            bonuses.marketPremiumVisibilityBpsBonus += 100;
            bonuses.marketProvenancePremiumBonus = true;
        }

        if (coreCombos && hasWarehouse && hasGuardTower) {
            bonuses.warehouseProtectedBucketsBonus += 1;
            bonuses.warehouseRaidableBucketsReduction += 1;
            bonuses.warehouseProtectionBpsBonus += 300;
            bonuses.warehouseRaidMitigationBpsBonus += 200;

            bonuses.guardWarehouseProtectionBpsBonus += 300;
            bonuses.guardRaidMitigationBpsBonus += 200;
        }

        if (coreCombos && hasWarehouse && hasMarketStall && hasGuardTower) {
            bonuses.marketListingCapBonus += 3;
            bonuses.marketFeeReductionBpsBonus += 150;
            bonuses.marketPremiumVisibilityBpsBonus += 100;
            bonuses.marketProvenancePremiumBonus = true;

            bonuses.warehouseReserveBucketsBonus += 1;
            bonuses.warehouseProtectedBucketsBonus += 1;
            bonuses.warehouseRaidMitigationBpsBonus += 100;

            bonuses.guardRaidMitigationBpsBonus += 100;
        }

        if (fullSetActive) {
            bonuses.fullSet = true;
            bonuses.fullSetPrestigePresentationBpsBonus = 200;
            bonuses.fullSetForgeSynergyBpsBonus = 200;
            bonuses.fullSetMarketFeeReductionBpsBonus = 100;
            bonuses.fullSetWarehouseProtectionBpsBonus = 150;
            bonuses.fullSetClaimWindowBonusBpsBonus = 100;
            bonuses.marketProvenancePremiumBonus = true;
        }
    }

    function _mintReason(
        uint256 plotId,
        CityBuildingTypes.PersonalBuildingType buildingType
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked("PERSONAL_BUILDING_MINT", plotId, uint8(buildingType))
        );
    }

    function _upgradeReason(
        uint256 buildingId,
        uint8 newLevel
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked("PERSONAL_BUILDING_UPGRADE", buildingId, newLevel)
        );
    }

    function _specializationReason(
        uint256 buildingId,
        CityBuildingTypes.BuildingSpecialization specialization
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked("PERSONAL_BUILDING_SPECIALIZE", buildingId, uint8(specialization))
        );
    }
}