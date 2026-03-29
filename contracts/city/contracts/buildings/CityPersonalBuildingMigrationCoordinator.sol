/* FILE: contracts/city/contracts/buildings/CityPersonalBuildingMigrationCoordinator.sol */
/* TYPE: personal building V2 migration coordinator / snapshot hasher — NOT gameplay runtime */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

import "../libraries/CityBuildingTypes.sol";
import "../libraries/CityBuildingMigrationTypes.sol";
import "../interfaces/migration/ICityPersonalBuildingNFTMigrationView.sol";
import "../interfaces/migration/ICityPersonalBuildingPlacementMigrationView.sol";

contract CityPersonalBuildingMigrationCoordinator is AccessControl, Pausable {
    bytes32 public constant EXPORT_ADMIN_ROLE = keccak256("EXPORT_ADMIN_ROLE");
    bytes32 public constant EXPORTER_ROLE = keccak256("EXPORTER_ROLE");

    uint32 public constant MIGRATION_SCHEMA_VERSION = 1;

    error ZeroAddress();
    error InvalidNFT();
    error InvalidPlacement();
    error InvalidChronicleRange();

    event PersonalBuildingNFTSet(address indexed target, address indexed executor);
    event PersonalPlacementSet(address indexed target, address indexed executor);
    event PersonalBundleAnnounced(
        uint256 indexed buildingId,
        address indexed owner,
        bytes32 indexed exportTag,
        bytes32 bundleHash,
        uint64 exportedAt,
        uint256 exportNonce
    );

    ICityPersonalBuildingNFTMigrationView public personalBuildingNFT;
    ICityPersonalBuildingPlacementMigrationView public personalPlacement;

    mapping(uint256 => bytes32) public lastBundleHashOf;
    mapping(uint256 => uint256) public exportNonceOf;

    constructor(
        address personalBuildingNFT_,
        address personalPlacement_,
        address admin_
    ) {
        if (admin_ == address(0)) revert ZeroAddress();
        if (personalBuildingNFT_ == address(0)) revert ZeroAddress();
        if (personalPlacement_ == address(0)) revert ZeroAddress();
        if (personalBuildingNFT_.code.length == 0) revert InvalidNFT();
        if (personalPlacement_.code.length == 0) revert InvalidPlacement();

        personalBuildingNFT = ICityPersonalBuildingNFTMigrationView(personalBuildingNFT_);
        personalPlacement = ICityPersonalBuildingPlacementMigrationView(personalPlacement_);

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(EXPORT_ADMIN_ROLE, admin_);
        _grantRole(EXPORTER_ROLE, admin_);
    }

    function pause() external onlyRole(EXPORT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(EXPORT_ADMIN_ROLE) {
        _unpause();
    }

    function setPersonalBuildingNFT(address target_) external onlyRole(EXPORT_ADMIN_ROLE) {
        if (target_ == address(0)) revert ZeroAddress();
        if (target_.code.length == 0) revert InvalidNFT();
        personalBuildingNFT = ICityPersonalBuildingNFTMigrationView(target_);
        emit PersonalBuildingNFTSet(target_, msg.sender);
    }

    function setPersonalPlacement(address target_) external onlyRole(EXPORT_ADMIN_ROLE) {
        if (target_ == address(0)) revert ZeroAddress();
        if (target_.code.length == 0) revert InvalidPlacement();
        personalPlacement = ICityPersonalBuildingPlacementMigrationView(target_);
        emit PersonalPlacementSet(target_, msg.sender);
    }

    function previewBundle(
        uint256 buildingId,
        bytes32 exportTag
    ) public view returns (CityBuildingMigrationTypes.PersonalMigrationBundle memory bundle) {
        bundle.envelope = _buildEnvelope(exportTag);
        bundle.building = _buildBuildingSnapshot(buildingId);
        bundle.placement = _buildPlacementSnapshot(buildingId);
    }

    function hashBundle(uint256 buildingId, bytes32 exportTag) public view returns (bytes32) {
        CityBuildingMigrationTypes.PersonalMigrationBundle memory bundle = previewBundle(buildingId, exportTag);
        return keccak256(abi.encode(bundle));
    }

    function announceBundle(
        uint256 buildingId,
        bytes32 exportTag
    ) external onlyRole(EXPORTER_ROLE) whenNotPaused returns (bytes32 bundleHash) {
        CityBuildingMigrationTypes.PersonalMigrationBundle memory bundle = previewBundle(buildingId, exportTag);
        bundleHash = keccak256(abi.encode(bundle));

        lastBundleHashOf[buildingId] = bundleHash;
        uint256 nonce = ++exportNonceOf[buildingId];

        emit PersonalBundleAnnounced(
            buildingId,
            bundle.building.owner,
            exportTag,
            bundleHash,
            bundle.envelope.exportedAt,
            nonce
        );
    }

    function hashChronicleChunk(
        uint256 buildingId,
        uint256 start,
        uint256 limit
    ) external view returns (bytes32 chunkHash, uint256 endExclusive) {
        uint256 count = personalBuildingNFT.getChronicleCount(buildingId);
        if (start > count) revert InvalidChronicleRange();

        endExclusive = count;
        if (limit != 0 && start + limit < count) {
            endExclusive = start + limit;
        }

        bytes32 rolling;
        for (uint256 i = start; i < endExclusive; ++i) {
            CityBuildingTypes.ChronicleEntry memory c = personalBuildingNFT.getChronicleEntry(buildingId, i);
            rolling = keccak256(
                abi.encode(
                    rolling,
                    c.eventType,
                    c.eventData1,
                    c.eventData2,
                    c.actor,
                    c.timestamp,
                    c.extraData
                )
            );
        }

        return (rolling, endExclusive);
    }

    function _buildEnvelope(bytes32 exportTag) internal view returns (CityBuildingMigrationTypes.MigrationEnvelope memory) {
        return CityBuildingMigrationTypes.MigrationEnvelope({
            schemaVersion: MIGRATION_SCHEMA_VERSION,
            exportedAt: uint64(block.timestamp),
            chainId: block.chainid,
            coordinator: address(this),
            exportTag: exportTag
        });
    }

    function _buildBuildingSnapshot(
        uint256 buildingId
    ) internal view returns (CityBuildingMigrationTypes.PersonalBuildingSnapshot memory s) {
        address owner = personalBuildingNFT.ownerOf(buildingId);
        ICityPersonalBuildingNFTMigrationView.BuildingIdentityView memory identity =
            personalBuildingNFT.getBuildingIdentity(buildingId);
        ICityPersonalBuildingNFTMigrationView.VisualStateView memory visual =
            personalBuildingNFT.getVisualState(buildingId);
        ICityPersonalBuildingNFTMigrationView.ProvenanceCoreView memory provenance =
            personalBuildingNFT.getProvenanceCore(buildingId);
        CityBuildingTypes.BuildingUsageStats memory usageStats =
            personalBuildingNFT.getBuildingUsageStats(buildingId);
        CityBuildingTypes.BuildingHistoryCounters memory historyCounters =
            personalBuildingNFT.getBuildingHistoryCounters(buildingId);

        s = CityBuildingMigrationTypes.PersonalBuildingSnapshot({
            buildingId: buildingId,
            owner: owner,
            category: identity.category,
            buildingType: identity.buildingType,
            versionTag: identity.versionTag,
            dnaSeed: identity.dnaSeed,
            visualVariant: identity.visualVariant,
            customName: identity.customName,
            resonanceType: identity.resonanceType,
            mintedAt: identity.mintedAt,
            creator: identity.creator,
            originalMinter: identity.originalMinter,
            level: visual.level,
            specialization: visual.specialization,
            factionVariant: visual.factionVariant,
            placed: visual.placed,
            archived: visual.archived,
            migrationPrepared: visual.migrationPrepared,
            state: visual.state,
            imageURI: visual.imageURI,
            metadataURI: visual.metadataURI,
            originFaction: provenance.originFaction,
            originDistrictKind: provenance.originDistrictKind,
            founderEra: provenance.founderEra,
            genesisEra: provenance.genesisEra,
            prestigeScore: provenance.prestigeScore,
            historyScore: provenance.historyScore,
            usageStats: usageStats,
            historyCounters: historyCounters
        });
    }

    function _buildPlacementSnapshot(
        uint256 buildingId
    ) internal view returns (CityBuildingMigrationTypes.PersonalPlacementSnapshot memory s) {
        ICityPersonalBuildingPlacementMigrationView.PlacementProvenance memory p =
            personalPlacement.getPlacementProvenance(buildingId);

        s = CityBuildingMigrationTypes.PersonalPlacementSnapshot({
            currentPlotId: p.currentPlotId,
            firstPlotId: p.firstPlotId,
            firstFaction: p.firstFaction,
            firstDistrictKind: p.firstDistrictKind,
            firstPlacedTimestamp: p.firstPlacedTimestamp,
            currentPlacedAt: p.currentPlacedAt,
            lastPlacedAt: p.lastPlacedAt,
            lastUnplacedTimestamp: p.lastUnplacedTimestamp,
            currentPlacedBy: p.currentPlacedBy,
            currentlyPlaced: p.currentlyPlaced,
            placementPreparedForMigration: p.placementPreparedForMigration,
            placementArchivedToV2: p.placementArchivedToV2
        });
    }
}
