/* FILE: contracts/city/contracts/buildings/CollectiveBuildingNFTV1.sol */
/* TYPE: collective NFT / asset / identity / provenance layer — NOT PersonalBuildings */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../libraries/CityBuildingTypes.sol";
import "../libraries/CollectiveBuildingTypes.sol";

/*//////////////////////////////////////////////////////////////
                COLLECTIVE BUILDING NFT V1
//////////////////////////////////////////////////////////////*/

/// @title CollectiveBuildingNFTV1
/// @notice ERC721 asset layer for Community / Borderline / Nexus buildings.
/// @dev This contract is custody-oriented:
///      - NFTs are typically minted to a custody / collection contract, not to a player wallet.
///      - gameplay, crowdfunding, governance, faction checks and market logic live outside this file.
///      - this file only stores asset identity, collective provenance, state, branches and metadata.
contract CollectiveBuildingNFTV1 is ERC721, AccessControl, Pausable {
    /*//////////////////////////////////////////////////////////////
                                 ROLES
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant COLLECTIVE_ADMIN_ROLE = keccak256("COLLECTIVE_ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant METADATA_ROLE = keccak256("METADATA_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error InvalidTokenId();
    error InvalidVersionTag();
    error InvalidCustodyMode();
    error InvalidCollectiveLevel();
    error InvalidCategory();
    error InvalidCommunityKind();
    error InvalidCommunityBranch();
    error InvalidBorderlineKind();
    error InvalidBorderlineBranch();
    error InvalidNexusKind();
    error InvalidNexusBranch();
    error InvalidNameLength();
    error NoStateChange();
    error Unauthorized();
    error BuildingArchived();
    error BuildingPreparedForMigration();
    error TransfersBlocked();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event CommunityBuildingMinted(
        uint256 indexed tokenId,
        CollectiveBuildingTypes.CommunityBuildingKind indexed kind,
        uint8 indexed faction,
        uint256 plotId,
        uint256 campaignId,
        address custodyHolder,
        uint32 versionTag,
        address creator,
        uint64 createdAt
    );

    event BorderlineBuildingMinted(
        uint256 indexed tokenId,
        CollectiveBuildingTypes.BorderlineBuildingKind indexed kind,
        uint8 indexed primaryFaction,
        uint8 secondaryFaction,
        uint256 plotId,
        uint256 campaignId,
        address custodyHolder,
        uint32 versionTag,
        address creator,
        uint64 createdAt
    );

    event NexusBuildingMinted(
        uint256 indexed tokenId,
        CollectiveBuildingTypes.NexusBuildingKind indexed kind,
        uint256 plotId,
        uint256 campaignId,
        address custodyHolder,
        uint32 versionTag,
        address creator,
        uint64 createdAt
    );

    event CollectiveStateSet(
        uint256 indexed tokenId,
        CollectiveBuildingTypes.CollectiveBuildingState oldState,
        CollectiveBuildingTypes.CollectiveBuildingState newState,
        address indexed executor,
        uint64 updatedAt
    );

    event CollectiveArchivedSet(
        uint256 indexed tokenId,
        bool archived,
        address indexed executor,
        uint64 updatedAt
    );

    event CollectiveMigrationPreparedSet(
        uint256 indexed tokenId,
        bool prepared,
        address indexed executor,
        uint64 updatedAt
    );

    event CollectiveUpgraded(
        uint256 indexed tokenId,
        uint8 oldLevel,
        uint8 newLevel,
        address indexed executor,
        uint64 updatedAt
    );

    event CollectiveContextSet(
        uint256 indexed tokenId,
        uint256 plotId,
        uint256 campaignId,
        uint8 primaryFaction,
        uint8 secondaryFaction,
        address indexed executor
    );

    event CollectiveCustodyTransferred(
        uint256 indexed tokenId,
        address indexed oldCustodyHolder,
        address indexed newCustodyHolder,
        CollectiveBuildingTypes.CollectiveCustodyMode newCustodyMode,
        address executor
    );

    event CommunityBranchSet(
        uint256 indexed tokenId,
        CollectiveBuildingTypes.CommunityBuildingBranch oldBranch,
        CollectiveBuildingTypes.CommunityBuildingBranch newBranch,
        address indexed executor
    );

    event BorderlineBranchSet(
        uint256 indexed tokenId,
        CollectiveBuildingTypes.BorderlineBuildingBranch oldBranch,
        CollectiveBuildingTypes.BorderlineBuildingBranch newBranch,
        address indexed executor
    );

    event NexusBranchSet(
        uint256 indexed tokenId,
        CollectiveBuildingTypes.NexusBuildingBranch oldBranch,
        CollectiveBuildingTypes.NexusBuildingBranch newBranch,
        address indexed executor
    );

    event CollectiveCustomNameSet(
        uint256 indexed tokenId,
        string customName,
        address indexed executor
    );

    event CollectiveImageURISet(
        uint256 indexed tokenId,
        string imageURI,
        address indexed executor
    );

    event CollectiveMetadataURISet(
        uint256 indexed tokenId,
        string metadataURI,
        address indexed executor
    );

    event CollectiveIdentityVisualSet(
        uint256 indexed tokenId,
        uint256 dnaSeed,
        uint32 visualVariant,
        address indexed executor
    );

    event CollectiveVersionTagSet(
        uint256 indexed tokenId,
        uint32 oldVersionTag,
        uint32 newVersionTag,
        address indexed executor
    );

    event CollectivePrestigeAdded(
        uint256 indexed tokenId,
        uint32 amount,
        uint32 newPrestigeScore,
        address indexed executor
    );

    event CollectiveHistoryAdded(
        uint256 indexed tokenId,
        uint32 amount,
        uint32 newHistoryScore,
        address indexed executor
    );

    event BaseTokenURISet(
        string oldValue,
        string newValue,
        address indexed executor
    );

    event ChronicleEntryRecorded(
        uint256 indexed tokenId,
        uint256 indexed index,
        CityBuildingTypes.ChronicleEventType eventType,
        address indexed actor,
        uint64 timestamp
    );

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 private _nextTokenId = 1;
    string private _baseTokenUri;

    struct CollectiveAssetMeta {
        string customName;
        uint32 versionTag;
        uint32 totalUpgrades;
        uint32 prestigeScore;
        uint32 historyScore;
    }

    struct CollectiveAssetExtension {
        uint256 dnaSeed;
        uint32 visualVariant;
        address creator;
        string imageURI;
        string metadataURI;
    }

    struct CollectiveBranchSelection {
        CollectiveBuildingTypes.CommunityBuildingBranch communityBranch;
        CollectiveBuildingTypes.BorderlineBuildingBranch borderlineBranch;
        CollectiveBuildingTypes.NexusBuildingBranch nexusBranch;
    }

    struct CollectiveVisualStateView {
        uint32 visualVariant;
        uint8 level;
        CollectiveBuildingTypes.CollectiveBuildingState state;
        bool archived;
        bool migrationPrepared;
        string imageURI;
        string metadataURI;
    }

    struct CollectiveProvenanceView {
        CityBuildingTypes.BuildingCategory category;
        address creator;
        address custodyHolder;
        CollectiveBuildingTypes.CollectiveCustodyMode custodyMode;
        uint8 primaryFaction;
        uint8 secondaryFaction;
        uint256 plotId;
        uint256 campaignId;
        uint64 createdAt;
        uint64 activatedAt;
        uint32 versionTag;
        uint32 prestigeScore;
        uint32 historyScore;
    }

    mapping(uint256 => CollectiveBuildingTypes.CollectiveIdentity) private _identity;
    mapping(uint256 => CollectiveAssetMeta) private _assetMeta;
    mapping(uint256 => CollectiveAssetExtension) private _assetExt;
    mapping(uint256 => CollectiveBranchSelection) private _branches;
    mapping(uint256 => CollectiveBuildingTypes.CollectiveBuildingState) private _state;
    mapping(uint256 => bool) private _archived;
    mapping(uint256 => bool) private _migrationPrepared;
    mapping(uint256 => CityBuildingTypes.ChronicleEntry[]) private _chronicles;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address admin_,
        string memory baseTokenUri_
    ) ERC721("Inpinity City Collective Buildings", "ICCOLL") {
        if (admin_ == address(0)) revert ZeroAddress();

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(COLLECTIVE_ADMIN_ROLE, admin_);
        _grantRole(MINTER_ROLE, admin_);
        _grantRole(MANAGER_ROLE, admin_);
        _grantRole(METADATA_ROLE, admin_);
        _grantRole(PAUSER_ROLE, admin_);

        _baseTokenUri = baseTokenUri_;
    }

    modifier onlyCreatorOrManager(uint256 tokenId) {
        _requireMinted(tokenId);

        if (
            msg.sender != _assetExt[tokenId].creator &&
            !hasRole(MANAGER_ROLE, msg.sender)
        ) revert Unauthorized();
        _;
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

    function mintCommunityBuilding(
        address custodyHolder,
        CollectiveBuildingTypes.CommunityBuildingKind kind,
        uint8 faction,
        uint256 plotId,
        uint256 campaignId,
        CollectiveBuildingTypes.CollectiveCustodyMode custodyMode,
        uint32 versionTag
    ) external onlyRole(MINTER_ROLE) whenNotPaused returns (uint256 tokenId) {
        if (custodyHolder == address(0)) revert ZeroAddress();
        if (!CollectiveBuildingTypes.isValidCommunityKind(kind)) {
            revert InvalidCommunityKind();
        }

        tokenId = _mintCollectiveBase(
            custodyHolder,
            CityBuildingTypes.BuildingCategory.Community,
            faction,
            0,
            plotId,
            campaignId,
            custodyMode,
            versionTag
        );

        CollectiveBuildingTypes.CollectiveIdentity storage id_ = _identity[tokenId];
        id_.communityKind = kind;

        _pushChronicle(
            tokenId,
            CityBuildingTypes.ChronicleEventType.Mint,
            1,
            uint32(uint8(kind)),
            msg.sender,
            bytes32(0)
        );

        emit CommunityBuildingMinted(
            tokenId,
            kind,
            faction,
            plotId,
            campaignId,
            custodyHolder,
            _assetMeta[tokenId].versionTag,
            msg.sender,
            id_.createdAt
        );
    }

    function mintBorderlineBuilding(
        address custodyHolder,
        CollectiveBuildingTypes.BorderlineBuildingKind kind,
        uint8 primaryFaction,
        uint8 secondaryFaction,
        uint256 plotId,
        uint256 campaignId,
        CollectiveBuildingTypes.CollectiveCustodyMode custodyMode,
        uint32 versionTag
    ) external onlyRole(MINTER_ROLE) whenNotPaused returns (uint256 tokenId) {
        if (custodyHolder == address(0)) revert ZeroAddress();
        if (!CollectiveBuildingTypes.isValidBorderlineKind(kind)) {
            revert InvalidBorderlineKind();
        }

        tokenId = _mintCollectiveBase(
            custodyHolder,
            CityBuildingTypes.BuildingCategory.Borderline,
            primaryFaction,
            secondaryFaction,
            plotId,
            campaignId,
            custodyMode,
            versionTag
        );

        CollectiveBuildingTypes.CollectiveIdentity storage id_ = _identity[tokenId];
        id_.borderlineKind = kind;

        _pushChronicle(
            tokenId,
            CityBuildingTypes.ChronicleEventType.Mint,
            1,
            uint32(uint8(kind)),
            msg.sender,
            bytes32(0)
        );

        emit BorderlineBuildingMinted(
            tokenId,
            kind,
            primaryFaction,
            secondaryFaction,
            plotId,
            campaignId,
            custodyHolder,
            _assetMeta[tokenId].versionTag,
            msg.sender,
            id_.createdAt
        );
    }

    function mintNexusBuilding(
        address custodyHolder,
        CollectiveBuildingTypes.NexusBuildingKind kind,
        uint256 plotId,
        uint256 campaignId,
        CollectiveBuildingTypes.CollectiveCustodyMode custodyMode,
        uint32 versionTag
    ) external onlyRole(MINTER_ROLE) whenNotPaused returns (uint256 tokenId) {
        if (custodyHolder == address(0)) revert ZeroAddress();
        if (!CollectiveBuildingTypes.isValidNexusKind(kind)) {
            revert InvalidNexusKind();
        }

        tokenId = _mintCollectiveBase(
            custodyHolder,
            CityBuildingTypes.BuildingCategory.Nexus,
            0,
            0,
            plotId,
            campaignId,
            custodyMode,
            versionTag
        );

        CollectiveBuildingTypes.CollectiveIdentity storage id_ = _identity[tokenId];
        id_.nexusKind = kind;

        _pushChronicle(
            tokenId,
            CityBuildingTypes.ChronicleEventType.Mint,
            1,
            uint32(uint8(kind)),
            msg.sender,
            bytes32(0)
        );

        emit NexusBuildingMinted(
            tokenId,
            kind,
            plotId,
            campaignId,
            custodyHolder,
            _assetMeta[tokenId].versionTag,
            msg.sender,
            id_.createdAt
        );
    }

    /*//////////////////////////////////////////////////////////////
                                  READS
    //////////////////////////////////////////////////////////////*/

    function getCollectiveIdentity(
        uint256 tokenId
    ) external view returns (CollectiveBuildingTypes.CollectiveIdentity memory) {
        _requireMinted(tokenId);
        return _identity[tokenId];
    }

    function getCollectiveAssetMeta(
        uint256 tokenId
    ) external view returns (CollectiveAssetMeta memory) {
        _requireMinted(tokenId);
        return _assetMeta[tokenId];
    }

    function getCollectiveState(
        uint256 tokenId
    ) external view returns (CollectiveBuildingTypes.CollectiveBuildingState) {
        _requireMinted(tokenId);
        return _state[tokenId];
    }

    function isArchived(uint256 tokenId) external view returns (bool) {
        _requireMinted(tokenId);
        return _archived[tokenId];
    }

    function isMigrationPrepared(uint256 tokenId) external view returns (bool) {
        _requireMinted(tokenId);
        return _migrationPrepared[tokenId];
    }

    function getSelectedBranches(
        uint256 tokenId
    ) external view returns (CollectiveBranchSelection memory) {
        _requireMinted(tokenId);
        return _branches[tokenId];
    }

    function getCollectiveVisualState(
        uint256 tokenId
    ) external view returns (CollectiveVisualStateView memory v) {
        _requireMinted(tokenId);

        CollectiveBuildingTypes.CollectiveIdentity memory id_ = _identity[tokenId];
        CollectiveAssetExtension memory ext = _assetExt[tokenId];

        v = CollectiveVisualStateView({
            visualVariant: ext.visualVariant,
            level: id_.level,
            state: _state[tokenId],
            archived: _archived[tokenId],
            migrationPrepared: _migrationPrepared[tokenId],
            imageURI: ext.imageURI,
            metadataURI: ext.metadataURI
        });
    }

    function getCollectiveProvenance(
        uint256 tokenId
    ) external view returns (CollectiveProvenanceView memory v) {
        _requireMinted(tokenId);

        CollectiveBuildingTypes.CollectiveIdentity memory id_ = _identity[tokenId];
        CollectiveAssetMeta memory meta = _assetMeta[tokenId];
        CollectiveAssetExtension memory ext = _assetExt[tokenId];

        v = CollectiveProvenanceView({
            category: id_.category,
            creator: ext.creator,
            custodyHolder: id_.custodyHolder,
            custodyMode: id_.custodyMode,
            primaryFaction: id_.primaryFaction,
            secondaryFaction: id_.secondaryFaction,
            plotId: id_.plotId,
            campaignId: id_.campaignId,
            createdAt: id_.createdAt,
            activatedAt: id_.activatedAt,
            versionTag: meta.versionTag,
            prestigeScore: meta.prestigeScore,
            historyScore: meta.historyScore
        });
    }

    function getChronicleCount(uint256 tokenId) external view returns (uint256) {
        _requireMinted(tokenId);
        return _chronicles[tokenId].length;
    }

    function getChronicleEntry(
        uint256 tokenId,
        uint256 index
    ) external view returns (CityBuildingTypes.ChronicleEntry memory) {
        _requireMinted(tokenId);
        return _chronicles[tokenId][index];
    }

    function getImageURI(uint256 tokenId) external view returns (string memory) {
        _requireMinted(tokenId);
        return _assetExt[tokenId].imageURI;
    }

    function getMetadataURI(uint256 tokenId) external view returns (string memory) {
        _requireMinted(tokenId);
        return _assetExt[tokenId].metadataURI;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireMinted(tokenId);

        string memory explicitMetadataUri = _assetExt[tokenId].metadataURI;
        if (bytes(explicitMetadataUri).length > 0) {
            return explicitMetadataUri;
        }

        if (bytes(_baseTokenUri).length == 0) {
            return "";
        }

        return string(
            abi.encodePacked(_baseTokenUri, Strings.toString(tokenId), ".json")
        );
    }

    /*//////////////////////////////////////////////////////////////
                            STATE MUTATIONS
    //////////////////////////////////////////////////////////////*/

    function setCollectiveState(
        uint256 tokenId,
        CollectiveBuildingTypes.CollectiveBuildingState newState
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        _requireMutable(tokenId);

        CollectiveBuildingTypes.CollectiveBuildingState oldState = _state[tokenId];
        if (oldState == newState) revert NoStateChange();

        _state[tokenId] = newState;

        if (
            newState == CollectiveBuildingTypes.CollectiveBuildingState.Active &&
            _identity[tokenId].activatedAt == 0
        ) {
            _identity[tokenId].activatedAt = uint64(block.timestamp);
        }

        _pushChronicle(
            tokenId,
            CityBuildingTypes.ChronicleEventType.VersionUpgrade,
            uint32(uint8(oldState)),
            uint32(uint8(newState)),
            msg.sender,
            bytes32(0)
        );

        emit CollectiveStateSet(
            tokenId,
            oldState,
            newState,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    function setArchived(
        uint256 tokenId,
        bool archived_
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        _requireMinted(tokenId);
        if (_archived[tokenId] == archived_) revert NoStateChange();

        _archived[tokenId] = archived_;

        if (archived_) {
            _state[tokenId] = CollectiveBuildingTypes.CollectiveBuildingState.Archived;

            _pushChronicle(
                tokenId,
                CityBuildingTypes.ChronicleEventType.ArchiveMigration,
                1,
                0,
                msg.sender,
                bytes32(0)
            );
        } else if (_state[tokenId] == CollectiveBuildingTypes.CollectiveBuildingState.Archived) {
            _state[tokenId] = CollectiveBuildingTypes.CollectiveBuildingState.Inactive;
        }

        emit CollectiveArchivedSet(
            tokenId,
            archived_,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    function setMigrationPrepared(
        uint256 tokenId,
        bool prepared
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        _requireMinted(tokenId);
        if (_migrationPrepared[tokenId] == prepared) revert NoStateChange();

        _migrationPrepared[tokenId] = prepared;

        emit CollectiveMigrationPreparedSet(
            tokenId,
            prepared,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    function upgradeCollectiveBuilding(
        uint256 tokenId,
        uint8 newLevel
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        _requireMutable(tokenId);
        if (!CollectiveBuildingTypes.isValidCollectiveLevel(newLevel)) {
            revert InvalidCollectiveLevel();
        }

        CollectiveBuildingTypes.CollectiveIdentity storage id_ = _identity[tokenId];
        if (newLevel <= id_.level) revert NoStateChange();

        uint8 oldLevel = id_.level;
        id_.level = newLevel;
        _assetMeta[tokenId].totalUpgrades += 1;

        _pushChronicle(
            tokenId,
            CityBuildingTypes.ChronicleEventType.Upgrade,
            oldLevel,
            newLevel,
            msg.sender,
            bytes32(0)
        );

        emit CollectiveUpgraded(
            tokenId,
            oldLevel,
            newLevel,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    function setCollectiveContext(
        uint256 tokenId,
        uint256 plotId,
        uint256 campaignId,
        uint8 primaryFaction,
        uint8 secondaryFaction
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        _requireMutable(tokenId);

        CollectiveBuildingTypes.CollectiveIdentity storage id_ = _identity[tokenId];

        id_.plotId = plotId;
        id_.campaignId = campaignId;
        id_.primaryFaction = primaryFaction;
        id_.secondaryFaction = secondaryFaction;

        emit CollectiveContextSet(
            tokenId,
            plotId,
            campaignId,
            primaryFaction,
            secondaryFaction,
            msg.sender
        );
    }

    function transferCustody(
        uint256 tokenId,
        address newCustodyHolder,
        CollectiveBuildingTypes.CollectiveCustodyMode newCustodyMode
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        _requireMinted(tokenId);
        if (newCustodyHolder == address(0)) revert ZeroAddress();

        address oldHolder = ownerOf(tokenId);
        CollectiveBuildingTypes.CollectiveCustodyMode resolvedMode =
            _resolveCustodyMode(_identity[tokenId].category, newCustodyMode);

        _transfer(oldHolder, newCustodyHolder, tokenId);

        _identity[tokenId].custodyHolder = newCustodyHolder;
        _identity[tokenId].custodyMode = resolvedMode;

        emit CollectiveCustodyTransferred(
            tokenId,
            oldHolder,
            newCustodyHolder,
            resolvedMode,
            msg.sender
        );
    }

    function setCommunityBranch(
        uint256 tokenId,
        CollectiveBuildingTypes.CommunityBuildingBranch newBranch
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        _requireMutable(tokenId);

        CollectiveBuildingTypes.CollectiveIdentity memory id_ = _identity[tokenId];
        if (id_.category != CityBuildingTypes.BuildingCategory.Community) {
            revert InvalidCategory();
        }
        if (
            !CollectiveBuildingTypes.canChooseCommunityBranch(
                id_.communityKind,
                id_.level,
                newBranch
            )
        ) revert InvalidCommunityBranch();

        CollectiveBuildingTypes.CommunityBuildingBranch oldBranch =
            _branches[tokenId].communityBranch;
        if (oldBranch == newBranch) revert NoStateChange();

        _branches[tokenId].communityBranch = newBranch;

        emit CommunityBranchSet(tokenId, oldBranch, newBranch, msg.sender);
    }

    function setBorderlineBranch(
        uint256 tokenId,
        CollectiveBuildingTypes.BorderlineBuildingBranch newBranch
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        _requireMutable(tokenId);

        CollectiveBuildingTypes.CollectiveIdentity memory id_ = _identity[tokenId];
        if (id_.category != CityBuildingTypes.BuildingCategory.Borderline) {
            revert InvalidCategory();
        }
        if (
            !CollectiveBuildingTypes.canChooseBorderlineBranch(
                id_.borderlineKind,
                id_.level,
                newBranch
            )
        ) revert InvalidBorderlineBranch();

        CollectiveBuildingTypes.BorderlineBuildingBranch oldBranch =
            _branches[tokenId].borderlineBranch;
        if (oldBranch == newBranch) revert NoStateChange();

        _branches[tokenId].borderlineBranch = newBranch;

        emit BorderlineBranchSet(tokenId, oldBranch, newBranch, msg.sender);
    }

    function setNexusBranch(
        uint256 tokenId,
        CollectiveBuildingTypes.NexusBuildingBranch newBranch
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        _requireMutable(tokenId);

        CollectiveBuildingTypes.CollectiveIdentity memory id_ = _identity[tokenId];
        if (id_.category != CityBuildingTypes.BuildingCategory.Nexus) {
            revert InvalidCategory();
        }
        if (
            !CollectiveBuildingTypes.canChooseNexusBranch(
                id_.nexusKind,
                id_.level,
                newBranch
            )
        ) revert InvalidNexusBranch();

        CollectiveBuildingTypes.NexusBuildingBranch oldBranch =
            _branches[tokenId].nexusBranch;
        if (oldBranch == newBranch) revert NoStateChange();

        _branches[tokenId].nexusBranch = newBranch;

        emit NexusBranchSet(tokenId, oldBranch, newBranch, msg.sender);
    }

    function setCustomName(
        uint256 tokenId,
        string calldata customName
    ) external whenNotPaused onlyCreatorOrManager(tokenId) {
        if (!CityBuildingTypes.isNameLengthValid(customName)) {
            revert InvalidNameLength();
        }

        _assetMeta[tokenId].customName = customName;

        emit CollectiveCustomNameSet(tokenId, customName, msg.sender);
    }

    function setCreatorImageURI(
        uint256 tokenId,
        string calldata imageURI
    ) external whenNotPaused onlyCreatorOrManager(tokenId) {
        _assetExt[tokenId].imageURI = imageURI;

        emit CollectiveImageURISet(tokenId, imageURI, msg.sender);
    }

    function setCreatorMetadataURI(
        uint256 tokenId,
        string calldata metadataURI
    ) external whenNotPaused onlyCreatorOrManager(tokenId) {
        _assetExt[tokenId].metadataURI = metadataURI;

        emit CollectiveMetadataURISet(tokenId, metadataURI, msg.sender);
    }

    function setImageURI(
        uint256 tokenId,
        string calldata imageURI
    ) external onlyRole(METADATA_ROLE) whenNotPaused {
        _requireMinted(tokenId);
        _assetExt[tokenId].imageURI = imageURI;

        emit CollectiveImageURISet(tokenId, imageURI, msg.sender);
    }

    function setMetadataURI(
        uint256 tokenId,
        string calldata metadataURI
    ) external onlyRole(METADATA_ROLE) whenNotPaused {
        _requireMinted(tokenId);
        _assetExt[tokenId].metadataURI = metadataURI;

        emit CollectiveMetadataURISet(tokenId, metadataURI, msg.sender);
    }

    function setIdentityVisual(
        uint256 tokenId,
        uint256 dnaSeed,
        uint32 visualVariant
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        _requireMinted(tokenId);

        _assetExt[tokenId].dnaSeed = dnaSeed;
        _assetExt[tokenId].visualVariant = visualVariant;

        emit CollectiveIdentityVisualSet(
            tokenId,
            dnaSeed,
            visualVariant,
            msg.sender
        );
    }

    function setVersionTag(
        uint256 tokenId,
        uint32 versionTag
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        _requireMinted(tokenId);

        uint32 normalizedVersionTag = _normalizeVersionTag(versionTag);
        uint32 oldVersionTag = _assetMeta[tokenId].versionTag;
        if (oldVersionTag == normalizedVersionTag) revert NoStateChange();

        _assetMeta[tokenId].versionTag = normalizedVersionTag;

        _pushChronicle(
            tokenId,
            CityBuildingTypes.ChronicleEventType.VersionUpgrade,
            oldVersionTag,
            normalizedVersionTag,
            msg.sender,
            bytes32(0)
        );

        emit CollectiveVersionTagSet(
            tokenId,
            oldVersionTag,
            normalizedVersionTag,
            msg.sender
        );
    }

    function addPrestigeScore(
        uint256 tokenId,
        uint32 amount
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        _requireMinted(tokenId);

        _assetMeta[tokenId].prestigeScore += amount;

        emit CollectivePrestigeAdded(
            tokenId,
            amount,
            _assetMeta[tokenId].prestigeScore,
            msg.sender
        );
    }

    function addHistoryScore(
        uint256 tokenId,
        uint32 amount
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        _requireMinted(tokenId);

        _assetMeta[tokenId].historyScore += amount;

        emit CollectiveHistoryAdded(
            tokenId,
            amount,
            _assetMeta[tokenId].historyScore,
            msg.sender
        );
    }

    function recordChronicleEntry(
        uint256 tokenId,
        CityBuildingTypes.ChronicleEventType eventType,
        uint32 eventData1,
        uint32 eventData2,
        address actor,
        bytes32 extraData
    ) external onlyRole(MANAGER_ROLE) whenNotPaused {
        _requireMinted(tokenId);
        _pushChronicle(
            tokenId,
            eventType,
            eventData1,
            eventData2,
            actor,
            extraData
        );
    }

    /*//////////////////////////////////////////////////////////////
                           TRANSFER POLICY
    //////////////////////////////////////////////////////////////*/

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override whenNotPaused returns (address from) {
        from = _ownerOf(tokenId);

        if (from != address(0) && to != address(0) && !hasRole(MANAGER_ROLE, msg.sender)) {
            revert TransfersBlocked();
        }

        return super._update(to, tokenId, auth);
    }

    /*//////////////////////////////////////////////////////////////
                               INTERNALS
    //////////////////////////////////////////////////////////////*/

    function _mintCollectiveBase(
        address custodyHolder,
        CityBuildingTypes.BuildingCategory category,
        uint8 primaryFaction,
        uint8 secondaryFaction,
        uint256 plotId,
        uint256 campaignId,
        CollectiveBuildingTypes.CollectiveCustodyMode custodyMode,
        uint32 versionTag
    ) internal returns (uint256 tokenId) {
        tokenId = _nextTokenId++;
        _safeMint(custodyHolder, tokenId);

        CollectiveBuildingTypes.CollectiveCustodyMode resolvedMode =
            _resolveCustodyMode(category, custodyMode);

        _identity[tokenId] = CollectiveBuildingTypes.CollectiveIdentity({
            category: category,
            communityKind: CollectiveBuildingTypes.CommunityBuildingKind.None,
            borderlineKind: CollectiveBuildingTypes.BorderlineBuildingKind.None,
            nexusKind: CollectiveBuildingTypes.NexusBuildingKind.None,
            level: 1,
            primaryFaction: primaryFaction,
            secondaryFaction: secondaryFaction,
            plotId: plotId,
            campaignId: campaignId,
            createdAt: uint64(block.timestamp),
            activatedAt: 0,
            custodyHolder: custodyHolder,
            custodyMode: resolvedMode
        });

        _assetMeta[tokenId] = CollectiveAssetMeta({
            customName: "",
            versionTag: _normalizeVersionTag(versionTag),
            totalUpgrades: 0,
            prestigeScore: 0,
            historyScore: 0
        });

        _state[tokenId] = CollectiveBuildingTypes.CollectiveBuildingState.Planned;
        _archived[tokenId] = false;
        _migrationPrepared[tokenId] = false;

        _assetExt[tokenId].creator = msg.sender;
        _assetExt[tokenId].dnaSeed = _deriveDnaSeed(
            tokenId,
            custodyHolder,
            category,
            primaryFaction,
            secondaryFaction,
            plotId,
            campaignId
        );
        _assetExt[tokenId].visualVariant = _deriveVisualVariant(
            tokenId,
            category,
            plotId,
            campaignId
        );
    }

    function _normalizeVersionTag(uint32 versionTag) internal pure returns (uint32) {
        uint32 effectiveVersionTag = versionTag == 0
            ? CityBuildingTypes.VERSION_TAG_V1
            : versionTag;

        if (
            effectiveVersionTag != CityBuildingTypes.VERSION_TAG_V1 &&
            effectiveVersionTag != CityBuildingTypes.VERSION_TAG_V2
        ) revert InvalidVersionTag();

        return effectiveVersionTag;
    }

    function _resolveCustodyMode(
        CityBuildingTypes.BuildingCategory category,
        CollectiveBuildingTypes.CollectiveCustodyMode custodyMode
    ) internal pure returns (CollectiveBuildingTypes.CollectiveCustodyMode) {
        if (custodyMode != CollectiveBuildingTypes.CollectiveCustodyMode.None) {
            return custodyMode;
        }

        if (category == CityBuildingTypes.BuildingCategory.Nexus) {
            return CollectiveBuildingTypes.CollectiveCustodyMode.CityCustodied;
        }

        if (
            category == CityBuildingTypes.BuildingCategory.Community ||
            category == CityBuildingTypes.BuildingCategory.Borderline
        ) {
            return CollectiveBuildingTypes.CollectiveCustodyMode.ContractCustodied;
        }

        revert InvalidCustodyMode();
    }

    function _deriveDnaSeed(
        uint256 tokenId,
        address custodyHolder,
        CityBuildingTypes.BuildingCategory category,
        uint8 primaryFaction,
        uint8 secondaryFaction,
        uint256 plotId,
        uint256 campaignId
    ) internal view returns (uint256) {
        return uint256(
            keccak256(
                abi.encodePacked(
                    "INPINITY_COLLECTIVE_BUILDING_DNA",
                    block.chainid,
                    address(this),
                    tokenId,
                    custodyHolder,
                    uint8(category),
                    primaryFaction,
                    secondaryFaction,
                    plotId,
                    campaignId,
                    block.timestamp
                )
            )
        );
    }

    function _deriveVisualVariant(
        uint256 tokenId,
        CityBuildingTypes.BuildingCategory category,
        uint256 plotId,
        uint256 campaignId
    ) internal view returns (uint32) {
        return uint32(
            uint256(
                keccak256(
                    abi.encodePacked(
                        "INPINITY_COLLECTIVE_BUILDING_VISUAL",
                        address(this),
                        tokenId,
                        uint8(category),
                        plotId,
                        campaignId,
                        block.prevrandao,
                        block.timestamp
                    )
                )
            ) % type(uint32).max
        );
    }

    function _pushChronicle(
        uint256 tokenId,
        CityBuildingTypes.ChronicleEventType eventType,
        uint32 eventData1,
        uint32 eventData2,
        address actor,
        bytes32 extraData
    ) internal {
        _chronicles[tokenId].push(
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
            tokenId,
            _chronicles[tokenId].length - 1,
            eventType,
            actor,
            uint64(block.timestamp)
        );
    }

    function _requireMinted(uint256 tokenId) internal view {
        if (_ownerOf(tokenId) == address(0)) revert InvalidTokenId();
    }

    function _requireMutable(uint256 tokenId) internal view {
        _requireMinted(tokenId);
        if (_archived[tokenId]) revert BuildingArchived();
        if (_migrationPrepared[tokenId]) revert BuildingPreparedForMigration();
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