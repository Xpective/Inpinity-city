/* FILE: contracts/city/contracts/buildings/CityBuildingNFTV1.sol */
/* TYPE: NFT / ASSET / IDENTITY / PROVENANCE LAYER — NOT PersonalBuildings.sol */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
    IMPORTANT:
    - This file is the NFT / asset layer for Personal Buildings V1.
    - This file is NOT the gameplay orchestrator.
    - This file is NOT PlacementPolicy.
    - This file is NOT FunctionRegistry.
    - This file is NOT Vault logic.
    - This file is NOT mint-through-owned-plot logic.
*/

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../libraries/CityBuildingTypes.sol";

contract CityBuildingNFTV1 is ERC721, AccessControl, Pausable {
    /*//////////////////////////////////////////////////////////////
                         FILE ROLE / RESPONSIBILITY
    //////////////////////////////////////////////////////////////*/
    /* TYPE: NFT / ASSET LAYER
       Responsibility:
       - tradable building asset IDs
       - identity / visual / provenance core
       - core/meta/state reads
       - usage / prestige / history counters
       - placed / archived / migrationPrepared flags
       - upgrade + specialization state mutation
       - future URI/image extensibility
       - transfer blocking while placed
    */

    /*//////////////////////////////////////////////////////////////
                                 ROLES
    //////////////////////////////////////////////////////////////*/
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BUILDING_MANAGER_ROLE = keccak256("BUILDING_MANAGER_ROLE");
    bytes32 public constant PLACEMENT_ROLE = keccak256("PLACEMENT_ROLE");
    bytes32 public constant METADATA_ROLE = keccak256("METADATA_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error ZeroAddress();
    error InvalidBuildingType();
    error InvalidLevel();
    error InvalidSpecialization();
    error InvalidVersionTag();
    error InvalidState();
    error InvalidNameLength();
    error InvalidTokenId();
    error AlreadyPlaced();
    error NotPlaced();
    error BuildingArchived();
    error BuildingPreparedForMigration();
    error TransferBlockedWhilePlaced(uint256 buildingId);
    error NoStateChange();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint32 public constant DEFAULT_VERSION_TAG = CityBuildingTypes.VERSION_TAG_V1;
    uint256 public constant MAX_CUSTOM_NAME_LENGTH = 64;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    /* TYPE: NFT / ASSET EVENTS */
    event BuildingMinted(
        uint256 indexed buildingId,
        address indexed to,
        CityBuildingTypes.PersonalBuildingType indexed buildingType,
        uint32 versionTag,
        uint64 mintedAt
    );

    event BuildingPlacedStateSet(
        uint256 indexed buildingId,
        bool placed,
        address indexed executor,
        uint64 updatedAt
    );

    event BuildingArchivedStateSet(
        uint256 indexed buildingId,
        bool archived,
        address indexed executor,
        uint64 updatedAt
    );

    event BuildingMigrationPreparedStateSet(
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

    event BuildingCustomNameSet(
        uint256 indexed buildingId,
        string customName,
        address indexed executor
    );

    event BuildingPrestigeUpdated(
        uint256 indexed buildingId,
        uint32 oldValue,
        uint32 newValue,
        address indexed executor
    );

    event BuildingHistoryUpdated(
        uint256 indexed buildingId,
        uint32 oldValue,
        uint32 newValue,
        address indexed executor
    );

    event BuildingUsageRecorded(
        uint256 indexed buildingId,
        CityBuildingTypes.BuildingUsageType indexed usageType,
        uint32 amount,
        uint32 newTypeTotal,
        uint32 newGlobalTotal,
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

    /*//////////////////////////////////////////////////////////////
                            INTERNAL STORAGE
    //////////////////////////////////////////////////////////////*/
    /* TYPE: internal NFT storage — NOT gameplay orchestration */

    struct BuildingCoreData {
        CityBuildingTypes.BuildingCategory category;
        CityBuildingTypes.PersonalBuildingType buildingType;
        uint8 level;
        CityBuildingTypes.BuildingSpecialization specialization;
    }

    struct BuildingMetaData {
        string customName;
        uint32 versionTag;
        uint32 totalUses;
        uint32 totalTransfers;
        uint32 totalUpgrades;
        uint32 prestigeScore;
        uint32 historyScore;
    }

    struct BuildingStateData {
        CityBuildingTypes.BuildingState state;
        bool placed;
        bool archived;
        bool migrationPrepared;
    }

    struct BuildingIdentityData {
        uint256 dnaSeed;
        uint32 visualVariant;
        uint8 originFaction;
        uint8 originDistrictKind;
        uint8 resonanceType;
        uint32 founderEra;
        uint32 genesisEra;
        uint64 mintedAt;
        address creator;
        address originalMinter;
    }

    struct BuildingUriData {
        string imageURI;
        string metadataURI;
    }

    mapping(uint256 => BuildingCoreData) private _buildingCore;
    mapping(uint256 => BuildingMetaData) private _buildingMeta;
    mapping(uint256 => BuildingStateData) private _buildingStateData;
    mapping(uint256 => BuildingIdentityData) private _buildingIdentity;
    mapping(uint256 => BuildingUriData) private _buildingUris;
    mapping(uint256 => mapping(uint8 => uint32)) private _usageByType;

    uint256 private _nextBuildingId = 1;
    string private _baseTokenUri;

    /*//////////////////////////////////////////////////////////////
                             EXTERNAL READ STRUCTS
    //////////////////////////////////////////////////////////////*/
    /* TYPE: frontend / adapter / migration-friendly read models */

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
    /* TYPE: NFT / ASSET CONSTRUCTOR */
    constructor(
        address admin_,
        string memory baseTokenUri_
    ) ERC721("Inpinity City Building", "ICBUILD") {
        if (admin_ == address(0)) revert ZeroAddress();

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(MINTER_ROLE, admin_);
        _grantRole(BUILDING_MANAGER_ROLE, admin_);
        _grantRole(PLACEMENT_ROLE, admin_);
        _grantRole(METADATA_ROLE, admin_);
        _grantRole(PAUSER_ROLE, admin_);

        _baseTokenUri = baseTokenUri_;
    }

    /*//////////////////////////////////////////////////////////////
                               PAUSE CONTROL
    //////////////////////////////////////////////////////////////*/
    /* TYPE: NFT / ASSET CONTROL */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                                  MINT
    //////////////////////////////////////////////////////////////*/
    /* TYPE: NFT minting only — NOT plot entitlement logic */
    function mintBuilding(
        address to,
        CityBuildingTypes.PersonalBuildingType buildingType,
        uint32 versionTag
    ) external onlyRole(MINTER_ROLE) whenNotPaused returns (uint256 buildingId) {
        if (to == address(0)) revert ZeroAddress();
        if (!CityBuildingTypes.isValidBaseType(buildingType)) revert InvalidBuildingType();

        uint32 effectiveVersionTag = versionTag == 0 ? DEFAULT_VERSION_TAG : versionTag;
        if (effectiveVersionTag == 0) revert InvalidVersionTag();

        buildingId = _nextBuildingId++;
        _safeMint(to, buildingId);

        _buildingCore[buildingId] = BuildingCoreData({
            category: CityBuildingTypes.BuildingCategory.Personal,
            buildingType: buildingType,
            level: 1,
            specialization: CityBuildingTypes.BuildingSpecialization.None
        });

        _buildingMeta[buildingId] = BuildingMetaData({
            customName: "",
            versionTag: effectiveVersionTag,
            totalUses: 0,
            totalTransfers: 0,
            totalUpgrades: 0,
            prestigeScore: 0,
            historyScore: 0
        });

        _buildingStateData[buildingId] = BuildingStateData({
            state: CityBuildingTypes.BuildingState.Unplaced,
            placed: false,
            archived: false,
            migrationPrepared: false
        });

        _buildingIdentity[buildingId] = BuildingIdentityData({
            dnaSeed: _deriveDnaSeed(buildingId, to, buildingType),
            visualVariant: _deriveVisualVariant(buildingId, buildingType),
            originFaction: 0,
            originDistrictKind: 0,
            resonanceType: 0,
            founderEra: 0,
            genesisEra: 0,
            mintedAt: uint64(block.timestamp),
            creator: msg.sender,
            originalMinter: to
        });

        emit BuildingMinted(
            buildingId,
            to,
            buildingType,
            effectiveVersionTag,
            uint64(block.timestamp)
        );
    }

    /*//////////////////////////////////////////////////////////////
                          CORE / META / STATE READS
    //////////////////////////////////////////////////////////////*/
    /* TYPE: NFT canonical reads */

    function getBuildingCore(
        uint256 buildingId
    ) external view returns (CityBuildingTypes.BuildingCore memory core) {
        _requireMintedBuilding(buildingId);

        BuildingCoreData memory d = _buildingCore[buildingId];
        BuildingIdentityData memory i = _buildingIdentity[buildingId];
        BuildingStateData memory s = _buildingStateData[buildingId];

        /*
            ASSUMPTION:
            This constructor shape assumes CityBuildingTypes.BuildingCore contains
            at least the fields used elsewhere in the project:
            category, buildingType, level, specialization, mintedAt, firstOwner, placed.
            If CityBuildingTypes.BuildingCore in the repo contains extra fields,
            align this return mapping to the actual library definition.
        */
        core = CityBuildingTypes.BuildingCore({
            category: d.category,
            buildingType: d.buildingType,
            level: d.level,
            specialization: d.specialization,
            mintedAt: i.mintedAt,
            firstOwner: i.originalMinter,
            placed: s.placed
        });
    }

    function getBuildingMeta(
        uint256 buildingId
    ) external view returns (CityBuildingTypes.BuildingMeta memory meta) {
        _requireMintedBuilding(buildingId);

        BuildingMetaData memory d = _buildingMeta[buildingId];

        /*
            ASSUMPTION:
            This constructor shape assumes CityBuildingTypes.BuildingMeta contains
            the fields used by the project notes:
            customName, versionTag, totalUses, totalTransfers,
            totalUpgrades, prestigeScore, historyScore.
        */
        meta = CityBuildingTypes.BuildingMeta({
            customName: d.customName,
            versionTag: d.versionTag,
            totalUses: d.totalUses,
            totalTransfers: d.totalTransfers,
            totalUpgrades: d.totalUpgrades,
            prestigeScore: d.prestigeScore,
            historyScore: d.historyScore
        });
    }

    function getBuildingState(
        uint256 buildingId
    ) external view returns (CityBuildingTypes.BuildingState) {
        _requireMintedBuilding(buildingId);
        return _buildingStateData[buildingId].state;
    }

    function isArchived(uint256 buildingId) external view returns (bool) {
        _requireMintedBuilding(buildingId);
        return _buildingStateData[buildingId].archived;
    }

    function isMigrationPrepared(uint256 buildingId) external view returns (bool) {
        _requireMintedBuilding(buildingId);
        return _buildingStateData[buildingId].migrationPrepared;
    }

    /*//////////////////////////////////////////////////////////////
                        NEW IDENTITY / VISUAL / PROVENANCE READS
    //////////////////////////////////////////////////////////////*/
    /* TYPE: stable read layer for frontend / placement / V2 migration */

    function getBuildingIdentity(
        uint256 buildingId
    ) external view returns (BuildingIdentityView memory view_) {
        _requireMintedBuilding(buildingId);

        BuildingCoreData memory c = _buildingCore[buildingId];
        BuildingMetaData memory m = _buildingMeta[buildingId];
        BuildingIdentityData memory i = _buildingIdentity[buildingId];

        view_ = BuildingIdentityView({
            buildingId: buildingId,
            category: c.category,
            buildingType: c.buildingType,
            versionTag: m.versionTag,
            dnaSeed: i.dnaSeed,
            visualVariant: i.visualVariant,
            customName: m.customName,
            resonanceType: i.resonanceType,
            mintedAt: i.mintedAt,
            creator: i.creator,
            originalMinter: i.originalMinter
        });
    }

    function getVisualState(
        uint256 buildingId
    ) external view returns (VisualStateView memory view_) {
        _requireMintedBuilding(buildingId);

        BuildingCoreData memory c = _buildingCore[buildingId];
        BuildingStateData memory s = _buildingStateData[buildingId];
        BuildingIdentityData memory i = _buildingIdentity[buildingId];
        BuildingUriData memory u = _buildingUris[buildingId];

        view_ = VisualStateView({
            visualVariant: i.visualVariant,
            level: c.level,
            specialization: c.specialization,
            placed: s.placed,
            archived: s.archived,
            migrationPrepared: s.migrationPrepared,
            state: s.state,
            imageURI: u.imageURI,
            metadataURI: u.metadataURI
        });
    }

    function getProvenanceCore(
        uint256 buildingId
    ) external view returns (ProvenanceCoreView memory view_) {
        _requireMintedBuilding(buildingId);

        BuildingIdentityData memory i = _buildingIdentity[buildingId];
        BuildingMetaData memory m = _buildingMeta[buildingId];

        view_ = ProvenanceCoreView({
            originFaction: i.originFaction,
            originDistrictKind: i.originDistrictKind,
            founderEra: i.founderEra,
            genesisEra: i.genesisEra,
            creator: i.creator,
            originalMinter: i.originalMinter,
            mintedAt: i.mintedAt,
            versionTag: m.versionTag,
            prestigeScore: m.prestigeScore,
            historyScore: m.historyScore
        });
    }

    /*//////////////////////////////////////////////////////////////
                              STATE MUTATIONS
    //////////////////////////////////////////////////////////////*/
    /* TYPE: asset-state mutation — NOT gameplay orchestration */

    function setPlaced(
        uint256 buildingId,
        bool placed
    ) external onlyRole(PLACEMENT_ROLE) whenNotPaused {
        _requireMutableBuilding(buildingId);

        BuildingStateData storage s = _buildingStateData[buildingId];
        if (s.placed == placed) revert NoStateChange();

        s.placed = placed;
        s.state = placed
            ? CityBuildingTypes.BuildingState.PlacedActive
            : CityBuildingTypes.BuildingState.Unplaced;

        emit BuildingPlacedStateSet(
            buildingId,
            placed,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    function upgradeBuilding(
        uint256 buildingId,
        uint8 newLevel
    ) external onlyRole(BUILDING_MANAGER_ROLE) whenNotPaused {
        _requireMutableBuilding(buildingId);
        if (!CityBuildingTypes.isValidLevel(newLevel)) revert InvalidLevel();

        BuildingCoreData storage c = _buildingCore[buildingId];
        uint8 oldLevel = c.level;

        if (newLevel <= oldLevel) revert NoStateChange();

        c.level = newLevel;
        _buildingMeta[buildingId].totalUpgrades += 1;

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
    ) external onlyRole(BUILDING_MANAGER_ROLE) whenNotPaused {
        _requireMutableBuilding(buildingId);
        if (newSpecialization == CityBuildingTypes.BuildingSpecialization.None) {
            revert InvalidSpecialization();
        }

        BuildingCoreData storage c = _buildingCore[buildingId];
        CityBuildingTypes.BuildingSpecialization oldSpecialization = c.specialization;
        if (oldSpecialization == newSpecialization) revert NoStateChange();

        c.specialization = newSpecialization;

        emit BuildingSpecialized(
            buildingId,
            oldSpecialization,
            newSpecialization,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    function setArchived(
        uint256 buildingId,
        bool archived
    ) external onlyRole(BUILDING_MANAGER_ROLE) whenNotPaused {
        _requireMintedBuilding(buildingId);

        BuildingStateData storage s = _buildingStateData[buildingId];
        if (s.archived == archived) revert NoStateChange();

        s.archived = archived;
        s.state = archived
            ? CityBuildingTypes.BuildingState.Archived
            : (s.placed ? CityBuildingTypes.BuildingState.PlacedActive : CityBuildingTypes.BuildingState.Unplaced);

        emit BuildingArchivedStateSet(
            buildingId,
            archived,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    function setMigrationPrepared(
        uint256 buildingId,
        bool prepared
    ) external onlyRole(BUILDING_MANAGER_ROLE) whenNotPaused {
        _requireMintedBuilding(buildingId);

        BuildingStateData storage s = _buildingStateData[buildingId];
        if (s.migrationPrepared == prepared) revert NoStateChange();

        s.migrationPrepared = prepared;

        emit BuildingMigrationPreparedStateSet(
            buildingId,
            prepared,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    function setBuildingCustomName(
        uint256 buildingId,
        string calldata customName
    ) external whenNotPaused {
        _requireMintedBuilding(buildingId);
        _requireOwnerOrManager(buildingId);

        if (bytes(customName).length > MAX_CUSTOM_NAME_LENGTH) revert InvalidNameLength();

        _buildingMeta[buildingId].customName = customName;
        emit BuildingCustomNameSet(buildingId, customName, msg.sender);
    }

    function addPrestigeScore(
        uint256 buildingId,
        uint32 amount
    ) external onlyRole(BUILDING_MANAGER_ROLE) whenNotPaused {
        _requireMintedBuilding(buildingId);

        BuildingMetaData storage m = _buildingMeta[buildingId];
        uint32 oldValue = m.prestigeScore;
        uint32 newValue = oldValue + amount;
        m.prestigeScore = newValue;

        emit BuildingPrestigeUpdated(buildingId, oldValue, newValue, msg.sender);
    }

    function addHistoryScore(
        uint256 buildingId,
        uint32 amount
    ) external onlyRole(BUILDING_MANAGER_ROLE) whenNotPaused {
        _requireMintedBuilding(buildingId);

        BuildingMetaData storage m = _buildingMeta[buildingId];
        uint32 oldValue = m.historyScore;
        uint32 newValue = oldValue + amount;
        m.historyScore = newValue;

        emit BuildingHistoryUpdated(buildingId, oldValue, newValue, msg.sender);
    }

    function recordUsage(
        uint256 buildingId,
        CityBuildingTypes.BuildingUsageType usageType,
        uint32 amount
    ) external onlyRole(BUILDING_MANAGER_ROLE) whenNotPaused {
        _requireMintedBuilding(buildingId);

        uint8 usageKey = uint8(usageType);

        BuildingMetaData storage m = _buildingMeta[buildingId];
        m.totalUses += amount;
        _usageByType[buildingId][usageKey] += amount;

        emit BuildingUsageRecorded(
            buildingId,
            usageType,
            amount,
            _usageByType[buildingId][usageKey],
            m.totalUses,
            msg.sender
        );
    }

    /*//////////////////////////////////////////////////////////////
                         OPTIONAL IDENTITY / PROVENANCE SETTERS
    //////////////////////////////////////////////////////////////*/
    /* TYPE: manager-side provenance/visual enrichment for V1/V2 readiness */

    function setIdentityTraits(
        uint256 buildingId,
        uint256 dnaSeed,
        uint32 visualVariant,
        uint8 originFaction,
        uint8 originDistrictKind,
        uint8 resonanceType,
        uint32 founderEra,
        uint32 genesisEra
    ) external onlyRole(BUILDING_MANAGER_ROLE) whenNotPaused {
        _requireMintedBuilding(buildingId);

        BuildingIdentityData storage i = _buildingIdentity[buildingId];
        i.dnaSeed = dnaSeed;
        i.visualVariant = visualVariant;
        i.originFaction = originFaction;
        i.originDistrictKind = originDistrictKind;
        i.resonanceType = resonanceType;
        i.founderEra = founderEra;
        i.genesisEra = genesisEra;
    }

    function setVersionTag(
        uint256 buildingId,
        uint32 versionTag
    ) external onlyRole(BUILDING_MANAGER_ROLE) whenNotPaused {
        _requireMintedBuilding(buildingId);
        if (versionTag == 0) revert InvalidVersionTag();

        _buildingMeta[buildingId].versionTag = versionTag;
    }

    /*//////////////////////////////////////////////////////////////
                             METADATA / URI
    //////////////////////////////////////////////////////////////*/
    /* TYPE: metadata layer — still NFT layer, not gameplay logic */

    function setBaseTokenURI(
        string calldata newBaseTokenUri
    ) external onlyRole(METADATA_ROLE) {
        string memory oldValue = _baseTokenUri;
        _baseTokenUri = newBaseTokenUri;
        emit BaseTokenURISet(oldValue, newBaseTokenUri, msg.sender);
    }

    function setImageURI(
        uint256 buildingId,
        string calldata imageURI
    ) external onlyRole(METADATA_ROLE) {
        _requireMintedBuilding(buildingId);
        _buildingUris[buildingId].imageURI = imageURI;
        emit BuildingImageURISet(buildingId, imageURI, msg.sender);
    }

    function setMetadataURI(
        uint256 buildingId,
        string calldata metadataURI
    ) external onlyRole(METADATA_ROLE) {
        _requireMintedBuilding(buildingId);
        _buildingUris[buildingId].metadataURI = metadataURI;
        emit BuildingMetadataURISet(buildingId, metadataURI, msg.sender);
    }

    function getImageURI(uint256 buildingId) external view returns (string memory) {
        _requireMintedBuilding(buildingId);
        return _buildingUris[buildingId].imageURI;
    }

    function getMetadataURI(uint256 buildingId) external view returns (string memory) {
        _requireMintedBuilding(buildingId);
        return _buildingUris[buildingId].metadataURI;
    }

    function tokenURI(uint256 buildingId) public view override returns (string memory) {
        _requireMintedBuilding(buildingId);

        string memory explicitMetadataUri = _buildingUris[buildingId].metadataURI;
        if (bytes(explicitMetadataUri).length > 0) {
            return explicitMetadataUri;
        }

        if (bytes(_baseTokenUri).length == 0) {
            return "";
        }

        return string(abi.encodePacked(_baseTokenUri, Strings.toString(buildingId), ".json"));
    }

    /*//////////////////////////////////////////////////////////////
                              EXTRA READS
    //////////////////////////////////////////////////////////////*/
    /* TYPE: utility reads for frontend / migration / analytics */

    function getUsageCount(
        uint256 buildingId,
        CityBuildingTypes.BuildingUsageType usageType
    ) external view returns (uint32) {
        _requireMintedBuilding(buildingId);
        return _usageByType[buildingId][uint8(usageType)];
    }

    function exists(uint256 buildingId) external view returns (bool) {
        return _ownerOf(buildingId) != address(0);
    }

    function nextBuildingId() external view returns (uint256) {
        return _nextBuildingId;
    }

    /*//////////////////////////////////////////////////////////////
                           TRANSFER RESTRICTIONS
    //////////////////////////////////////////////////////////////*/
    /* TYPE: NFT transfer policy — placed buildings cannot move */

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override whenNotPaused returns (address from) {
        from = _ownerOf(tokenId);

        if (from != address(0) && to != address(0)) {
            BuildingStateData memory s = _buildingStateData[tokenId];
            if (s.placed) revert TransferBlockedWhilePlaced(tokenId);

            _buildingMeta[tokenId].totalTransfers += 1;
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

        BuildingStateData memory s = _buildingStateData[buildingId];
        if (s.archived) revert BuildingArchived();
        if (s.migrationPrepared) revert BuildingPreparedForMigration();
    }

    function _requireOwnerOrManager(uint256 buildingId) internal view {
        address owner = ownerOf(buildingId);
        if (
            msg.sender != owner &&
            !hasRole(BUILDING_MANAGER_ROLE, msg.sender)
        ) {
            revert ZeroAddress(); // replace with custom unauthorized error later if preferred
        }
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
            ) % 100000
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