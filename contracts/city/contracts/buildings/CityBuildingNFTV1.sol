/* FILE: contracts/city/contracts/buildings/CityBuildingNFTV1.sol */
/* TYPE: NFT / ASSET / IDENTITY / PROVENANCE LAYER — NOT PersonalBuildings.sol */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../libraries/CityBuildingTypes.sol";

/*//////////////////////////////////////////////////////////////
                    CITY BUILDING NFT V1
//////////////////////////////////////////////////////////////*/

/// @title CityBuildingNFTV1
/// @notice ERC721 asset layer for Inpinity City buildings.
/// @dev This file is strictly the NFT / identity / provenance / usage / prestige layer.
///      It does NOT perform plot entitlement checks, mint quotes, vault logic,
///      placement validation, function registry logic, or gameplay orchestration.
contract CityBuildingNFTV1 is ERC721, AccessControl, Pausable {
    using CityBuildingTypes for CityBuildingTypes.BuildingUsageStats;

    /*//////////////////////////////////////////////////////////////
                                 ROLES
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant NFT_ADMIN_ROLE = keccak256("NFT_ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant PLACEMENT_ROLE = keccak256("PLACEMENT_ROLE");
    bytes32 public constant METADATA_ROLE = keccak256("METADATA_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error InvalidTokenId();
    error InvalidBuildingType();
    error InvalidBuildingCategory();
    error InvalidLevel();
    error InvalidSpecialization();
    error InvalidVersionTag();
    error InvalidState();
    error InvalidFactionVariant();
    error InvalidNameLength();
    error BuildingArchived();
    error BuildingPreparedForMigration();
    error TransferBlockedWhilePlaced(uint256 buildingId);
    error TransferBlockedWhileMigrationPrepared(uint256 buildingId);
    error NoStateChange();
    error Unauthorized();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event BuildingMinted(
        uint256 indexed buildingId,
        address indexed to,
        CityBuildingTypes.PersonalBuildingType indexed buildingType,
        uint32 versionTag,
        uint64 mintedAt
    );

    event BuildingStateSet(
        uint256 indexed buildingId,
        CityBuildingTypes.BuildingState state,
        address indexed executor,
        uint64 updatedAt
    );

    event BuildingPlacedSet(
        uint256 indexed buildingId,
        bool placed,
        address indexed executor,
        uint64 updatedAt
    );

    event BuildingArchivedSet(
        uint256 indexed buildingId,
        bool archived,
        address indexed executor,
        uint64 updatedAt
    );

    event BuildingMigrationPreparedSet(
        uint256 indexed buildingId,
        bool prepared,
        address indexed executor,
        uint64 updatedAt
    );

    event BuildingUpgraded(
        uint256 indexed buildingId,
        uint8 oldLevel,
        uint8 newLevel,
        address indexed executor,
        uint64 updatedAt
    );

    event BuildingSpecialized(
        uint256 indexed buildingId,
        CityBuildingTypes.BuildingSpecialization oldSpecialization,
        CityBuildingTypes.BuildingSpecialization newSpecialization,
        address indexed executor,
        uint64 updatedAt
    );

    event BuildingFactionVariantSet(
        uint256 indexed buildingId,
        CityBuildingTypes.FactionVariant oldVariant,
        CityBuildingTypes.FactionVariant newVariant,
        address indexed executor
    );

    event BuildingCustomNameSet(
        uint256 indexed buildingId,
        string customName,
        address indexed executor
    );

    event BuildingPrestigeAdded(
        uint256 indexed buildingId,
        uint32 amount,
        uint32 newPrestigeScore,
        address indexed executor
    );

    event BuildingHistoryAdded(
        uint256 indexed buildingId,
        uint32 amount,
        uint32 newHistoryScore,
        address indexed executor
    );

    event BuildingUsageRecorded(
        uint256 indexed buildingId,
        CityBuildingTypes.BuildingUsageType indexed usageType,
        uint32 amount,
        uint32 newTotalUses,
        address indexed executor
    );

    event BuildingImageURISet(
        uint256 indexed buildingId,
        string imageURI,
        address indexed executor
    );

    event BuildingMetadataURISet(
        uint256 indexed buildingId,
        string metadataURI,
        address indexed executor
    );

    event BaseTokenURISet(
        string oldValue,
        string newValue,
        address indexed executor
    );

    event BuildingIdentityExtendedSet(
        uint256 indexed buildingId,
        uint256 dnaSeed,
        uint32 visualVariant,
        address indexed executor
    );

    event BuildingProvenanceCoreSet(
        uint256 indexed buildingId,
        uint8 originFaction,
        uint8 originDistrictKind,
        uint8 resonanceType,
        uint32 founderEra,
        uint32 genesisEra,
        address indexed executor
    );

    event ChronicleEntryRecorded(
        uint256 indexed buildingId,
        uint256 indexed index,
        CityBuildingTypes.ChronicleEventType eventType,
        address indexed actor,
        uint64 timestamp
    );

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 private _nextBuildingId = 1;
    string private _baseTokenUri;

    mapping(uint256 => CityBuildingTypes.BuildingCore) private _buildingCore;
    mapping(uint256 => CityBuildingTypes.BuildingMeta) private _buildingMeta;
    mapping(uint256 => CityBuildingTypes.BuildingState) private _buildingState;
    mapping(uint256 => bool) private _placed;
    mapping(uint256 => bool) private _archived;
    mapping(uint256 => bool) private _migrationPrepared;

    mapping(uint256 => CityBuildingTypes.BuildingUsageStats) private _usageStats;
    mapping(uint256 => CityBuildingTypes.BuildingHistoryCounters) private _historyCounters;
    mapping(uint256 => CityBuildingTypes.ChronicleEntry[]) private _chronicles;

    struct BuildingIdentityExtension {
        uint256 dnaSeed;
        uint32 visualVariant;
        uint8 originFaction;
        uint8 originDistrictKind;
        uint8 resonanceType;
        uint32 founderEra;
        uint32 genesisEra;
        address creator;
        string imageURI;
        string metadataURI;
    }

    mapping(uint256 => BuildingIdentityExtension) private _identityExt;

    /*//////////////////////////////////////////////////////////////
                              READ STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct BuildingIdentityView {
        uint256 buildingId;
        CityBuildingTypes.BuildingCategory category;
        CityBuildingTypes.PersonalBuildingType buildingType;
        uint32 versionTag;
        uint256 dnaSeed;
        uint32 visualVariant;
        string customName;
        uint8 resonanceType;
        uint64 mintedAt;
        address creator;
        address originalMinter;
    }

    struct VisualStateView {
        uint32 visualVariant;
        uint8 level;
        CityBuildingTypes.BuildingSpecialization specialization;
        CityBuildingTypes.FactionVariant factionVariant;
        bool placed;
        bool archived;
        bool migrationPrepared;
        CityBuildingTypes.BuildingState state;
        string imageURI;
        string metadataURI;
    }

    struct ProvenanceCoreView {
        uint8 originFaction;
        uint8 originDistrictKind;
        uint8 resonanceType;
        uint32 founderEra;
        uint32 genesisEra;
        address creator;
        address originalMinter;
        uint64 mintedAt;
        uint32 versionTag;
        uint32 prestigeScore;
        uint32 historyScore;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address admin_,
        string memory baseTokenUri_
    ) ERC721("Inpinity City Buildings", "ICBUILD") {
        if (admin_ == address(0)) revert ZeroAddress();

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(NFT_ADMIN_ROLE, admin_);
        _grantRole(MINTER_ROLE, admin_);
        _grantRole(MANAGER_ROLE, admin_);
        _grantRole(PLACEMENT_ROLE, admin_);
        _grantRole(METADATA_ROLE, admin_);
        _grantRole(PAUSER_ROLE, admin_);

        _baseTokenUri = baseTokenUri_;
    }

    /*//////////////////////////////////////////////////////////////
                                  ADMIN
    //////////////////////////////////////////////////////////////*/

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function setBaseTokenURI(
        string calldata newBaseTokenUri
    ) external onlyRole(METADATA_ROLE) {
        string memory oldValue = _baseTokenUri;
        _baseTokenUri = newBaseTokenUri;
        emit BaseTokenURISet(oldValue, newBaseTokenUri, msg.sender);
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

        uint32 effectiveVersionTag = versionTag == 0
            ? CityBuildingTypes.VERSION_TAG_V1
            : versionTag;

        if (
            effectiveVersionTag != CityBuildingTypes.VERSION_TAG_V1 &&
            effectiveVersionTag != CityBuildingTypes.VERSION_TAG_V2
        ) revert InvalidVersionTag();

        buildingId = _nextBuildingId++;
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
            versionTag: effectiveVersionTag,
            totalUses: 0,
            totalTransfers: 0,
            totalUpgrades: 0,
            prestigeScore: 0,
            historyScore: 0
        });

        _buildingState[buildingId] = CityBuildingTypes.BuildingState.Unplaced;
        _placed[buildingId] = false;
        _archived[buildingId] = false;
        _migrationPrepared[buildingId] = false;

        _identityExt[buildingId].creator = msg.sender;
        _identityExt[buildingId].dnaSeed = _deriveDnaSeed(buildingId, to, buildingType);
        _identityExt[buildingId].visualVariant = _deriveVisualVariant(buildingId, buildingType);

        _pushChronicle(
            buildingId,
            CityBuildingTypes.ChronicleEventType.Mint,
            1,
            uint32(uint8(buildingType)),
            msg.sender,
            bytes32(0)
        );

        emit BuildingMinted(
            buildingId,
            to,
            buildingType,
            effectiveVersionTag,
            uint64(block.timestamp)
        );
    }

    /*//////////////////////////////////////////////////////////////
                                  READS
    //////////////////////////////////////////////////////////////*/

    function getBuildingCore(
        uint256 buildingId
    ) external view returns (CityBuildingTypes.BuildingCore memory) {
        _requireMintedBuilding(buildingId);
        return _buildingCore[buildingId];
    }

    function getBuildingMeta(
        uint256 buildingId
    ) external view returns (CityBuildingTypes.BuildingMeta memory) {
        _requireMintedBuilding(buildingId);
        return _buildingMeta[buildingId];
    }

    function getBuildingState(
        uint256 buildingId
    ) external view returns (CityBuildingTypes.BuildingState) {
        _requireMintedBuilding(buildingId);
        return _buildingState[buildingId];
    }

    function isArchived(uint256 buildingId) external view returns (bool) {
        _requireMintedBuilding(buildingId);
        return _archived[buildingId];
    }

    function isMigrationPrepared(uint256 buildingId) external view returns (bool) {
        _requireMintedBuilding(buildingId);
        return _migrationPrepared[buildingId];
    }

    function isPlaced(uint256 buildingId) external view returns (bool) {
        _requireMintedBuilding(buildingId);
        return _placed[buildingId];
    }

    function getBuildingIdentity(
        uint256 buildingId
    ) external view returns (BuildingIdentityView memory v) {
        _requireMintedBuilding(buildingId);

        CityBuildingTypes.BuildingCore memory core = _buildingCore[buildingId];
        CityBuildingTypes.BuildingMeta memory meta = _buildingMeta[buildingId];
        BuildingIdentityExtension memory ext = _identityExt[buildingId];

        v = BuildingIdentityView({
            buildingId: buildingId,
            category: core.category,
            buildingType: core.buildingType,
            versionTag: meta.versionTag,
            dnaSeed: ext.dnaSeed,
            visualVariant: ext.visualVariant,
            customName: meta.customName,
            resonanceType: ext.resonanceType,
            mintedAt: core.mintedAt,
            creator: ext.creator,
            originalMinter: core.firstOwner
        });
    }

    function getVisualState(
        uint256 buildingId
    ) external view returns (VisualStateView memory v) {
        _requireMintedBuilding(buildingId);

        CityBuildingTypes.BuildingCore memory core = _buildingCore[buildingId];
        BuildingIdentityExtension memory ext = _identityExt[buildingId];

        v = VisualStateView({
            visualVariant: ext.visualVariant,
            level: core.level,
            specialization: core.specialization,
            factionVariant: core.factionVariant,
            placed: _placed[buildingId],
            archived: _archived[buildingId],
            migrationPrepared: _migrationPrepared[buildingId],
            state: _buildingState[buildingId],
            imageURI: ext.imageURI,
            metadataURI: ext.metadataURI
        });
    }

    function getProvenanceCore(
        uint256 buildingId
    ) external view returns (ProvenanceCoreView memory v) {
        _requireMintedBuilding(buildingId);

        CityBuildingTypes.BuildingCore memory core = _buildingCore[buildingId];
        CityBuildingTypes.BuildingMeta memory meta = _buildingMeta[buildingId];
        BuildingIdentityExtension memory ext = _identityExt[buildingId];

        v = ProvenanceCoreView({
            originFaction: ext.originFaction,
            originDistrictKind: ext.originDistrictKind,
            resonanceType: ext.resonanceType,
            founderEra: ext.founderEra,
            genesisEra: ext.genesisEra,
            creator: ext.creator,
            originalMinter: core.firstOwner,
            mintedAt: core.mintedAt,
            versionTag: meta.versionTag,
            prestigeScore: meta.prestigeScore,
            historyScore: meta.historyScore
        });
    }

    function getBuildingUsageStats(
        uint256 buildingId
    ) external view returns (CityBuildingTypes.BuildingUsageStats memory) {
        _requireMintedBuilding(buildingId);
        return _usageStats[buildingId];
    }

    function getBuildingHistoryCounters(
        uint256 buildingId
    ) external view returns (CityBuildingTypes.BuildingHistoryCounters memory) {
        _requireMintedBuilding(buildingId);
        return _historyCounters[buildingId];
    }

    function getChronicleCount(uint256 buildingId) external view returns (uint256) {
        _requireMintedBuilding(buildingId);
        return _chronicles[buildingId].length;
    }

    function getChronicleEntry(
        uint256 buildingId,
        uint256 index
    ) external view returns (CityBuildingTypes.ChronicleEntry memory) {
        _requireMintedBuilding(buildingId);
        return _chronicles[buildingId][index];
    }

    function getImageURI(uint256 buildingId) external view returns (string memory) {
        _requireMintedBuilding(buildingId);
        return _identityExt[buildingId].imageURI;
    }

    function getMetadataURI(uint256 buildingId) external view returns (string memory) {
        _requireMintedBuilding(buildingId);
        return _identityExt[buildingId].metadataURI;
    }

    function tokenURI(uint256 buildingId) public view override returns (string memory) {
        _requireMintedBuilding(buildingId);

        string memory explicitMetadataUri = _identityExt[buildingId].metadataURI;
        if (bytes(explicitMetadataUri).length > 0) {
            return explicitMetadataUri;
        }

        if (bytes(_baseTokenUri).length == 0) {
            return "";
        }

        return string(
            abi.encodePacked(_baseTokenUri, Strings.toString(buildingId), ".json")
        );
    }

    /*//////////////////////////////////////////////////////////////
                            STATE MUTATIONS
    //////////////////////////////////////////////////////////////*/

    function setPlaced(
        uint256 buildingId,
        bool placed_
    ) external onlyRole(PLACEMENT_ROLE) whenNotPaused {
        _requireMutableBuilding(buildingId);

        if (_placed[buildingId] == placed_) revert NoStateChange();

        _placed[buildingId] = placed_;
        _buildingState[buildingId] = placed_
            ? CityBuildingTypes.BuildingState.PlacedActive
            : CityBuildingTypes.BuildingState.Unplaced;

        _pushChronicle(
            buildingId,
            placed_
                ? CityBuildingTypes.ChronicleEventType.Place
                : CityBuildingTypes.ChronicleEventType.Unplace,
            placed_ ? 1 : 0,
            0,
            msg.sender,
            bytes32(0)
        );

        emit BuildingPlacedSet(
            buildingId,
            placed_,
            msg.sender,
            uint64(block.timestamp)
        );

        emit BuildingStateSet(
            buildingId,
            _buildingState[buildingId],
            msg.sender,
            uint64(block.timestamp)
        );
    }

    function setArchived(
        uint256 buildingId,
        bool archived_
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        _requireMintedBuilding(buildingId);
        if (_archived[buildingId] == archived_) revert NoStateChange();

        _archived[buildingId] = archived_;
        _buildingState[buildingId] = archived_
            ? CityBuildingTypes.BuildingState.Archived
            : (_placed[buildingId]
                ? CityBuildingTypes.BuildingState.PlacedActive
                : CityBuildingTypes.BuildingState.Unplaced);

        if (archived_) {
            _historyCounters[buildingId].migrations += 1;
            _pushChronicle(
                buildingId,
                CityBuildingTypes.ChronicleEventType.ArchiveMigration,
                1,
                0,
                msg.sender,
                bytes32(0)
            );
        }

        emit BuildingArchivedSet(
            buildingId,
            archived_,
            msg.sender,
            uint64(block.timestamp)
        );

        emit BuildingStateSet(
            buildingId,
            _buildingState[buildingId],
            msg.sender,
            uint64(block.timestamp)
        );
    }

    function setMigrationPrepared(
        uint256 buildingId,
        bool prepared
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        _requireMintedBuilding(buildingId);
        if (_migrationPrepared[buildingId] == prepared) revert NoStateChange();

        _migrationPrepared[buildingId] = prepared;
        if (prepared) {
            _historyCounters[buildingId].migrations += 1;
        }

        emit BuildingMigrationPreparedSet(
            buildingId,
            prepared,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    function upgradeBuilding(
        uint256 buildingId,
        uint8 newLevel
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        _requireMutableBuilding(buildingId);
        if (!CityBuildingTypes.isValidLevel(newLevel)) revert InvalidLevel();

        CityBuildingTypes.BuildingCore storage core = _buildingCore[buildingId];
        if (core.category != CityBuildingTypes.BuildingCategory.Personal) {
            revert InvalidBuildingCategory();
        }
        if (newLevel <= core.level) revert NoStateChange();

        uint8 oldLevel = core.level;
        core.level = newLevel;
        _buildingMeta[buildingId].totalUpgrades += 1;

        _pushChronicle(
            buildingId,
            CityBuildingTypes.ChronicleEventType.Upgrade,
            oldLevel,
            newLevel,
            msg.sender,
            bytes32(0)
        );

        emit BuildingUpgraded(
            buildingId,
            oldLevel,
            newLevel,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    function specializeBuilding(
        uint256 buildingId,
        CityBuildingTypes.BuildingSpecialization newSpecialization
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        _requireMutableBuilding(buildingId);

        CityBuildingTypes.BuildingCore storage core = _buildingCore[buildingId];

        if (core.category != CityBuildingTypes.BuildingCategory.Personal) {
            revert InvalidBuildingCategory();
        }

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
        _historyCounters[buildingId].specializationChanges += 1;

        _pushChronicle(
            buildingId,
            CityBuildingTypes.ChronicleEventType.Specialize,
            uint32(uint8(oldSpecialization)),
            uint32(uint8(newSpecialization)),
            msg.sender,
            bytes32(0)
        );

        emit BuildingSpecialized(
            buildingId,
            oldSpecialization,
            newSpecialization,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    function setFactionVariant(
        uint256 buildingId,
        CityBuildingTypes.FactionVariant factionVariant
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        _requireMutableBuilding(buildingId);

        CityBuildingTypes.BuildingCore storage core = _buildingCore[buildingId];

        if (!CityBuildingTypes.canHaveFactionVariant(core.buildingType)) {
            revert InvalidFactionVariant();
        }

        CityBuildingTypes.FactionVariant oldVariant = core.factionVariant;
        if (oldVariant == factionVariant) revert NoStateChange();

        core.factionVariant = factionVariant;

        _pushChronicle(
            buildingId,
            CityBuildingTypes.ChronicleEventType.FactionVariantSet,
            uint32(uint8(oldVariant)),
            uint32(uint8(factionVariant)),
            msg.sender,
            bytes32(0)
        );

        emit BuildingFactionVariantSet(
            buildingId,
            oldVariant,
            factionVariant,
            msg.sender
        );
    }

    function setCustomName(
        uint256 buildingId,
        string calldata customName
    ) external whenNotPaused {
        _requireMintedBuilding(buildingId);
        _requireOwnerOrManager(buildingId);

        CityBuildingTypes.BuildingCore memory core = _buildingCore[buildingId];
        if (!CityBuildingTypes.supportsCustomName(core.buildingType)) {
            revert InvalidBuildingType();
        }
        if (!CityBuildingTypes.isNameLengthValid(customName)) {
            revert InvalidNameLength();
        }

        _buildingMeta[buildingId].customName = customName;

        emit BuildingCustomNameSet(buildingId, customName, msg.sender);
    }

    function addPrestigeScore(
        uint256 buildingId,
        uint32 amount
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        _requireMintedBuilding(buildingId);

        CityBuildingTypes.BuildingMeta storage meta = _buildingMeta[buildingId];
        meta.prestigeScore += amount;

        emit BuildingPrestigeAdded(
            buildingId,
            amount,
            meta.prestigeScore,
            msg.sender
        );
    }

    function addHistoryScore(
        uint256 buildingId,
        uint32 amount
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        _requireMintedBuilding(buildingId);

        CityBuildingTypes.BuildingMeta storage meta = _buildingMeta[buildingId];
        meta.historyScore += amount;

        emit BuildingHistoryAdded(
            buildingId,
            amount,
            meta.historyScore,
            msg.sender
        );
    }

    function recordUsage(
        uint256 buildingId,
        CityBuildingTypes.BuildingUsageType usageType,
        uint32 amount
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        _requireMintedBuilding(buildingId);

        CityBuildingTypes.BuildingMeta storage meta = _buildingMeta[buildingId];
        meta.totalUses += amount;
        _usageStats[buildingId].incrementUsage(usageType, amount);

        emit BuildingUsageRecorded(
            buildingId,
            usageType,
            amount,
            meta.totalUses,
            msg.sender
        );
    }

    /*//////////////////////////////////////////////////////////////
                      IDENTITY / VISUAL / PROVENANCE SETTERS
    //////////////////////////////////////////////////////////////*/

    function setIdentityExtension(
        uint256 buildingId,
        uint256 dnaSeed,
        uint32 visualVariant
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        _requireMintedBuilding(buildingId);

        _identityExt[buildingId].dnaSeed = dnaSeed;
        _identityExt[buildingId].visualVariant = visualVariant;

        emit BuildingIdentityExtendedSet(
            buildingId,
            dnaSeed,
            visualVariant,
            msg.sender
        );
    }

    function setProvenanceCore(
        uint256 buildingId,
        uint8 originFaction,
        uint8 originDistrictKind,
        uint8 resonanceType,
        uint32 founderEra,
        uint32 genesisEra
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        _requireMintedBuilding(buildingId);

        BuildingIdentityExtension storage ext = _identityExt[buildingId];
        ext.originFaction = originFaction;
        ext.originDistrictKind = originDistrictKind;
        ext.resonanceType = resonanceType;
        ext.founderEra = founderEra;
        ext.genesisEra = genesisEra;

        emit BuildingProvenanceCoreSet(
            buildingId,
            originFaction,
            originDistrictKind,
            resonanceType,
            founderEra,
            genesisEra,
            msg.sender
        );
    }

    function setVersionTag(
        uint256 buildingId,
        uint32 versionTag
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        _requireMintedBuilding(buildingId);
        if (
            versionTag != CityBuildingTypes.VERSION_TAG_V1 &&
            versionTag != CityBuildingTypes.VERSION_TAG_V2
        ) revert InvalidVersionTag();

        _buildingMeta[buildingId].versionTag = versionTag;
    }

    function setImageURI(
        uint256 buildingId,
        string calldata imageURI
    ) external onlyRole(METADATA_ROLE) whenNotPaused {
        _requireMintedBuilding(buildingId);
        _identityExt[buildingId].imageURI = imageURI;

        emit BuildingImageURISet(buildingId, imageURI, msg.sender);
    }

    function setMetadataURI(
        uint256 buildingId,
        string calldata metadataURI
    ) external onlyRole(METADATA_ROLE) whenNotPaused {
        _requireMintedBuilding(buildingId);
        _identityExt[buildingId].metadataURI = metadataURI;

        emit BuildingMetadataURISet(buildingId, metadataURI, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                            CHRONICLE HELPERS
    //////////////////////////////////////////////////////////////*/

    function recordChronicleEntry(
        uint256 buildingId,
        CityBuildingTypes.ChronicleEventType eventType,
        uint32 eventData1,
        uint32 eventData2,
        address actor,
        bytes32 extraData
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        _requireMintedBuilding(buildingId);
        _pushChronicle(
            buildingId,
            eventType,
            eventData1,
            eventData2,
            actor,
            extraData
        );
    }

    /*//////////////////////////////////////////////////////////////
                           TRANSFER RESTRICTIONS
    //////////////////////////////////////////////////////////////*/

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override whenNotPaused returns (address from) {
        from = _ownerOf(tokenId);

        if (from != address(0) && to != address(0)) {
            if (_placed[tokenId]) revert TransferBlockedWhilePlaced(tokenId);
            if (_migrationPrepared[tokenId]) {
                revert TransferBlockedWhileMigrationPrepared(tokenId);
            }

            _buildingMeta[tokenId].totalTransfers += 1;

            _pushChronicle(
                tokenId,
                CityBuildingTypes.ChronicleEventType.Transfer,
                0,
                0,
                msg.sender,
                bytes32(uint256(uint160(to)))
            );
        }

        return super._update(to, tokenId, auth);
    }

    /*//////////////////////////////////////////////////////////////
                               INTERNALS
    //////////////////////////////////////////////////////////////*/

    function _requireMintedBuilding(uint256 buildingId) internal view {
        if (_ownerOf(buildingId) == address(0)) revert InvalidTokenId();
    }

    function _requireMutableBuilding(uint256 buildingId) internal view {
        _requireMintedBuilding(buildingId);
        if (_archived[buildingId]) revert BuildingArchived();
        if (_migrationPrepared[buildingId]) revert BuildingPreparedForMigration();
    }

    function _requireOwnerOrManager(uint256 buildingId) internal view {
        if (
            msg.sender != ownerOf(buildingId) &&
            !hasRole(MANAGER_ROLE, msg.sender)
        ) revert Unauthorized();
    }

    function _deriveDnaSeed(
        uint256 buildingId,
        address to,
        CityBuildingTypes.PersonalBuildingType buildingType
    ) internal view returns (uint256) {
        return uint256(
            keccak256(
                abi.encodePacked(
                    "INPINITY_CITY_BUILDING_DNA",
                    block.chainid,
                    address(this),
                    buildingId,
                    to,
                    uint8(buildingType),
                    block.timestamp
                )
            )
        );
    }

    function _deriveVisualVariant(
        uint256 buildingId,
        CityBuildingTypes.PersonalBuildingType buildingType
    ) internal view returns (uint32) {
        return uint32(
            uint256(
                keccak256(
                    abi.encodePacked(
                        "INPINITY_CITY_BUILDING_VISUAL",
                        address(this),
                        buildingId,
                        uint8(buildingType),
                        block.prevrandao,
                        block.timestamp
                    )
                )
            ) % type(uint32).max
        );
    }

    function _pushChronicle(
        uint256 buildingId,
        CityBuildingTypes.ChronicleEventType eventType,
        uint32 eventData1,
        uint32 eventData2,
        address actor,
        bytes32 extraData
    ) internal {
        _chronicles[buildingId].push(
            CityBuildingTypes.ChronicleEntry({
                eventType: eventType,
                eventData1: eventData1,
                eventData2: eventData2,
                actor: actor,
                timestamp: uint64(block.timestamp),
                extraData: extraData
            })
        );

        emit ChronicleEntryRecorded(
            buildingId,
            _chronicles[buildingId].length - 1,
            eventType,
            actor,
            uint64(block.timestamp)
        );
    }

    /*//////////////////////////////////////////////////////////////
                           INTERFACE SUPPORT
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}