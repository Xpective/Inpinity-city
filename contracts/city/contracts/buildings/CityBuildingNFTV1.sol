// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/interfaces/IERC4906.sol";

import "../libraries/CityBuildingTypes.sol";

/*//////////////////////////////////////////////////////////////
                      V2 MIGRATION INTERFACE
//////////////////////////////////////////////////////////////*/

/// @notice Interface that a V2 building contract or dedicated migrator must implement.
interface ICityBuildingV2Receiver {
    function receiveMigration(
        uint256 oldBuildingId,
        address originalOwner,
        CityBuildingTypes.BuildingCore calldata core,
        CityBuildingTypes.BuildingMeta calldata meta,
        CityBuildingTypes.BuildingUsageStats calldata usage,
        CityBuildingTypes.BuildingHistoryCounters calldata history,
        uint64 lastUpgradeAt,
        uint64 lastTransferredAt,
        uint64 lastMeaningfulUseAt,
        uint32 migrationNonce
    ) external returns (uint256 newBuildingId);
}

/// @title CityBuildingNFTV1
/// @notice Tradable personal building NFT identity layer for Inpinity City V1.
/// @dev Holds building identity, progression, specialization, metadata, history and usage counters.
///      Placement logic stays in CityBuildingPlacement.
///      Upgrade cost / resource / PIT / tech gating stays in PersonalBuildings.
///      Migration uses archive semantics: the V1 token is not burned, but permanently frozen after archive.
contract CityBuildingNFTV1 is ERC721, AccessControl, Pausable, IERC4906 {
    using CityBuildingTypes for CityBuildingTypes.BuildingUsageStats;

    /*//////////////////////////////////////////////////////////////
                                 ROLES
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PLACEMENT_ROLE = keccak256("PLACEMENT_ROLE");
    bytes32 public constant USAGE_ROLE = keccak256("USAGE_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant URI_MANAGER_ROLE = keccak256("URI_MANAGER_ROLE");
    bytes32 public constant STATE_MANAGER_ROLE = keccak256("STATE_MANAGER_ROLE");
    bytes32 public constant VERSION_MANAGER_ROLE = keccak256("VERSION_MANAGER_ROLE");
    bytes32 public constant MIGRATION_ADMIN_ROLE = keccak256("MIGRATION_ADMIN_ROLE");

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidBuildingType();
    error InvalidLevel();
    error InvalidNameLength();
    error InvalidState();
    error InvalidSpecialization();
    error InvalidFactionVariant();
    error BuildingDoesNotExist();
    error TransferWhilePlacedBlocked();
    error TransferWhilePreparedForMigration();
    error TransferWhileArchivedBlocked();
    error OperationBlockedWhilePrepared();
    error NotTokenOwnerNorApproved();
    error NoStateChange();
    error NoVersionChange();
    error LevelNotIncremental();
    error ZeroAddress();
    error AlreadyPreparedForMigration();
    error MigrationTargetNotSet();
    error NotPreparedForMigration();
    error CannotPrepareWhilePlaced();
    error MigrationDelayNotElapsed();
    error AlreadyArchived();
    error MigrationFailed();
    error MigrationClosed();
    error InvalidMigrationConfig();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event BuildingMinted(
        uint256 indexed buildingId,
        CityBuildingTypes.PersonalBuildingType indexed buildingType,
        address indexed minter,
        address to,
        uint64 mintedAt
    );

    event BuildingRenamed(
        uint256 indexed buildingId,
        string newName,
        address indexed executor
    );

    event BuildingUpgraded(
        uint256 indexed buildingId,
        uint8 oldLevel,
        uint8 newLevel,
        address indexed executor,
        uint64 upgradedAt
    );

    event BuildingSpecialized(
        uint256 indexed buildingId,
        CityBuildingTypes.BuildingSpecialization oldSpecialization,
        CityBuildingTypes.BuildingSpecialization newSpecialization,
        address indexed executor
    );

    event BuildingFactionVariantChosen(
        uint256 indexed buildingId,
        CityBuildingTypes.FactionVariant oldVariant,
        CityBuildingTypes.FactionVariant newVariant,
        address indexed executor
    );

    event BuildingPlacementStateChanged(
        uint256 indexed buildingId,
        bool placed,
        address indexed executor
    );

    event BuildingStateChanged(
        uint256 indexed buildingId,
        CityBuildingTypes.BuildingState oldState,
        CityBuildingTypes.BuildingState newState,
        address indexed executor
    );

    event BuildingUsageRecorded(
        uint256 indexed buildingId,
        CityBuildingTypes.BuildingUsageType indexed usageType,
        uint32 amount,
        address indexed executor
    );

    event StorageVolumeRecorded(
        uint256 indexed buildingId,
        uint256 addedVolume,
        uint256 removedVolume,
        uint256 newTotalStoredVolume,
        address indexed executor
    );

    event BuildingMaintenanceRecorded(
        uint256 indexed buildingId,
        uint32 newMaintenanceActions,
        address indexed executor
    );

    event BuildingLifecycleInterruptionRecorded(
        uint256 indexed buildingId,
        uint32 newLifecycleInterruptions,
        address indexed executor
    );

    event BuildingPublicSessionRecorded(
        uint256 indexed buildingId,
        uint32 newPublicSessions,
        address indexed executor
    );

    event BuildingVersionTagUpdated(
        uint256 indexed buildingId,
        uint32 oldVersionTag,
        uint32 newVersionTag,
        address indexed executor
    );

    event BaseURISet(string newBaseURI, address indexed executor);

    event MigrationTargetSet(address indexed target, bool open, address indexed executor);

    event BuildingPreparedForMigration(
        uint256 indexed buildingId,
        uint64 preparedAt,
        uint32 nonce
    );

    event BuildingUnpreparedForMigration(
        uint256 indexed buildingId,
        uint64 unpreparedAt
    );

    /// @notice Emitted when a building is archived after successful V2 migration.
    event BuildingArchived(
        uint256 indexed buildingId,
        uint256 indexed newV2BuildingId,
        address indexed migrator,
        uint64 archivedAt
    );

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public nextBuildingId = 1;
    string private _baseTokenURI;

    mapping(uint256 => CityBuildingTypes.BuildingCore) private _buildingCore;
    mapping(uint256 => CityBuildingTypes.BuildingMeta) private _buildingMeta;
    mapping(uint256 => CityBuildingTypes.BuildingUsageStats) private _buildingUsage;
    mapping(uint256 => CityBuildingTypes.BuildingHistoryCounters) private _buildingHistory;
    mapping(uint256 => CityBuildingTypes.BuildingState) private _buildingState;

    mapping(uint256 => bool) public preparedForMigration;
    mapping(uint256 => uint64) public preparedForMigrationAt;
    mapping(uint256 => uint32) public migrationPreparationNonce;

    mapping(uint256 => bool) public archivedToV2;
    mapping(uint256 => uint256) public v2BuildingId;

    address public migrationTarget;
    bool public migrationOpen;

    uint64 public constant MIGRATION_PREP_DELAY = 1 days;
    uint32 public constant CONTRACT_VERSION = CityBuildingTypes.VERSION_TAG_V1;

    mapping(uint256 => uint64) public lastUpgradeAt;
    mapping(uint256 => uint64) public lastTransferredAt;
    mapping(uint256 => uint64) public lastMeaningfulUseAt;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseTokenURI_,
        address admin_
    ) ERC721(name_, symbol_) {
        if (admin_ == address(0)) revert ZeroAddress();

        _baseTokenURI = baseTokenURI_;

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(MINTER_ROLE, admin_);
        _grantRole(UPGRADER_ROLE, admin_);
        _grantRole(PLACEMENT_ROLE, admin_);
        _grantRole(USAGE_ROLE, admin_);
        _grantRole(PAUSER_ROLE, admin_);
        _grantRole(URI_MANAGER_ROLE, admin_);
        _grantRole(STATE_MANAGER_ROLE, admin_);
        _grantRole(VERSION_MANAGER_ROLE, admin_);
        _grantRole(MIGRATION_ADMIN_ROLE, admin_);
    }

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyExisting(uint256 buildingId) {
        if (!_existsCompat(buildingId)) revert BuildingDoesNotExist();
        _;
    }

    modifier onlyTokenOwnerOrApproved(uint256 buildingId) {
        if (!_isOwnerOrApprovedCompat(msg.sender, buildingId)) {
            revert NotTokenOwnerNorApproved();
        }
        _;
    }

    modifier onlyTokenOwner(uint256 buildingId) {
        if (_ownerOf(buildingId) != msg.sender) revert NotTokenOwnerNorApproved();
        _;
    }

    modifier notPreparedForMigration(uint256 buildingId) {
        if (preparedForMigration[buildingId]) revert OperationBlockedWhilePrepared();
        _;
    }

    modifier notArchived(uint256 buildingId) {
        if (archivedToV2[buildingId]) revert AlreadyArchived();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               ADMIN / PAUSE
    //////////////////////////////////////////////////////////////*/

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function setBaseURI(string calldata newBaseURI) external onlyRole(URI_MANAGER_ROLE) {
        _baseTokenURI = newBaseURI;
        emit BaseURISet(newBaseURI, msg.sender);
    }

    /// @notice Sets the V2 receiver target and opens/closes migration.
    /// @dev No probe-call is performed here; compatibility must be verified offchain or operationally.
    /// @dev target may be zero only when open == false.
    function setMigrationTarget(address target, bool open) external onlyRole(MIGRATION_ADMIN_ROLE) {
        if (open && target == address(0)) revert InvalidMigrationConfig();

        migrationTarget = target;
        migrationOpen = open;

        emit MigrationTargetSet(target, open, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                                  MINT
    //////////////////////////////////////////////////////////////*/

    function mintBuilding(
        address to,
        CityBuildingTypes.PersonalBuildingType buildingType,
        uint32 versionTag
    ) external onlyRole(MINTER_ROLE) whenNotPaused returns (uint256 buildingId) {
        if (to == address(0)) revert ZeroAddress();
        if (!CityBuildingTypes.isValidBaseType(buildingType)) revert InvalidBuildingType();

        buildingId = nextBuildingId++;
        _safeMint(to, buildingId);

        _buildingCore[buildingId] = CityBuildingTypes.BuildingCore({
            category: CityBuildingTypes.BuildingCategory.Personal,
            buildingType: buildingType,
            level: 1,
            specialization: CityBuildingTypes.BuildingSpecialization.None,
            factionVariant: CityBuildingTypes.FactionVariant.None,
            mintedAt: uint64(block.timestamp),
            firstOwner: to
        });

        _buildingMeta[buildingId] = CityBuildingTypes.BuildingMeta({
            customName: "",
            versionTag: versionTag == 0 ? CityBuildingTypes.VERSION_TAG_V1 : versionTag,
            totalUses: 0,
            totalTransfers: 0,
            totalUpgrades: 0,
            prestigeScore: 0,
            historyScore: 0
        });

        _buildingState[buildingId] = CityBuildingTypes.BuildingState.Unplaced;

        emit BuildingMinted(
            buildingId,
            buildingType,
            msg.sender,
            to,
            uint64(block.timestamp)
        );
        emit MetadataUpdate(buildingId);
    }

    /*//////////////////////////////////////////////////////////////
                             OWNER / USER ACTIONS
    //////////////////////////////////////////////////////////////*/

    function renameBuilding(
        uint256 buildingId,
        string calldata newName
    )
        external
        whenNotPaused
        onlyExisting(buildingId)
        onlyTokenOwnerOrApproved(buildingId)
        notPreparedForMigration(buildingId)
        notArchived(buildingId)
    {
        if (!CityBuildingTypes.supportsCustomName(_buildingCore[buildingId].buildingType)) {
            revert InvalidBuildingType();
        }
        if (!CityBuildingTypes.isNameLengthValid(newName)) revert InvalidNameLength();

        _buildingMeta[buildingId].customName = newName;

        emit BuildingRenamed(buildingId, newName, msg.sender);
        emit MetadataUpdate(buildingId);
    }

    /*//////////////////////////////////////////////////////////////
                           UPGRADE / SPECIALIZE
    //////////////////////////////////////////////////////////////*/

    function upgradeBuilding(
        uint256 buildingId,
        uint8 newLevel
    )
        external
        onlyRole(UPGRADER_ROLE)
        whenNotPaused
        onlyExisting(buildingId)
        notPreparedForMigration(buildingId)
        notArchived(buildingId)
    {
        CityBuildingTypes.BuildingCore storage core = _buildingCore[buildingId];
        uint8 oldLevel = core.level;

        if (!CityBuildingTypes.isValidLevel(newLevel)) revert InvalidLevel();
        if (newLevel != oldLevel + 1) revert LevelNotIncremental();

        core.level = newLevel;
        _buildingMeta[buildingId].totalUpgrades += 1;
        lastUpgradeAt[buildingId] = uint64(block.timestamp);

        emit BuildingUpgraded(
            buildingId,
            oldLevel,
            newLevel,
            msg.sender,
            uint64(block.timestamp)
        );
        emit MetadataUpdate(buildingId);
    }

    function specializeBuilding(
        uint256 buildingId,
        CityBuildingTypes.BuildingSpecialization newSpecialization
    )
        external
        onlyRole(UPGRADER_ROLE)
        whenNotPaused
        onlyExisting(buildingId)
        notPreparedForMigration(buildingId)
        notArchived(buildingId)
    {
        CityBuildingTypes.BuildingCore storage core = _buildingCore[buildingId];

        if (
            !CityBuildingTypes.canChooseSpecialization(
                core.buildingType,
                core.level,
                newSpecialization
            )
        ) revert InvalidSpecialization();

        CityBuildingTypes.BuildingSpecialization oldSpecialization = core.specialization;
        if (oldSpecialization == newSpecialization) revert NoStateChange();

        core.specialization = newSpecialization;
        _buildingHistory[buildingId].specializationChanges += 1;

        emit BuildingSpecialized(
            buildingId,
            oldSpecialization,
            newSpecialization,
            msg.sender
        );
        emit MetadataUpdate(buildingId);
    }

    function setFactionVariant(
        uint256 buildingId,
        CityBuildingTypes.FactionVariant newVariant
    )
        external
        onlyRole(UPGRADER_ROLE)
        whenNotPaused
        onlyExisting(buildingId)
        notPreparedForMigration(buildingId)
        notArchived(buildingId)
    {
        CityBuildingTypes.BuildingCore storage core = _buildingCore[buildingId];

        if (!CityBuildingTypes.canHaveFactionVariant(core.buildingType)) {
            revert InvalidFactionVariant();
        }

        CityBuildingTypes.FactionVariant oldVariant = core.factionVariant;
        if (oldVariant == newVariant) revert NoStateChange();

        core.factionVariant = newVariant;

        emit BuildingFactionVariantChosen(
            buildingId,
            oldVariant,
            newVariant,
            msg.sender
        );
        emit MetadataUpdate(buildingId);
    }

    function setVersionTag(
        uint256 buildingId,
        uint32 newVersionTag
    )
        external
        onlyRole(VERSION_MANAGER_ROLE)
        onlyExisting(buildingId)
        notPreparedForMigration(buildingId)
        notArchived(buildingId)
    {
        uint32 oldVersionTag = _buildingMeta[buildingId].versionTag;
        if (oldVersionTag == newVersionTag) revert NoVersionChange();

        _buildingMeta[buildingId].versionTag = newVersionTag;

        emit BuildingVersionTagUpdated(
            buildingId,
            oldVersionTag,
            newVersionTag,
            msg.sender
        );
        emit MetadataUpdate(buildingId);
    }

    /*//////////////////////////////////////////////////////////////
                         PLACEMENT / STATE SYNC
    //////////////////////////////////////////////////////////////*/

    function setPlaced(
        uint256 buildingId,
        bool placed
    )
        external
        onlyRole(PLACEMENT_ROLE)
        onlyExisting(buildingId)
        notPreparedForMigration(buildingId)
        notArchived(buildingId)
    {
        CityBuildingTypes.BuildingState oldState = _buildingState[buildingId];
        CityBuildingTypes.BuildingState newState =
            placed
                ? CityBuildingTypes.BuildingState.PlacedActive
                : CityBuildingTypes.BuildingState.Unplaced;

        if (oldState == newState) revert NoStateChange();

        _buildingState[buildingId] = newState;

        emit BuildingPlacementStateChanged(buildingId, placed, msg.sender);
        emit BuildingStateChanged(buildingId, oldState, newState, msg.sender);
        emit MetadataUpdate(buildingId);
    }

    function setBuildingState(
        uint256 buildingId,
        CityBuildingTypes.BuildingState newState
    )
        external
        onlyRole(STATE_MANAGER_ROLE)
        onlyExisting(buildingId)
        notPreparedForMigration(buildingId)
        notArchived(buildingId)
    {
        if (
            newState == CityBuildingTypes.BuildingState.None
            || newState == CityBuildingTypes.BuildingState.Archived
        ) revert InvalidState();

        CityBuildingTypes.BuildingState oldState = _buildingState[buildingId];
        if (oldState == newState) revert NoStateChange();

        _buildingState[buildingId] = newState;

        emit BuildingStateChanged(buildingId, oldState, newState, msg.sender);
        emit MetadataUpdate(buildingId);
    }

    /*//////////////////////////////////////////////////////////////
                           USAGE / HISTORY TRACKING
    //////////////////////////////////////////////////////////////*/

    function recordUsage(
        uint256 buildingId,
        CityBuildingTypes.BuildingUsageType usageType,
        uint32 amount
    )
        external
        onlyRole(USAGE_ROLE)
        whenNotPaused
        onlyExisting(buildingId)
        notPreparedForMigration(buildingId)
        notArchived(buildingId)
    {
        if (amount == 0) revert NoStateChange();

        _buildingUsage[buildingId].incrementUsage(usageType, amount);
        _buildingMeta[buildingId].totalUses += amount;
        lastMeaningfulUseAt[buildingId] = uint64(block.timestamp);

        emit BuildingUsageRecorded(buildingId, usageType, amount, msg.sender);
        emit MetadataUpdate(buildingId);
    }

    function recordStorageVolume(
        uint256 buildingId,
        uint256 addedVolume,
        uint256 removedVolume
    )
        external
        onlyRole(USAGE_ROLE)
        whenNotPaused
        onlyExisting(buildingId)
        notPreparedForMigration(buildingId)
        notArchived(buildingId)
    {
        CityBuildingTypes.BuildingUsageStats storage stats = _buildingUsage[buildingId];
        uint256 current = stats.totalStoredVolume;

        if (removedVolume > current) {
            stats.totalStoredVolume = 0;
        } else {
            stats.totalStoredVolume = current - removedVolume;
        }

        if (addedVolume > 0) {
            stats.totalStoredVolume += addedVolume;
        }

        lastMeaningfulUseAt[buildingId] = uint64(block.timestamp);

        emit StorageVolumeRecorded(
            buildingId,
            addedVolume,
            removedVolume,
            stats.totalStoredVolume,
            msg.sender
        );
        emit MetadataUpdate(buildingId);
    }

    function recordMaintenance(
        uint256 buildingId,
        uint32 amount
    )
        external
        onlyRole(USAGE_ROLE)
        whenNotPaused
        onlyExisting(buildingId)
        notPreparedForMigration(buildingId)
        notArchived(buildingId)
    {
        if (amount == 0) revert NoStateChange();

        _buildingHistory[buildingId].maintenanceActions += amount;
        lastMeaningfulUseAt[buildingId] = uint64(block.timestamp);

        emit BuildingMaintenanceRecorded(
            buildingId,
            _buildingHistory[buildingId].maintenanceActions,
            msg.sender
        );
        emit MetadataUpdate(buildingId);
    }

    function recordLifecycleInterruption(
        uint256 buildingId,
        uint32 amount
    )
        external
        onlyRole(USAGE_ROLE)
        whenNotPaused
        onlyExisting(buildingId)
        notPreparedForMigration(buildingId)
        notArchived(buildingId)
    {
        if (amount == 0) revert NoStateChange();

        _buildingHistory[buildingId].lifecycleInterruptions += amount;

        emit BuildingLifecycleInterruptionRecorded(
            buildingId,
            _buildingHistory[buildingId].lifecycleInterruptions,
            msg.sender
        );
        emit MetadataUpdate(buildingId);
    }

    function recordPublicSession(
        uint256 buildingId,
        uint32 amount
    )
        external
        onlyRole(USAGE_ROLE)
        whenNotPaused
        onlyExisting(buildingId)
        notPreparedForMigration(buildingId)
        notArchived(buildingId)
    {
        if (amount == 0) revert NoStateChange();

        _buildingHistory[buildingId].publicSessions += amount;
        lastMeaningfulUseAt[buildingId] = uint64(block.timestamp);

        emit BuildingPublicSessionRecorded(
            buildingId,
            _buildingHistory[buildingId].publicSessions,
            msg.sender
        );
        emit MetadataUpdate(buildingId);
    }

    function addPrestigeScore(
        uint256 buildingId,
        uint32 amount
    )
        external
        onlyRole(USAGE_ROLE)
        whenNotPaused
        onlyExisting(buildingId)
        notPreparedForMigration(buildingId)
        notArchived(buildingId)
    {
        if (amount == 0) revert NoStateChange();

        _buildingMeta[buildingId].prestigeScore += amount;
        lastMeaningfulUseAt[buildingId] = uint64(block.timestamp);

        emit MetadataUpdate(buildingId);
    }

    function addHistoryScore(
        uint256 buildingId,
        uint32 amount
    )
        external
        onlyRole(USAGE_ROLE)
        whenNotPaused
        onlyExisting(buildingId)
        notPreparedForMigration(buildingId)
        notArchived(buildingId)
    {
        if (amount == 0) revert NoStateChange();

        _buildingMeta[buildingId].historyScore += amount;
        lastMeaningfulUseAt[buildingId] = uint64(block.timestamp);

        emit MetadataUpdate(buildingId);
    }

    /*//////////////////////////////////////////////////////////////
                          MIGRATION PREPARATION
    //////////////////////////////////////////////////////////////*/

    function prepareForMigration(
        uint256 buildingId
    )
        external
        whenNotPaused
        onlyExisting(buildingId)
        onlyTokenOwner(buildingId)
        notArchived(buildingId)
    {
        if (preparedForMigration[buildingId]) revert AlreadyPreparedForMigration();
        _requireNotPlaced(buildingId);
        _requireMigrationReady();

        preparedForMigration[buildingId] = true;
        preparedForMigrationAt[buildingId] = uint64(block.timestamp);
        migrationPreparationNonce[buildingId]++;

        emit BuildingPreparedForMigration(
            buildingId,
            uint64(block.timestamp),
            migrationPreparationNonce[buildingId]
        );
        emit MetadataUpdate(buildingId);
    }

    function unprepareForMigration(
        uint256 buildingId
    )
        external
        whenNotPaused
        onlyExisting(buildingId)
        onlyTokenOwner(buildingId)
        notArchived(buildingId)
    {
        if (!preparedForMigration[buildingId]) revert NotPreparedForMigration();

        preparedForMigration[buildingId] = false;
        delete preparedForMigrationAt[buildingId];

        emit BuildingUnpreparedForMigration(buildingId, uint64(block.timestamp));
        emit MetadataUpdate(buildingId);
    }

    /*//////////////////////////////////////////////////////////////
                          ACTIVE MIGRATION TO V2
    //////////////////////////////////////////////////////////////*/

    /// @notice Archives a prepared building to V2. V1 data remains readable.
    function migrateToV2(
        uint256 buildingId
    )
        external
        whenNotPaused
        onlyExisting(buildingId)
        onlyTokenOwner(buildingId)
        notArchived(buildingId)
    {
        if (!preparedForMigration[buildingId]) revert NotPreparedForMigration();
        _requireMigrationReady();
        _requireNotPlaced(buildingId);

        if (block.timestamp < preparedForMigrationAt[buildingId] + MIGRATION_PREP_DELAY) {
            revert MigrationDelayNotElapsed();
        }

        CityBuildingTypes.BuildingCore memory core = _buildingCore[buildingId];
        CityBuildingTypes.BuildingMeta memory meta = _buildingMeta[buildingId];
        CityBuildingTypes.BuildingUsageStats memory usage = _buildingUsage[buildingId];
        CityBuildingTypes.BuildingHistoryCounters memory history = _buildingHistory[buildingId];
        uint32 nonce = migrationPreparationNonce[buildingId];

        uint256 newBuildingId;
        try ICityBuildingV2Receiver(migrationTarget).receiveMigration(
            buildingId,
            msg.sender,
            core,
            meta,
            usage,
            history,
            lastUpgradeAt[buildingId],
            lastTransferredAt[buildingId],
            lastMeaningfulUseAt[buildingId],
            nonce
        ) returns (uint256 newId) {
            newBuildingId = newId;
        } catch {
            revert MigrationFailed();
        }

        archivedToV2[buildingId] = true;
        v2BuildingId[buildingId] = newBuildingId;
        _buildingState[buildingId] = CityBuildingTypes.BuildingState.Archived;
        _buildingHistory[buildingId].migrations += 1;

        emit BuildingArchived(
            buildingId,
            newBuildingId,
            msg.sender,
            uint64(block.timestamp)
        );
        emit MetadataUpdate(buildingId);
    }

    /*//////////////////////////////////////////////////////////////
                                  READS
    //////////////////////////////////////////////////////////////*/

    function exists(uint256 buildingId) external view returns (bool) {
        return _existsCompat(buildingId);
    }

    function canMigrate(uint256 buildingId) external view returns (bool) {
        return
            _existsCompat(buildingId) &&
            preparedForMigration[buildingId] &&
            !CityBuildingTypes.isPlacedState(_buildingState[buildingId]) &&
            migrationTarget != address(0) &&
            migrationOpen &&
            !archivedToV2[buildingId] &&
            block.timestamp >= preparedForMigrationAt[buildingId] + MIGRATION_PREP_DELAY;
    }

    function isMigrationPrepared(uint256 buildingId) external view returns (bool) {
        return preparedForMigration[buildingId];
    }

    function isArchived(uint256 buildingId) external view returns (bool) {
        return archivedToV2[buildingId];
    }

    function getV2BuildingId(uint256 buildingId) external view returns (uint256) {
        return v2BuildingId[buildingId];
    }

    function isTransferBlocked(uint256 buildingId) external view returns (bool) {
        if (!_existsCompat(buildingId)) return false;
        return CityBuildingTypes.isPlacedState(_buildingState[buildingId])
            || preparedForMigration[buildingId]
            || archivedToV2[buildingId];
    }

    function isPlacedBuilding(uint256 buildingId) public view onlyExisting(buildingId) returns (bool) {
        return CityBuildingTypes.isPlacedState(_buildingState[buildingId]);
    }

    struct BuildingFull {
        CityBuildingTypes.BuildingCore core;
        CityBuildingTypes.BuildingMeta meta;
        CityBuildingTypes.BuildingUsageStats usage;
        CityBuildingTypes.BuildingHistoryCounters history;
        CityBuildingTypes.BuildingState state;
        bool placed;
        bool preparedForMigration;
        uint64 preparedAt;
        uint64 lastUpgradeAt;
        uint64 lastTransferAt;
        uint64 lastMeaningfulUse;
        bool archived;
        uint256 v2Id;
    }

    function getBuildingFull(
        uint256 buildingId
    ) external view onlyExisting(buildingId) returns (BuildingFull memory) {
        return BuildingFull({
            core: _buildingCore[buildingId],
            meta: _buildingMeta[buildingId],
            usage: _buildingUsage[buildingId],
            history: _buildingHistory[buildingId],
            state: _buildingState[buildingId],
            placed: CityBuildingTypes.isPlacedState(_buildingState[buildingId]),
            preparedForMigration: preparedForMigration[buildingId],
            preparedAt: preparedForMigrationAt[buildingId],
            lastUpgradeAt: lastUpgradeAt[buildingId],
            lastTransferAt: lastTransferredAt[buildingId],
            lastMeaningfulUse: lastMeaningfulUseAt[buildingId],
            archived: archivedToV2[buildingId],
            v2Id: v2BuildingId[buildingId]
        });
    }

    struct BuildingSummary {
        CityBuildingTypes.PersonalBuildingType buildingType;
        uint8 level;
        CityBuildingTypes.BuildingSpecialization specialization;
        CityBuildingTypes.BuildingState state;
        bool placed;
        bool preparedForMigration;
        bool archived;
        uint32 totalUses;
        uint32 prestigeScore;
        uint32 historyScore;
    }

    function getBuildingSummary(
        uint256 buildingId
    ) external view onlyExisting(buildingId) returns (BuildingSummary memory) {
        CityBuildingTypes.BuildingCore memory core = _buildingCore[buildingId];
        return BuildingSummary({
            buildingType: core.buildingType,
            level: core.level,
            specialization: core.specialization,
            state: _buildingState[buildingId],
            placed: CityBuildingTypes.isPlacedState(_buildingState[buildingId]),
            preparedForMigration: preparedForMigration[buildingId],
            archived: archivedToV2[buildingId],
            totalUses: _buildingMeta[buildingId].totalUses,
            prestigeScore: _buildingMeta[buildingId].prestigeScore,
            historyScore: _buildingMeta[buildingId].historyScore
        });
    }

    function getBuildingCore(
        uint256 buildingId
    ) external view onlyExisting(buildingId) returns (CityBuildingTypes.BuildingCore memory) {
        return _buildingCore[buildingId];
    }

    function getBuildingMeta(
        uint256 buildingId
    ) external view onlyExisting(buildingId) returns (CityBuildingTypes.BuildingMeta memory) {
        return _buildingMeta[buildingId];
    }

    function getBuildingUsageStats(
        uint256 buildingId
    ) external view onlyExisting(buildingId) returns (CityBuildingTypes.BuildingUsageStats memory) {
        return _buildingUsage[buildingId];
    }

    function getBuildingHistoryCounters(
        uint256 buildingId
    ) external view onlyExisting(buildingId) returns (CityBuildingTypes.BuildingHistoryCounters memory) {
        return _buildingHistory[buildingId];
    }

    function getBuildingState(
        uint256 buildingId
    ) external view onlyExisting(buildingId) returns (CityBuildingTypes.BuildingState) {
        return _buildingState[buildingId];
    }

    function isCreatorTierForge(
        uint256 buildingId
    ) external view onlyExisting(buildingId) returns (bool) {
        return CityBuildingTypes.isCreatorTierForge(_buildingCore[buildingId]);
    }

    function isResearchMaster(
        uint256 buildingId
    ) external view onlyExisting(buildingId) returns (bool) {
        return CityBuildingTypes.isResearchMaster(_buildingCore[buildingId]);
    }

    function getLastUpgradeAt(uint256 buildingId) external view returns (uint64) {
        return lastUpgradeAt[buildingId];
    }

    function getLastTransferredAt(uint256 buildingId) external view returns (uint64) {
        return lastTransferredAt[buildingId];
    }

    function getLastMeaningfulUseAt(uint256 buildingId) external view returns (uint64) {
        return lastMeaningfulUseAt[buildingId];
    }

    /*//////////////////////////////////////////////////////////////
                                METADATA
    //////////////////////////////////////////////////////////////*/

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /*//////////////////////////////////////////////////////////////
                           TRANSFER RESTRICTIONS
    //////////////////////////////////////////////////////////////*/

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address from) {
        from = _ownerOf(tokenId);

        if (from != address(0) && to != address(0)) {
            if (CityBuildingTypes.isPlacedState(_buildingState[tokenId])) revert TransferWhilePlacedBlocked();
            if (preparedForMigration[tokenId]) revert TransferWhilePreparedForMigration();
            if (archivedToV2[tokenId]) revert TransferWhileArchivedBlocked();

            _buildingMeta[tokenId].totalTransfers += 1;
            lastTransferredAt[tokenId] = uint64(block.timestamp);
        }

        return super._update(to, tokenId, auth);
    }

    /*//////////////////////////////////////////////////////////////
                           ERC165 / INTERFACES
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, AccessControl) returns (bool) {
        return
            interfaceId == type(IERC4906).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                               INTERNALS
    //////////////////////////////////////////////////////////////*/

    function _existsCompat(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    function _requireNotPlaced(uint256 buildingId) private view {
        if (CityBuildingTypes.isPlacedState(_buildingState[buildingId])) {
            revert CannotPrepareWhilePlaced();
        }
    }

    function _requireMigrationReady() private view {
        if (migrationTarget == address(0)) revert MigrationTargetNotSet();
        if (!migrationOpen) revert MigrationClosed();
    }

    function _isOwnerOrApprovedCompat(address spender, uint256 tokenId) private view returns (bool) {
        address owner = _ownerOf(tokenId);
        return spender == owner
            || getApproved(tokenId) == spender
            || isApprovedForAll(owner, spender);
    }
}