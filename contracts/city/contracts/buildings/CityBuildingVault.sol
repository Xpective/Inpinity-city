/* FILE: contracts/city/contracts/buildings/CityBuildingVault.sol */
/* TYPE: warehouse vault / decay / repair / raid-prep layer — NOT NFT, NOT PersonalBuildings */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "../libraries/CityBuildingTypes.sol";
import "../interfaces/buildings/ICityBuildingVault.sol";
import "../interfaces/buildings/ICityBuildingVaultYield.sol";

/*//////////////////////////////////////////////////////////////
                        EXTERNAL INTERFACES
//////////////////////////////////////////////////////////////*/

interface ICityBuildingNFTV1VaultRead {
    function ownerOf(uint256 tokenId) external view returns (address);

    function getBuildingCore(
        uint256 buildingId
    ) external view returns (CityBuildingTypes.BuildingCore memory);

    function isArchived(uint256 buildingId) external view returns (bool);

    function isMigrationPrepared(uint256 buildingId) external view returns (bool);
}

/*//////////////////////////////////////////////////////////////
                        CITY BUILDING VAULT
//////////////////////////////////////////////////////////////*/

contract CityBuildingVault is
    AccessControl,
    Pausable,
    ReentrancyGuard,
    ICityBuildingVault,
    ICityBuildingVaultYield
{
    /*//////////////////////////////////////////////////////////////
                                 ROLES
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant VAULT_ADMIN_ROLE = keccak256("VAULT_ADMIN_ROLE");
    bytes32 public constant VAULT_OPERATOR_ROLE = keccak256("VAULT_OPERATOR_ROLE");
    bytes32 public constant VAULT_CALLER_ROLE = keccak256("VAULT_CALLER_ROLE");
    bytes32 public constant RAID_CALLER_ROLE = keccak256("RAID_CALLER_ROLE");
    bytes32 public constant REPAIR_CALLER_ROLE = keccak256("REPAIR_CALLER_ROLE");
    bytes32 public constant YIELD_CALLER_ROLE = keccak256("YIELD_CALLER_ROLE");

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint8 public constant RESOURCE_SLOT_COUNT = 10;

    uint8 public constant DECAY_NONE = 0;
    uint8 public constant DECAY_STABLE = 1;
    uint8 public constant DECAY_WORN = 2;
    uint8 public constant DECAY_DAMAGED = 3;
    uint8 public constant DECAY_CRITICAL = 4;

    uint8 public constant REPAIR_NONE = 0;
    uint8 public constant REPAIR_NOT_REQUIRED = 1;
    uint8 public constant REPAIR_MINOR_REQUIRED = 2;
    uint8 public constant REPAIR_MAJOR_REQUIRED = 3;
    uint8 public constant REPAIR_LOCKED_UNTIL_REPAIR = 4;

    uint8 public constant YIELD_MODE_NONE = 0;
    uint8 public constant YIELD_MODE_7D = 1;
    uint8 public constant YIELD_MODE_30D = 2;

    uint64 public constant YIELD_LOCK_7D = 7 days;
    uint64 public constant YIELD_LOCK_30D = 30 days;

    uint32 public constant MAX_BPS = 10_000;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error InvalidBuildingNFT();
    error InvalidBuildingId();
    error InvalidBuildingCategory();
    error InvalidBuildingType();
    error InvalidResourceId();
    error InvalidBps();
    error InvalidDecayState();
    error InvalidRepairState();
    error InvalidResourceState();
    error InvalidYieldMode();
    error InvalidAmount();

    error BuildingArchived();
    error BuildingPreparedForMigration();
    error VaultNotEnabled();
    error VaultAlreadyEnabled();
    error EmergencyLocked();
    error AmountExceedsStored();
    error AmountExceedsRaidable();
    error AmountExceedsProtected();

    error YieldNotEligibleByLevel();
    error YieldConfigNotEnabled();
    error YieldPositionActive();
    error YieldPositionNotFound();
    error YieldPositionNotMatured(uint64 maturityAt);

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event BuildingNFTSet(address indexed buildingNFT, address indexed executor);

    event WarehouseVaultEnabled(
        uint256 indexed buildingId,
        uint8 vaultTier,
        uint32 vaultCapBps,
        address indexed executor
    );

    event WarehouseVaultDisabled(
        uint256 indexed buildingId,
        address indexed executor
    );

    event WarehouseVaultRaidEnabledSet(
        uint256 indexed buildingId,
        bool enabled,
        address indexed executor
    );

    event WarehouseVaultEmergencyLockSet(
        uint256 indexed buildingId,
        bool locked,
        address indexed executor
    );

    event WarehouseVaultProfileUpdated(
        uint256 indexed buildingId,
        uint8 vaultTier,
        uint8 defenseTier,
        uint8 decayState,
        uint8 repairState,
        uint32 vaultCapBps,
        uint32 defenseBps,
        uint32 raidMitigationBps,
        uint32 damageBps,
        address indexed executor
    );

    event WarehouseVaultResourceStateUpdated(
        uint256 indexed buildingId,
        uint8 indexed resourceId,
        uint256 stored,
        uint256 reserved,
        uint256 protectedAmount,
        uint256 raidableAmount,
        address executor
    );

    event WarehouseVaultRaidMarked(
        uint256 indexed buildingId,
        uint32 damageBps,
        uint64 raidAt,
        address indexed executor
    );

    event WarehouseVaultRaidLossApplied(
        uint256 indexed buildingId,
        uint8 indexed resourceId,
        uint256 amount,
        uint64 raidAt,
        address indexed executor
    );

    event WarehouseVaultRepairRequiredSet(
        uint256 indexed buildingId,
        bool repairRequired,
        uint8 repairState,
        address indexed executor
    );

    event WarehouseVaultRepairRecorded(
        uint256 indexed buildingId,
        uint8 repairState,
        uint32 damageBps,
        uint64 repairedAt,
        address indexed executor
    );

    event WarehouseVaultDecayUpdated(
        uint256 indexed buildingId,
        uint8 decayState,
        uint32 damageBps,
        uint64 checkedAt,
        address indexed executor
    );

    event WarehouseVaultActionTouched(
        uint256 indexed buildingId,
        uint64 touchedAt,
        address indexed executor
    );

    event WarehouseVaultRecommendedProfileApplied(
        uint256 indexed buildingId,
        uint8 recommendedVaultTier,
        uint8 recommendedDefenseTier,
        uint32 recommendedVaultCapBps,
        uint32 recommendedDefenseBps,
        uint32 recommendedRaidMitigationBps,
        address indexed executor
    );

    event ResourceYieldConfigSet(
        uint8 indexed resourceId,
        uint32 sevenDayBaseBps,
        uint32 thirtyDayBaseBps,
        bool enabled,
        address indexed executor
    );

    event WarehouseYieldPositionOpened(
        uint256 indexed buildingId,
        uint8 indexed resourceId,
        uint256 amount,
        uint8 lockMode,
        uint32 effectiveYieldBps,
        uint64 startedAt,
        uint64 maturityAt,
        address indexed executor
    );

    event WarehouseYieldPositionClosed(
        uint256 indexed buildingId,
        uint8 indexed resourceId,
        uint256 amount,
        uint256 yieldAmount,
        uint8 lockMode,
        uint64 closedAt,
        address indexed executor
    );

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    ICityBuildingNFTV1VaultRead public buildingNFT;

    mapping(uint256 => WarehouseVaultProfile) internal _vaultProfiles;
    mapping(uint256 => mapping(uint8 => VaultResourceState)) internal _vaultResources;

    struct ResourceYieldConfig {
        uint32 sevenDayBaseBps;
        uint32 thirtyDayBaseBps;
        bool enabled;
    }

    struct WarehouseYieldPosition {
        uint256 amount;
        uint256 protectionShiftedAmount;
        uint64 startedAt;
        uint64 maturityAt;
        uint8 lockMode;
        uint32 effectiveYieldBps;
        bool active;
    }

    mapping(uint8 => ResourceYieldConfig) internal _yieldConfigs;
    mapping(uint256 => mapping(uint8 => WarehouseYieldPosition)) internal _yieldPositions;
    mapping(uint256 => mapping(uint8 => uint256)) public totalYieldSettledByResource;
    mapping(uint256 => mapping(uint8 => uint64)) public lastYieldSettledAtByResource;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address buildingNFT_,
        address admin_
    ) {
        if (buildingNFT_ == address(0) || admin_ == address(0)) revert ZeroAddress();
        if (buildingNFT_.code.length == 0) revert InvalidBuildingNFT();

        buildingNFT = ICityBuildingNFTV1VaultRead(buildingNFT_);

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(VAULT_ADMIN_ROLE, admin_);
        _grantRole(VAULT_OPERATOR_ROLE, admin_);
        _grantRole(VAULT_CALLER_ROLE, admin_);
        _grantRole(RAID_CALLER_ROLE, admin_);
        _grantRole(REPAIR_CALLER_ROLE, admin_);
        _grantRole(YIELD_CALLER_ROLE, admin_);
    }

    /*//////////////////////////////////////////////////////////////
                                 ADMIN
    //////////////////////////////////////////////////////////////*/

    function pause() external onlyRole(VAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(VAULT_ADMIN_ROLE) {
        _unpause();
    }

    function setBuildingNFT(address buildingNFT_) external onlyRole(VAULT_ADMIN_ROLE) {
        if (buildingNFT_ == address(0)) revert ZeroAddress();
        if (buildingNFT_.code.length == 0) revert InvalidBuildingNFT();

        buildingNFT = ICityBuildingNFTV1VaultRead(buildingNFT_);
        emit BuildingNFTSet(buildingNFT_, msg.sender);
    }

    function setResourceYieldConfig(
        uint8 resourceId,
        uint32 sevenDayBaseBps,
        uint32 thirtyDayBaseBps,
        bool enabled
    ) external onlyRole(VAULT_OPERATOR_ROLE) {
        _requireValidResourceId(resourceId);
        if (sevenDayBaseBps > MAX_BPS || thirtyDayBaseBps > MAX_BPS) revert InvalidBps();

        _yieldConfigs[resourceId] = ResourceYieldConfig({
            sevenDayBaseBps: sevenDayBaseBps,
            thirtyDayBaseBps: thirtyDayBaseBps,
            enabled: enabled
        });

        emit ResourceYieldConfigSet(
            resourceId,
            sevenDayBaseBps,
            thirtyDayBaseBps,
            enabled,
            msg.sender
        );
    }

    /*//////////////////////////////////////////////////////////////
                         VAULT ENABLE / CONFIG
    //////////////////////////////////////////////////////////////*/

    function enableWarehouseVault(
        uint256 buildingId,
        uint8 vaultTier,
        uint32 vaultCapBps
    ) external onlyRole(VAULT_OPERATOR_ROLE) whenNotPaused {
        _requireWarehouse(buildingId);
        if (vaultCapBps > MAX_BPS) revert InvalidBps();

        WarehouseVaultProfile storage p = _vaultProfiles[buildingId];
        if (p.vaultEnabled) revert VaultAlreadyEnabled();

        CityBuildingTypes.BuildingCore memory core = buildingNFT.getBuildingCore(buildingId);

        uint8 resolvedVaultTier = vaultTier == 0 ? _recommendedVaultTier(core) : vaultTier;
        uint8 resolvedDefenseTier = _recommendedDefenseTier(core);
        uint32 resolvedVaultCapBps = vaultCapBps == 0 ? _recommendedVaultCapBps(core) : vaultCapBps;
        uint32 resolvedDefenseBps = _recommendedDefenseBps(core);
        uint32 resolvedRaidMitigationBps = _recommendedRaidMitigationBps(core);

        p.vaultEnabled = true;
        p.raidEnabled = core.level >= 3;
        p.repairRequired = false;
        p.emergencyLocked = false;

        p.vaultTier = resolvedVaultTier;
        p.defenseTier = resolvedDefenseTier;
        p.decayState = core.level >= 3 ? DECAY_STABLE : DECAY_NONE;
        p.repairState = core.level >= 3 ? REPAIR_NOT_REQUIRED : REPAIR_NONE;

        p.vaultCapBps = resolvedVaultCapBps;
        p.defenseBps = resolvedDefenseBps;
        p.raidMitigationBps = resolvedRaidMitigationBps;
        p.damageBps = 0;

        p.activatedAt = uint64(block.timestamp);
        p.lastVaultActionAt = uint64(block.timestamp);
        p.lastDecayCheckAt = uint64(block.timestamp);
        p.lastRepairAt = 0;
        p.lastRaidAt = 0;

        emit WarehouseVaultEnabled(buildingId, resolvedVaultTier, resolvedVaultCapBps, msg.sender);
        emit WarehouseVaultRecommendedProfileApplied(
            buildingId,
            resolvedVaultTier,
            resolvedDefenseTier,
            resolvedVaultCapBps,
            resolvedDefenseBps,
            resolvedRaidMitigationBps,
            msg.sender
        );
    }

    function disableWarehouseVault(
        uint256 buildingId
    ) external onlyRole(VAULT_OPERATOR_ROLE) whenNotPaused {
        _requireWarehouse(buildingId);

        WarehouseVaultProfile storage p = _vaultProfiles[buildingId];
        if (!p.vaultEnabled) revert VaultNotEnabled();

        delete _vaultProfiles[buildingId];

        for (uint8 i = 0; i < RESOURCE_SLOT_COUNT; i++) {
            delete _vaultResources[buildingId][i];
            delete _yieldPositions[buildingId][i];
        }

        emit WarehouseVaultDisabled(buildingId, msg.sender);
    }

    function setWarehouseVaultRaidEnabled(
        uint256 buildingId,
        bool enabled
    ) external onlyRole(VAULT_OPERATOR_ROLE) whenNotPaused {
        _requireEnabledWarehouse(buildingId);

        WarehouseVaultProfile storage p = _vaultProfiles[buildingId];
        p.raidEnabled = enabled;
        p.lastVaultActionAt = uint64(block.timestamp);

        emit WarehouseVaultRaidEnabledSet(buildingId, enabled, msg.sender);
    }

    function setWarehouseVaultEmergencyLock(
        uint256 buildingId,
        bool locked
    ) external onlyRole(VAULT_OPERATOR_ROLE) whenNotPaused {
        _requireEnabledWarehouse(buildingId);

        WarehouseVaultProfile storage p = _vaultProfiles[buildingId];
        p.emergencyLocked = locked;
        p.lastVaultActionAt = uint64(block.timestamp);

        emit WarehouseVaultEmergencyLockSet(buildingId, locked, msg.sender);
    }

    function setWarehouseVaultProfile(
        uint256 buildingId,
        uint8 vaultTier,
        uint8 defenseTier,
        uint8 decayState,
        uint8 repairState,
        uint32 vaultCapBps,
        uint32 defenseBps,
        uint32 raidMitigationBps,
        uint32 damageBps
    ) external onlyRole(VAULT_OPERATOR_ROLE) whenNotPaused {
        _requireEnabledWarehouse(buildingId);
        _requireValidDecayState(decayState);
        _requireValidRepairState(repairState);

        if (
            vaultCapBps > MAX_BPS ||
            defenseBps > MAX_BPS ||
            raidMitigationBps > MAX_BPS ||
            damageBps > MAX_BPS
        ) revert InvalidBps();

        WarehouseVaultProfile storage p = _vaultProfiles[buildingId];

        p.vaultTier = vaultTier;
        p.defenseTier = defenseTier;
        p.decayState = decayState;
        p.repairState = repairState;
        p.vaultCapBps = vaultCapBps;
        p.defenseBps = defenseBps;
        p.raidMitigationBps = raidMitigationBps;
        p.damageBps = damageBps;
        p.repairRequired = _isRepairRequiredState(repairState);
        p.lastVaultActionAt = uint64(block.timestamp);

        emit WarehouseVaultProfileUpdated(
            buildingId,
            vaultTier,
            defenseTier,
            decayState,
            repairState,
            vaultCapBps,
            defenseBps,
            raidMitigationBps,
            damageBps,
            msg.sender
        );
    }

    function setWarehouseVaultResourceState(
        uint256 buildingId,
        uint8 resourceId,
        uint256 stored,
        uint256 reserved,
        uint256 protectedAmount,
        uint256 raidableAmount
    ) external onlyRole(VAULT_OPERATOR_ROLE) whenNotPaused {
        _requireEnabledWarehouse(buildingId);
        _requireValidResourceId(resourceId);
        _requireValidResourceState(stored, reserved, protectedAmount, raidableAmount);

        VaultResourceState storage s = _vaultResources[buildingId][resourceId];
        s.stored = stored;
        s.reserved = reserved;
        s.protectedAmount = protectedAmount;
        s.raidableAmount = raidableAmount;

        _vaultProfiles[buildingId].lastVaultActionAt = uint64(block.timestamp);

        emit WarehouseVaultResourceStateUpdated(
            buildingId,
            resourceId,
            stored,
            reserved,
            protectedAmount,
            raidableAmount,
            msg.sender
        );
    }

    /*//////////////////////////////////////////////////////////////
                          YIELD / STAKING PREP
    //////////////////////////////////////////////////////////////*/

    function openWarehouseYieldPosition(
        uint256 buildingId,
        uint8 resourceId,
        uint256 amount,
        uint8 lockMode
    ) external onlyRole(YIELD_CALLER_ROLE) whenNotPaused nonReentrant {
        CityBuildingTypes.BuildingCore memory core = _requireWarehouseCore(buildingId);
        if (!_vaultProfiles[buildingId].vaultEnabled) revert VaultNotEnabled();
        if (core.level < 5) revert YieldNotEligibleByLevel();
        if (_vaultProfiles[buildingId].emergencyLocked) revert EmergencyLocked();

        _requireValidResourceId(resourceId);
        if (amount == 0) revert InvalidAmount();

        ResourceYieldConfig memory config = _yieldConfigs[resourceId];
        if (!config.enabled) revert YieldConfigNotEnabled();

        WarehouseYieldPosition storage position = _yieldPositions[buildingId][resourceId];
        if (position.active) revert YieldPositionActive();

        VaultResourceState storage state_ = _vaultResources[buildingId][resourceId];

        uint256 stakeable = state_.stored > state_.reserved ? state_.stored - state_.reserved : 0;
        if (amount > stakeable) revert AmountExceedsStored();

        uint64 lockDuration = _yieldLockDuration(lockMode);
        uint32 effectiveYieldBps = _effectiveYieldBpsFromConfig(core, config, lockMode);
        if (effectiveYieldBps == 0) revert YieldConfigNotEnabled();

        uint256 protectionShifted = amount <= state_.raidableAmount ? amount : state_.raidableAmount;

        state_.reserved += amount;
        if (protectionShifted != 0) {
            state_.raidableAmount -= protectionShifted;
            state_.protectedAmount += protectionShifted;
        }

        position.amount = amount;
        position.protectionShiftedAmount = protectionShifted;
        position.startedAt = uint64(block.timestamp);
        position.maturityAt = uint64(block.timestamp) + lockDuration;
        position.lockMode = lockMode;
        position.effectiveYieldBps = effectiveYieldBps;
        position.active = true;

        _vaultProfiles[buildingId].lastVaultActionAt = uint64(block.timestamp);

        emit WarehouseVaultResourceStateUpdated(
            buildingId,
            resourceId,
            state_.stored,
            state_.reserved,
            state_.protectedAmount,
            state_.raidableAmount,
            msg.sender
        );

        emit WarehouseYieldPositionOpened(
            buildingId,
            resourceId,
            amount,
            lockMode,
            effectiveYieldBps,
            uint64(block.timestamp),
            uint64(block.timestamp) + lockDuration,
            msg.sender
        );
    }

    function closeWarehouseYieldPosition(
        uint256 buildingId,
        uint8 resourceId
    )
        external
        onlyRole(YIELD_CALLER_ROLE)
        whenNotPaused
        nonReentrant
        returns (
            uint256 principalAmount,
            uint256 yieldAmount
        )
    {
        _requireEnabledWarehouse(buildingId);
        _requireValidResourceId(resourceId);

        WarehouseYieldPosition storage position = _yieldPositions[buildingId][resourceId];
        if (!position.active) revert YieldPositionNotFound();
        if (block.timestamp < position.maturityAt) {
            revert YieldPositionNotMatured(position.maturityAt);
        }

        VaultResourceState storage state_ = _vaultResources[buildingId][resourceId];

        principalAmount = position.amount;
        yieldAmount = (principalAmount * position.effectiveYieldBps) / MAX_BPS;

        if (state_.reserved >= principalAmount) {
            state_.reserved -= principalAmount;
        } else {
            state_.reserved = 0;
        }

        uint256 shifted = position.protectionShiftedAmount;
        if (shifted != 0) {
            if (state_.protectedAmount >= shifted) {
                state_.protectedAmount -= shifted;
            } else {
                state_.protectedAmount = 0;
            }

            state_.raidableAmount += shifted;
            if (state_.raidableAmount > state_.stored) {
                state_.raidableAmount = state_.stored;
            }

            if (state_.protectedAmount + state_.raidableAmount > state_.stored) {
                uint256 overflow = state_.protectedAmount + state_.raidableAmount - state_.stored;
                if (state_.raidableAmount >= overflow) {
                    state_.raidableAmount -= overflow;
                } else {
                    state_.raidableAmount = 0;
                }
            }
        }

        totalYieldSettledByResource[buildingId][resourceId] += yieldAmount;
        lastYieldSettledAtByResource[buildingId][resourceId] = uint64(block.timestamp);

        uint8 closedLockMode = position.lockMode;
        delete _yieldPositions[buildingId][resourceId];

        _vaultProfiles[buildingId].lastVaultActionAt = uint64(block.timestamp);

        emit WarehouseVaultResourceStateUpdated(
            buildingId,
            resourceId,
            state_.stored,
            state_.reserved,
            state_.protectedAmount,
            state_.raidableAmount,
            msg.sender
        );

        emit WarehouseYieldPositionClosed(
            buildingId,
            resourceId,
            principalAmount,
            yieldAmount,
            closedLockMode,
            uint64(block.timestamp),
            msg.sender
        );
    }

    /*//////////////////////////////////////////////////////////////
                           RAID / REPAIR PREP
    //////////////////////////////////////////////////////////////*/

    function markVaultRaided(
        uint256 buildingId,
        uint32 damageBps
    ) external onlyRole(RAID_CALLER_ROLE) whenNotPaused {
        _requireEnabledWarehouse(buildingId);

        WarehouseVaultProfile storage p = _vaultProfiles[buildingId];
        if (p.emergencyLocked) revert EmergencyLocked();
        if (damageBps > MAX_BPS) revert InvalidBps();

        p.lastRaidAt = uint64(block.timestamp);
        p.lastVaultActionAt = uint64(block.timestamp);
        p.damageBps = damageBps;

        if (damageBps >= 6000) {
            p.decayState = DECAY_CRITICAL;
            p.repairState = REPAIR_LOCKED_UNTIL_REPAIR;
            p.repairRequired = true;
        } else if (damageBps >= 3000) {
            p.decayState = DECAY_DAMAGED;
            p.repairState = REPAIR_MAJOR_REQUIRED;
            p.repairRequired = true;
        } else if (damageBps >= 1000) {
            p.decayState = DECAY_WORN;
            p.repairState = REPAIR_MINOR_REQUIRED;
            p.repairRequired = true;
        } else {
            p.decayState = DECAY_STABLE;
            p.repairState = REPAIR_NOT_REQUIRED;
            p.repairRequired = false;
        }

        emit WarehouseVaultRaidMarked(
            buildingId,
            damageBps,
            uint64(block.timestamp),
            msg.sender
        );
    }

    function applyVaultRaidLoss(
        uint256 buildingId,
        uint8 resourceId,
        uint256 amount
    ) external onlyRole(RAID_CALLER_ROLE) whenNotPaused {
        _requireEnabledWarehouse(buildingId);
        _requireValidResourceId(resourceId);

        WarehouseVaultProfile storage p = _vaultProfiles[buildingId];
        if (p.emergencyLocked) revert EmergencyLocked();
        if (!p.raidEnabled) revert VaultNotEnabled();

        VaultResourceState storage s = _vaultResources[buildingId][resourceId];
        if (amount > s.raidableAmount) revert AmountExceedsRaidable();
        if (amount > s.stored) revert AmountExceedsStored();

        s.raidableAmount -= amount;
        s.stored -= amount;

        if (s.reserved > s.stored) s.reserved = s.stored;
        if (s.protectedAmount > s.stored) s.protectedAmount = s.stored;
        if (s.raidableAmount > s.stored) s.raidableAmount = s.stored;

        p.lastRaidAt = uint64(block.timestamp);
        p.lastVaultActionAt = uint64(block.timestamp);

        emit WarehouseVaultRaidLossApplied(
            buildingId,
            resourceId,
            amount,
            uint64(block.timestamp),
            msg.sender
        );
    }

    function markRepairRequired(
        uint256 buildingId,
        uint8 repairState
    ) external onlyRole(REPAIR_CALLER_ROLE) whenNotPaused {
        _requireEnabledWarehouse(buildingId);
        _requireValidRepairState(repairState);

        WarehouseVaultProfile storage p = _vaultProfiles[buildingId];
        p.repairState = repairState;
        p.repairRequired = _isRepairRequiredState(repairState);
        p.lastVaultActionAt = uint64(block.timestamp);

        emit WarehouseVaultRepairRequiredSet(
            buildingId,
            p.repairRequired,
            repairState,
            msg.sender
        );
    }

    function recordRepair(
        uint256 buildingId,
        uint8 repairState,
        uint32 damageBps
    ) external onlyRole(REPAIR_CALLER_ROLE) whenNotPaused {
        _requireEnabledWarehouse(buildingId);
        _requireValidRepairState(repairState);
        if (damageBps > MAX_BPS) revert InvalidBps();

        WarehouseVaultProfile storage p = _vaultProfiles[buildingId];
        p.repairState = repairState;
        p.damageBps = damageBps;
        p.lastRepairAt = uint64(block.timestamp);
        p.lastVaultActionAt = uint64(block.timestamp);
        p.repairRequired = _isRepairRequiredState(repairState);

        if (!p.repairRequired && damageBps == 0) {
            p.decayState = DECAY_STABLE;
        }

        emit WarehouseVaultRepairRecorded(
            buildingId,
            repairState,
            damageBps,
            uint64(block.timestamp),
            msg.sender
        );
    }

    function updateDecayState(
        uint256 buildingId,
        uint8 decayState,
        uint32 damageBps
    ) external onlyRole(VAULT_CALLER_ROLE) whenNotPaused {
        _requireEnabledWarehouse(buildingId);
        _requireValidDecayState(decayState);
        if (damageBps > MAX_BPS) revert InvalidBps();

        WarehouseVaultProfile storage p = _vaultProfiles[buildingId];
        p.decayState = decayState;
        p.damageBps = damageBps;
        p.lastDecayCheckAt = uint64(block.timestamp);
        p.lastVaultActionAt = uint64(block.timestamp);

        emit WarehouseVaultDecayUpdated(
            buildingId,
            decayState,
            damageBps,
            uint64(block.timestamp),
            msg.sender
        );
    }

    function touchVaultAction(
        uint256 buildingId
    ) external onlyRole(VAULT_CALLER_ROLE) whenNotPaused {
        _requireEnabledWarehouse(buildingId);

        _vaultProfiles[buildingId].lastVaultActionAt = uint64(block.timestamp);

        emit WarehouseVaultActionTouched(
            buildingId,
            uint64(block.timestamp),
            msg.sender
        );
    }

    /*//////////////////////////////////////////////////////////////
                                  READS
    //////////////////////////////////////////////////////////////*/

    function getWarehouseVaultProfile(
        uint256 buildingId
    ) external view override returns (WarehouseVaultProfile memory) {
        return _vaultProfiles[buildingId];
    }

    function getWarehouseVaultResourceState(
        uint256 buildingId,
        uint8 resourceId
    ) external view override returns (VaultResourceState memory) {
        _requireValidResourceId(resourceId);
        return _vaultResources[buildingId][resourceId];
    }

    function isWarehouseVaultEnabled(
        uint256 buildingId
    ) external view override returns (bool) {
        return _vaultProfiles[buildingId].vaultEnabled;
    }

    function getWarehouseVaultCapBps(
        uint256 buildingId
    ) external view override returns (uint32) {
        return _vaultProfiles[buildingId].vaultCapBps;
    }

    function getWarehouseVaultDefenseProfile(
        uint256 buildingId
    )
        external
        view
        override
        returns (
            uint8 defenseTier,
            uint32 defenseBps,
            uint32 raidMitigationBps,
            uint32 damageBps
        )
    {
        WarehouseVaultProfile memory p = _vaultProfiles[buildingId];
        return (
            p.defenseTier,
            p.defenseBps,
            p.raidMitigationBps,
            p.damageBps
        );
    }

    function getWarehouseVaultTotals(
        uint256 buildingId
    )
        external
        view
        override
        returns (
            uint256 totalStored,
            uint256 totalReserved,
            uint256 totalProtected,
            uint256 totalRaidable
        )
    {
        for (uint8 i = 0; i < RESOURCE_SLOT_COUNT; i++) {
            VaultResourceState memory s = _vaultResources[buildingId][i];
            totalStored += s.stored;
            totalReserved += s.reserved;
            totalProtected += s.protectedAmount;
            totalRaidable += s.raidableAmount;
        }
    }

    function getBuildingDurabilityState(
        uint256 buildingId
    )
        external
        view
        override
        returns (
            uint8 decayState,
            uint8 repairState,
            uint32 damageBps,
            bool repairRequired,
            uint64 lastDecayCheckAt,
            uint64 lastRepairAt
        )
    {
        WarehouseVaultProfile memory p = _vaultProfiles[buildingId];
        return (
            p.decayState,
            p.repairState,
            p.damageBps,
            p.repairRequired,
            p.lastDecayCheckAt,
            p.lastRepairAt
        );
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
        CityBuildingTypes.BuildingCore memory core = _requireWarehouseCore(buildingId);

        return (
            _recommendedVaultTier(core),
            _recommendedDefenseTier(core),
            _recommendedVaultCapBps(core),
            _recommendedDefenseBps(core),
            _recommendedRaidMitigationBps(core),
            core.level >= 3,
            core.level >= 3,
            core.level >= 3
        );
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
        CityBuildingTypes.BuildingCore memory core = _requireWarehouseCore(buildingId);
        return _recommendedBucketProfile(core);
    }

    function getResourceYieldConfig(
        uint8 resourceId
    )
        external
        view
        override
        returns (
            uint32 sevenDayBaseBps,
            uint32 thirtyDayBaseBps,
            bool enabled
        )
    {
        _requireValidResourceId(resourceId);
        ResourceYieldConfig memory cfg = _yieldConfigs[resourceId];
        return (cfg.sevenDayBaseBps, cfg.thirtyDayBaseBps, cfg.enabled);
    }

    function getWarehouseYieldPosition(
        uint256 buildingId,
        uint8 resourceId
    )
        external
        view
        override
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
        _requireValidResourceId(resourceId);

        WarehouseYieldPosition memory p = _yieldPositions[buildingId][resourceId];
        amount = p.amount;
        protectionShiftedAmount = p.protectionShiftedAmount;
        startedAt = p.startedAt;
        maturityAt = p.maturityAt;
        lockMode = p.lockMode;
        effectiveYieldBps = p.effectiveYieldBps;
        active = p.active;
        matured = p.active && block.timestamp >= p.maturityAt;
        previewYieldAmount = p.active ? (p.amount * p.effectiveYieldBps) / MAX_BPS : 0;
    }

    function previewWarehouseYieldSettlement(
        uint256 buildingId,
        uint8 resourceId
    )
        external
        view
        override
        returns (
            uint256 principalAmount,
            uint256 yieldAmount,
            bool matured,
            uint64 maturityAt
        )
    {
        _requireValidResourceId(resourceId);

        WarehouseYieldPosition memory p = _yieldPositions[buildingId][resourceId];
        principalAmount = p.amount;
        yieldAmount = p.active ? (p.amount * p.effectiveYieldBps) / MAX_BPS : 0;
        matured = p.active && block.timestamp >= p.maturityAt;
        maturityAt = p.maturityAt;
    }

    function isWarehouseYieldEligible(
        uint256 buildingId
    ) external view override returns (bool) {
        CityBuildingTypes.BuildingCore memory core = _requireWarehouseCore(buildingId);
        return core.level >= 5;
    }

    function getEffectiveWarehouseYieldBps(
        uint256 buildingId,
        uint8 resourceId,
        uint8 lockMode
    ) external view override returns (uint32) {
        _requireValidResourceId(resourceId);

        CityBuildingTypes.BuildingCore memory core = _requireWarehouseCore(buildingId);
        if (core.level < 5) return 0;

        ResourceYieldConfig memory config = _yieldConfigs[resourceId];
        if (!config.enabled) return 0;

        return _effectiveYieldBpsFromConfig(core, config, lockMode);
    }

    /*//////////////////////////////////////////////////////////////
                               INTERNALS
    //////////////////////////////////////////////////////////////*/

    function _requireWarehouse(uint256 buildingId) internal view {
        _requireWarehouseCore(buildingId);
    }

    function _requireWarehouseCore(
        uint256 buildingId
    ) internal view returns (CityBuildingTypes.BuildingCore memory core) {
        if (buildingId == 0) revert InvalidBuildingId();
        if (buildingNFT.isArchived(buildingId)) revert BuildingArchived();
        if (buildingNFT.isMigrationPrepared(buildingId)) revert BuildingPreparedForMigration();

        core = buildingNFT.getBuildingCore(buildingId);
        if (core.category != CityBuildingTypes.BuildingCategory.Personal) {
            revert InvalidBuildingCategory();
        }
        if (core.buildingType != CityBuildingTypes.PersonalBuildingType.Warehouse) {
            revert InvalidBuildingType();
        }
    }

    function _requireEnabledWarehouse(uint256 buildingId) internal view {
        _requireWarehouse(buildingId);
        if (!_vaultProfiles[buildingId].vaultEnabled) revert VaultNotEnabled();
    }

    function _requireValidResourceId(uint8 resourceId) internal pure {
        if (resourceId >= RESOURCE_SLOT_COUNT) revert InvalidResourceId();
    }

    function _requireValidDecayState(uint8 decayState) internal pure {
        if (decayState > DECAY_CRITICAL) revert InvalidDecayState();
    }

    function _requireValidRepairState(uint8 repairState) internal pure {
        if (repairState > REPAIR_LOCKED_UNTIL_REPAIR) revert InvalidRepairState();
    }

    function _requireValidResourceState(
        uint256 stored,
        uint256 reserved,
        uint256 protectedAmount,
        uint256 raidableAmount
    ) internal pure {
        if (reserved > stored) revert AmountExceedsStored();
        if (protectedAmount > stored) revert AmountExceedsStored();
        if (raidableAmount > stored) revert AmountExceedsStored();
        if (protectedAmount + raidableAmount > stored) revert InvalidResourceState();
    }

    function _isRepairRequiredState(uint8 repairState) internal pure returns (bool) {
        return (
            repairState == REPAIR_MINOR_REQUIRED ||
            repairState == REPAIR_MAJOR_REQUIRED ||
            repairState == REPAIR_LOCKED_UNTIL_REPAIR
        );
    }

    function _yieldLockDuration(uint8 lockMode) internal pure returns (uint64) {
        if (lockMode == YIELD_MODE_7D) return YIELD_LOCK_7D;
        if (lockMode == YIELD_MODE_30D) return YIELD_LOCK_30D;
        revert InvalidYieldMode();
    }

    function _baseYieldBps(
        uint8 resourceId,
        uint8 lockMode
    ) internal view returns (uint32) {
        ResourceYieldConfig memory config = _yieldConfigs[resourceId];
        if (!config.enabled) revert YieldConfigNotEnabled();
        return _baseYieldBpsFromConfig(config, lockMode);
    }

    function _baseYieldBpsFromConfig(
        ResourceYieldConfig memory config,
        uint8 lockMode
    ) internal pure returns (uint32) {
        if (lockMode == YIELD_MODE_7D) return config.sevenDayBaseBps;
        if (lockMode == YIELD_MODE_30D) return config.thirtyDayBaseBps;
        revert InvalidYieldMode();
    }

    function _warehouseYieldBonusBps(
        CityBuildingTypes.BuildingCore memory core,
        uint8 lockMode
    ) internal pure returns (uint32) {
        if (core.level < 5) return 0;

        uint32 bonus;
        if (lockMode == YIELD_MODE_7D) {
            if (core.level == 5) bonus = 50;
            else if (core.level == 6) bonus = 100;
            else bonus = 150;
        } else if (lockMode == YIELD_MODE_30D) {
            if (core.level == 5) bonus = 100;
            else if (core.level == 6) bonus = 200;
            else bonus = 300;
        } else {
            revert InvalidYieldMode();
        }

        if (core.specialization == CityBuildingTypes.BuildingSpecialization.ResourceVault) {
            bonus += lockMode == YIELD_MODE_7D ? 50 : 100;
        } else if (core.specialization == CityBuildingTypes.BuildingSpecialization.TradeDepot) {
            bonus += lockMode == YIELD_MODE_7D ? 75 : 125;
        } else if (core.specialization == CityBuildingTypes.BuildingSpecialization.MerchantVault) {
            bonus += lockMode == YIELD_MODE_7D ? 100 : 150;
        } else if (core.specialization == CityBuildingTypes.BuildingSpecialization.FortressVault) {
            bonus += lockMode == YIELD_MODE_7D ? 50 : 75;
        }

        return bonus;
    }

    function _effectiveYieldBps(
        CityBuildingTypes.BuildingCore memory core,
        uint8 resourceId,
        uint8 lockMode
    ) internal view returns (uint32) {
        uint32 base = _baseYieldBps(resourceId, lockMode);
        uint32 bonus = _warehouseYieldBonusBps(core, lockMode);
        uint32 effective = base + bonus;
        return effective > MAX_BPS ? MAX_BPS : effective;
    }

    function _effectiveYieldBpsFromConfig(
        CityBuildingTypes.BuildingCore memory core,
        ResourceYieldConfig memory config,
        uint8 lockMode
    ) internal pure returns (uint32) {
        uint32 base = _baseYieldBpsFromConfig(config, lockMode);
        uint32 bonus = _warehouseYieldBonusBps(core, lockMode);
        uint32 effective = base + bonus;
        return effective > MAX_BPS ? MAX_BPS : effective;
    }

    function _recommendedVaultTier(
        CityBuildingTypes.BuildingCore memory core
    ) internal pure returns (uint8) {
        if (core.level >= 7) return 4;
        if (core.level >= 5) return 3;
        if (core.level >= 3) return 2;
        return 1;
    }

    function _recommendedDefenseTier(
        CityBuildingTypes.BuildingCore memory core
    ) internal pure returns (uint8) {
        uint8 tier;
        if (core.level >= 7) tier = 3;
        else if (core.level >= 5) tier = 2;
        else if (core.level >= 3) tier = 1;
        else tier = 0;

        if (core.specialization == CityBuildingTypes.BuildingSpecialization.FortressVault) {
            tier += 1;
        }

        return tier;
    }

    function _recommendedVaultCapBps(
        CityBuildingTypes.BuildingCore memory core
    ) internal pure returns (uint32) {
        uint32 cap;
        if (core.level == 1) cap = 1500;
        else if (core.level == 2) cap = 2200;
        else if (core.level == 3) cap = 3200;
        else if (core.level == 4) cap = 4200;
        else if (core.level == 5) cap = 5600;
        else if (core.level == 6) cap = 7000;
        else cap = 8500;

        if (core.specialization == CityBuildingTypes.BuildingSpecialization.ResourceVault) {
            cap += 500;
        } else if (core.specialization == CityBuildingTypes.BuildingSpecialization.TradeDepot) {
            cap += 250;
        } else if (core.specialization == CityBuildingTypes.BuildingSpecialization.MerchantVault) {
            cap += 400;
        } else if (core.specialization == CityBuildingTypes.BuildingSpecialization.FortressVault) {
            cap += 300;
        }

        return cap > MAX_BPS ? MAX_BPS : cap;
    }

    function _recommendedDefenseBps(
        CityBuildingTypes.BuildingCore memory core
    ) internal pure returns (uint32) {
        uint32 defense;
        if (core.level <= 2) defense = 0;
        else if (core.level == 3) defense = 200;
        else if (core.level == 4) defense = 400;
        else if (core.level == 5) defense = 650;
        else if (core.level == 6) defense = 900;
        else defense = 1200;

        if (core.specialization == CityBuildingTypes.BuildingSpecialization.FortressVault) {
            defense += 250;
        } else if (core.specialization == CityBuildingTypes.BuildingSpecialization.MerchantVault) {
            defense += 100;
        }

        return defense > MAX_BPS ? MAX_BPS : defense;
    }

    function _recommendedRaidMitigationBps(
        CityBuildingTypes.BuildingCore memory core
    ) internal pure returns (uint32) {
        uint32 mitigation;
        if (core.level <= 3) mitigation = 0;
        else if (core.level == 4) mitigation = 175;
        else if (core.level == 5) mitigation = 350;
        else if (core.level == 6) mitigation = 525;
        else mitigation = 800;

        if (core.specialization == CityBuildingTypes.BuildingSpecialization.FortressVault) {
            mitigation += 200;
        } else if (core.specialization == CityBuildingTypes.BuildingSpecialization.ResourceVault) {
            mitigation += 75;
        }

        return mitigation > MAX_BPS ? MAX_BPS : mitigation;
    }

    function _recommendedBucketProfile(
        CityBuildingTypes.BuildingCore memory core
    )
        internal
        pure
        returns (
            uint32 reserveBuckets,
            uint32 protectedBuckets,
            uint32 raidableBuckets
        )
    {
        if (core.level == 1) {
            reserveBuckets = 1;
            protectedBuckets = 1;
            raidableBuckets = 1;
        } else if (core.level == 2) {
            reserveBuckets = 2;
            protectedBuckets = 1;
            raidableBuckets = 2;
        } else if (core.level == 3) {
            reserveBuckets = 3;
            protectedBuckets = 1;
            raidableBuckets = 2;
        } else if (core.level == 4) {
            reserveBuckets = 4;
            protectedBuckets = 1;
            raidableBuckets = 3;
        } else if (core.level == 5) {
            reserveBuckets = 5;
            protectedBuckets = 2;
            raidableBuckets = 3;
        } else if (core.level == 6) {
            reserveBuckets = 6;
            protectedBuckets = 2;
            raidableBuckets = 4;
        } else {
            reserveBuckets = 8;
            protectedBuckets = 3;
            raidableBuckets = 4;
        }

        if (core.specialization == CityBuildingTypes.BuildingSpecialization.ResourceVault) {
            protectedBuckets += 1;
        } else if (core.specialization == CityBuildingTypes.BuildingSpecialization.TradeDepot) {
            reserveBuckets += 1;
        } else if (core.specialization == CityBuildingTypes.BuildingSpecialization.FortressVault) {
            protectedBuckets += 1;
            if (raidableBuckets > 0) raidableBuckets -= 1;
        } else if (core.specialization == CityBuildingTypes.BuildingSpecialization.MerchantVault) {
            reserveBuckets += 1;
            protectedBuckets += 1;
        }
    }
}