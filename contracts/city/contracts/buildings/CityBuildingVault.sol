// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "../libraries/CityBuildingTypes.sol";
import "../../interfaces/buildings/ICityBuildingVault.sol";

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
    ICityBuildingVault
{
    /*//////////////////////////////////////////////////////////////
                                 ROLES
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant VAULT_ADMIN_ROLE = keccak256("VAULT_ADMIN_ROLE");
    bytes32 public constant VAULT_OPERATOR_ROLE = keccak256("VAULT_OPERATOR_ROLE");
    bytes32 public constant VAULT_CALLER_ROLE = keccak256("VAULT_CALLER_ROLE");
    bytes32 public constant RAID_CALLER_ROLE = keccak256("RAID_CALLER_ROLE");
    bytes32 public constant REPAIR_CALLER_ROLE = keccak256("REPAIR_CALLER_ROLE");

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
    error BuildingArchived();
    error BuildingPreparedForMigration();
    error VaultNotEnabled();
    error VaultAlreadyEnabled();
    error EmergencyLocked();
    error AmountExceedsStored();
    error AmountExceedsRaidable();
    error AmountExceedsProtected();

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

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    ICityBuildingNFTV1VaultRead public buildingNFT;

    mapping(uint256 => WarehouseVaultProfile) internal _vaultProfiles;
    mapping(uint256 => mapping(uint8 => VaultResourceState)) internal _vaultResources;

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

    /*//////////////////////////////////////////////////////////////
                         VAULT ENABLE / CONFIG
    //////////////////////////////////////////////////////////////*/

    function enableWarehouseVault(
        uint256 buildingId,
        uint8 vaultTier,
        uint32 vaultCapBps
    ) external onlyRole(VAULT_OPERATOR_ROLE) whenNotPaused {
        _requireWarehouse(buildingId);

        WarehouseVaultProfile storage p = _vaultProfiles[buildingId];
        if (p.vaultEnabled) revert VaultAlreadyEnabled();
        if (vaultCapBps > MAX_BPS) revert InvalidBps();

        p.vaultEnabled = true;
        p.raidEnabled = false;
        p.repairRequired = false;
        p.emergencyLocked = false;

        p.vaultTier = vaultTier;
        p.defenseTier = 0;
        p.decayState = DECAY_STABLE;
        p.repairState = REPAIR_NOT_REQUIRED;

        p.vaultCapBps = vaultCapBps;
        p.defenseBps = 0;
        p.raidMitigationBps = 0;
        p.damageBps = 0;

        p.activatedAt = uint64(block.timestamp);
        p.lastVaultActionAt = uint64(block.timestamp);
        p.lastDecayCheckAt = uint64(block.timestamp);
        p.lastRepairAt = 0;
        p.lastRaidAt = 0;

        emit WarehouseVaultEnabled(buildingId, vaultTier, vaultCapBps, msg.sender);
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
        p.repairRequired = (
            repairState == REPAIR_MINOR_REQUIRED ||
            repairState == REPAIR_MAJOR_REQUIRED ||
            repairState == REPAIR_LOCKED_UNTIL_REPAIR
        );
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

        if (reserved > stored) revert AmountExceedsStored();
        if (protectedAmount > stored) revert AmountExceedsStored();
        if (raidableAmount > stored) revert AmountExceedsStored();

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
        p.repairRequired = (
            repairState == REPAIR_MINOR_REQUIRED ||
            repairState == REPAIR_MAJOR_REQUIRED ||
            repairState == REPAIR_LOCKED_UNTIL_REPAIR
        );
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
        p.repairRequired = (
            repairState == REPAIR_MINOR_REQUIRED ||
            repairState == REPAIR_MAJOR_REQUIRED ||
            repairState == REPAIR_LOCKED_UNTIL_REPAIR
        );

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

    /*//////////////////////////////////////////////////////////////
                               INTERNALS
    //////////////////////////////////////////////////////////////*/

    function _requireWarehouse(uint256 buildingId) internal view {
        if (buildingId == 0) revert InvalidBuildingId();
        if (buildingNFT.isArchived(buildingId)) revert BuildingArchived();
        if (buildingNFT.isMigrationPrepared(buildingId)) revert BuildingPreparedForMigration();

        CityBuildingTypes.BuildingCore memory core = buildingNFT.getBuildingCore(buildingId);
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
}