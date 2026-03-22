// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

import "../libraries/CityBuildingTypes.sol";

/*//////////////////////////////////////////////////////////////
                        EXTERNAL INTERFACES
//////////////////////////////////////////////////////////////*/

interface ICityBuildingNFTV1PersonalLogic {
    function ownerOf(uint256 tokenId) external view returns (address);

    function mintBuilding(
        address to,
        CityBuildingTypes.PersonalBuildingType buildingType,
        uint32 versionTag
    ) external returns (uint256 buildingId);

    function getBuildingCore(
        uint256 buildingId
    ) external view returns (CityBuildingTypes.BuildingCore memory);

    function getBuildingMeta(
        uint256 buildingId
    ) external view returns (CityBuildingTypes.BuildingMeta memory);

    function isArchived(uint256 buildingId) external view returns (bool);

    function isMigrationPrepared(uint256 buildingId) external view returns (bool);

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

/// @notice Resource adapter for ResourceToken / city resource burning.
interface IPersonalBuildingResourceAdapter {
    function burnResourceBundle(
        address from,
        uint256[10] calldata amounts,
        bytes32 reason
    ) external;
}

/// @notice Optional PIT/Pitrone fee adapter.
interface IPersonalBuildingPitAdapter {
    function collectPitFee(
        address from,
        uint256 amount,
        bytes32 reason
    ) external;
}

/// @notice Optional discovery / research / recipe gate adapter.
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

/// @notice Optional hook adapter to touch plot activity / city status after meaningful actions.
interface IPersonalBuildingStatusHookAdapter {
    function touchPlotActivity(uint256 plotId) external;
}

/// @notice Plot adapter used for player-facing building minting.
/// @dev One owned completed personal plot can be used as mint entitlement.
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

/*//////////////////////////////////////////////////////////////
                         PERSONAL BUILDINGS
//////////////////////////////////////////////////////////////*/

/// @title PersonalBuildings
/// @notice Gameplay logic layer for personal buildings:
///         - player-facing mint by owned plot
///         - upgrade costs / cooldowns
///         - specialization costs
///         - optional PIT / tech / status hooks
///         - set / synergy reads
/// @dev CityBuildingNFTV1 remains the asset layer.
///      CityBuildingPlacement remains placement truth.
///      This contract must receive MINTER_ROLE, UPGRADER_ROLE and USAGE_ROLE on the NFT contract.
contract PersonalBuildings is AccessControl, Pausable {
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

    error InvalidBuildingCategory();
    error InvalidBuildingType();
    error InvalidLevel();
    error InvalidConfig();
    error MaxLevelReached();
    error NotBuildingOwner();
    error BuildingArchived();
    error BuildingPreparedForMigration();
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

    error NoIdsProvided();

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

    event MintCostConfigured(
        CityBuildingTypes.PersonalBuildingType indexed buildingType,
        uint256[10] resourceAmounts,
        uint256 pitFee,
        uint32 prestigeReward,
        uint32 historyReward,
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
        address indexed executor
    );

    event SpecializationCostConfigured(
        CityBuildingTypes.BuildingSpecialization indexed specialization,
        uint256[10] resourceAmounts,
        uint256 pitFee,
        uint32 prestigeReward,
        uint32 historyReward,
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

    /// @notice buildingType => mint cost config
    mapping(uint8 => MintCostConfig) private _mintConfigs;

    /// @notice buildingType => targetLevel => config
    mapping(uint8 => mapping(uint8 => UpgradeCostConfig)) private _upgradeConfigs;

    /// @notice specialization => config
    mapping(uint8 => SpecializationCostConfig) private _specializationConfigs;

    /// @notice buildingId => last upgrade execution timestamp via this logic contract
    mapping(uint256 => uint64) public lastUpgradeExecutionAt;

    /// @notice plotId => whether this plot entitlement already minted a personal building
    mapping(uint256 => bool) public plotMintUsed;

    /// @notice plotId => the building minted via that plot entitlement
    mapping(uint256 => uint256) public mintedBuildingIdByPlot;

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

        buildingNFT = ICityBuildingNFTV1PersonalLogic(buildingNFT_);
        placement = ICityBuildingPlacementPersonalRead(placement_);
        resourceAdapter = IPersonalBuildingResourceAdapter(resourceAdapter_);
        pitAdapter = IPersonalBuildingPitAdapter(pitAdapter_);
        techAdapter = IPersonalBuildingTechAdapter(techAdapter_);
        statusHookAdapter = IPersonalBuildingStatusHookAdapter(statusHookAdapter_);
        mintPlotAdapter = IPersonalBuildingMintPlotAdapter(mintPlotAdapter_);

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

    function setMintCostConfig(
        CityBuildingTypes.PersonalBuildingType buildingType,
        uint256[10] calldata resourceAmounts,
        uint256 pitFee,
        uint32 prestigeReward,
        uint32 historyReward
    ) external onlyRole(CONFIG_ROLE) {
        if (!CityBuildingTypes.isValidBaseType(buildingType)) revert InvalidBuildingType();

        _mintConfigs[uint8(buildingType)] = MintCostConfig({
            resourceAmounts: resourceAmounts,
            pitFee: pitFee,
            prestigeReward: prestigeReward,
            historyReward: historyReward,
            configured: true
        });

        emit MintCostConfigured(
            buildingType,
            resourceAmounts,
            pitFee,
            prestigeReward,
            historyReward,
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
        uint32 historyReward
    ) external onlyRole(CONFIG_ROLE) {
        if (!CityBuildingTypes.isValidBaseType(buildingType)) revert InvalidBuildingType();
        if (!CityBuildingTypes.isValidLevel(targetLevel) || targetLevel == 1) revert InvalidLevel();

        _upgradeConfigs[uint8(buildingType)][targetLevel] = UpgradeCostConfig({
            resourceAmounts: resourceAmounts,
            pitFee: pitFee,
            cooldown: cooldown,
            prestigeReward: prestigeReward,
            historyReward: historyReward,
            configured: true
        });

        emit UpgradeCostConfigured(
            buildingType,
            targetLevel,
            resourceAmounts,
            pitFee,
            cooldown,
            prestigeReward,
            historyReward,
            msg.sender
        );
    }

    function setSpecializationCostConfig(
        CityBuildingTypes.BuildingSpecialization specialization,
        uint256[10] calldata resourceAmounts,
        uint256 pitFee,
        uint32 prestigeReward,
        uint32 historyReward
    ) external onlyRole(CONFIG_ROLE) {
        if (specialization == CityBuildingTypes.BuildingSpecialization.None) revert InvalidConfig();

        _specializationConfigs[uint8(specialization)] = SpecializationCostConfig({
            resourceAmounts: resourceAmounts,
            pitFee: pitFee,
            prestigeReward: prestigeReward,
            historyReward: historyReward,
            configured: true
        });

        emit SpecializationCostConfigured(
            specialization,
            resourceAmounts,
            pitFee,
            prestigeReward,
            historyReward,
            msg.sender
        );
    }

    /*//////////////////////////////////////////////////////////////
                           PLAYER MINT FLOW
    //////////////////////////////////////////////////////////////*/

    /// @notice Player-facing mint: a player who owns a valid personal plot may mint one building using that plot as entitlement.
    /// @dev This does NOT auto-place the building. Placement remains in CityBuildingPlacement.
    ///      To enable this flow, grant MINTER_ROLE on CityBuildingNFTV1 to this contract.
    function mintPersonalBuildingForOwnedPlot(
        uint256 plotId,
        CityBuildingTypes.PersonalBuildingType buildingType,
        uint32 versionTag
    ) external whenNotPaused returns (uint256 buildingId) {
        if (!CityBuildingTypes.isValidBaseType(buildingType)) revert InvalidBuildingType();
        if (address(mintPlotAdapter) == address(0)) revert MintAdapterNotSet();
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

        // silence warnings but keep future expansion open
        districtKind;
        faction;

        if (!exists) revert PlotNotFound();
        if (plotOwner != msg.sender) revert PlotOwnerMismatch();
        if (!completed) revert PlotNotCompleted();
        if (!personalPlot) revert PlotNotPersonal();
        if (!eligible) revert PlotNotEligibleForMint();

        MintCostConfig memory cfg = _mintConfigs[uint8(buildingType)];
        if (!cfg.configured) revert MintNotConfigured();

        _consumeResources(msg.sender, cfg.resourceAmounts, keccak256("PERSONAL_BUILDING_MINT"));
        _collectPitFee(msg.sender, cfg.pitFee, keccak256("PERSONAL_BUILDING_MINT"));

        buildingId = buildingNFT.mintBuilding(
            msg.sender,
            buildingType,
            versionTag == 0 ? CityBuildingTypes.VERSION_TAG_V1 : versionTag
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

    function upgradeBuilding(uint256 buildingId) external whenNotPaused {
        _requireBuildingOwner(buildingId);
        _requireBuildingMutable(buildingId);

        CityBuildingTypes.BuildingCore memory core = buildingNFT.getBuildingCore(buildingId);

        if (core.category != CityBuildingTypes.BuildingCategory.Personal) revert InvalidBuildingCategory();
        if (!CityBuildingTypes.isValidBaseType(core.buildingType)) revert InvalidBuildingType();
        if (!CityBuildingTypes.isValidLevel(core.level)) revert InvalidLevel();
        if (core.level >= CityBuildingTypes.MAX_BUILDING_LEVEL) revert MaxLevelReached();

        uint8 targetLevel = core.level + 1;
        UpgradeCostConfig memory cfg = _upgradeConfigs[uint8(core.buildingType)][targetLevel];
        if (!cfg.configured) revert UpgradeNotConfigured();

        uint64 lastExec = lastUpgradeExecutionAt[buildingId];
        if (cfg.cooldown > 0 && lastExec > 0) {
            uint64 readyAt = lastExec + cfg.cooldown;
            if (block.timestamp < readyAt) revert UpgradeCooldownActive(readyAt);
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

        _consumeResources(msg.sender, cfg.resourceAmounts, keccak256("PERSONAL_BUILDING_UPGRADE"));
        _collectPitFee(msg.sender, cfg.pitFee, keccak256("PERSONAL_BUILDING_UPGRADE"));

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
            core.level,
            targetLevel,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    function specializeBuilding(
        uint256 buildingId,
        CityBuildingTypes.BuildingSpecialization specialization
    ) external whenNotPaused {
        _requireBuildingOwner(buildingId);
        _requireBuildingMutable(buildingId);

        CityBuildingTypes.BuildingCore memory core = buildingNFT.getBuildingCore(buildingId);

        if (core.category != CityBuildingTypes.BuildingCategory.Personal) revert InvalidBuildingCategory();
        if (!CityBuildingTypes.isValidBaseType(core.buildingType)) revert InvalidBuildingType();

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

        _consumeResources(msg.sender, cfg.resourceAmounts, keccak256("PERSONAL_BUILDING_SPECIALIZE"));
        _collectPitFee(msg.sender, cfg.pitFee, keccak256("PERSONAL_BUILDING_SPECIALIZE"));

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
                false
            );
        }

        targetLevel = currentLevel + 1;

        UpgradeCostConfig memory cfg = _upgradeConfigs[uint8(buildingType)][targetLevel];
        return (
            buildingType,
            currentLevel,
            targetLevel,
            cfg.resourceAmounts,
            cfg.pitFee,
            cfg.cooldown,
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

    function getPersonalSetProgress(
        address owner,
        uint256[] calldata buildingIds
    ) external view returns (PersonalSetProgress memory progress) {
        if (buildingIds.length == 0) revert NoIdsProvided();

        for (uint256 i = 0; i < buildingIds.length; i++) {
            if (buildingNFT.ownerOf(buildingIds[i]) != owner) continue;

            CityBuildingTypes.BuildingCore memory core = buildingNFT.getBuildingCore(buildingIds[i]);
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
        bool fullSet;
    }

    function evaluateSynergies(
        address owner,
        uint256[] calldata buildingIds,
        uint8 minimumLevel
    ) external view returns (SynergyFlags memory s) {
        if (buildingIds.length == 0) revert NoIdsProvided();

        bool hasResidence;
        bool hasFarmingHub;
        bool hasForge;
        bool hasWarehouse;
        bool hasMarketStall;
        bool hasGuardTower;
        bool hasResearchLab;

        for (uint256 i = 0; i < buildingIds.length; i++) {
            if (buildingNFT.ownerOf(buildingIds[i]) != owner) continue;

            CityBuildingTypes.BuildingCore memory core = buildingNFT.getBuildingCore(buildingIds[i]);
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

        s.residenceMarket = hasResidence && hasMarketStall;
        s.farmingWarehouse = hasFarmingHub && hasWarehouse;
        s.forgeResearch = hasForge && hasResearchLab;
        s.warehouseMarket = hasWarehouse && hasMarketStall;
        s.guardResearch = hasGuardTower && hasResearchLab;
        s.guardMarket = hasGuardTower && hasMarketStall;
        s.residenceResearch = hasResidence && hasResearchLab;
        s.forgeWarehouse = hasForge && hasWarehouse;
        s.forgeMarket = hasForge && hasMarketStall;
        s.fullSet =
            hasResidence &&
            hasFarmingHub &&
            hasForge &&
            hasWarehouse &&
            hasMarketStall &&
            hasGuardTower &&
            hasResearchLab;
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

    function _consumeResources(
        address from,
        uint256[10] memory amounts,
        bytes32 reason
    ) internal {
        if (address(resourceAdapter) == address(0)) {
            for (uint256 i = 0; i < RESOURCE_SLOT_COUNT; i++) {
                if (amounts[i] != 0) revert InvalidConfig();
            }
            return;
        }

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
            
        ) = placement.getPlacementSummary(buildingId);

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
        } else if (
            specialization == CityBuildingTypes.BuildingSpecialization.MasterLab
        ) {
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
}