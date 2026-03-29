/* FILE: contracts/city/contracts/buildings/CityCollectiveBuildingMigrationCoordinator.sol */
/* TYPE: collective building V2 migration coordinator / snapshot hasher — NOT gameplay runtime */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

import "../libraries/CityBuildingTypes.sol";
import "../libraries/CollectiveBuildingTypes.sol";
import "../libraries/NexusTypes.sol";
import "../libraries/CityBuildingMigrationTypes.sol";
import "../interfaces/migration/ICityCollectiveBuildingNFTMigrationView.sol";
import "../interfaces/migration/ICommunityBuildingsMigrationView.sol";
import "../interfaces/migration/IBorderlineBuildingsMigrationView.sol";
import "../interfaces/migration/INexusBuildingsMigrationView.sol";

contract CityCollectiveBuildingMigrationCoordinator is AccessControl, Pausable {
    bytes32 public constant EXPORT_ADMIN_ROLE = keccak256("EXPORT_ADMIN_ROLE");
    bytes32 public constant EXPORTER_ROLE = keccak256("EXPORTER_ROLE");

    uint32 public constant MIGRATION_SCHEMA_VERSION = 1;

    error ZeroAddress();
    error InvalidCollectiveNFT();
    error InvalidCommunity();
    error InvalidBorderline();
    error InvalidNexus();
    error InvalidChronicleRange();

    event CollectiveNFTSet(address indexed target, address indexed executor);
    event CommunityBuildingsSet(address indexed target, address indexed executor);
    event BorderlineBuildingsSet(address indexed target, address indexed executor);
    event NexusBuildingsSet(address indexed target, address indexed executor);

    event CommunityBundleAnnounced(
        uint256 indexed tokenId,
        bytes32 indexed exportTag,
        bytes32 bundleHash,
        uint64 exportedAt,
        uint256 exportNonce
    );

    event BorderlineBundleAnnounced(
        uint256 indexed tokenId,
        bytes32 indexed exportTag,
        bytes32 bundleHash,
        uint64 exportedAt,
        uint256 exportNonce
    );

    event NexusBundleAnnounced(
        uint256 indexed tokenId,
        bytes32 indexed exportTag,
        bytes32 bundleHash,
        uint64 exportedAt,
        uint256 exportNonce
    );

    ICityCollectiveBuildingNFTMigrationView public collectiveNFT;
    ICommunityBuildingsMigrationView public communityBuildings;
    IBorderlineBuildingsMigrationView public borderlineBuildings;
    INexusBuildingsMigrationView public nexusBuildings;

    mapping(uint256 => bytes32) public lastCommunityBundleHashOf;
    mapping(uint256 => bytes32) public lastBorderlineBundleHashOf;
    mapping(uint256 => bytes32) public lastNexusBundleHashOf;

    mapping(uint256 => uint256) public communityExportNonceOf;
    mapping(uint256 => uint256) public borderlineExportNonceOf;
    mapping(uint256 => uint256) public nexusExportNonceOf;

    constructor(
        address collectiveNFT_,
        address communityBuildings_,
        address borderlineBuildings_,
        address nexusBuildings_,
        address admin_
    ) {
        if (admin_ == address(0)) revert ZeroAddress();
        if (collectiveNFT_ == address(0)) revert ZeroAddress();
        if (communityBuildings_ == address(0)) revert ZeroAddress();
        if (borderlineBuildings_ == address(0)) revert ZeroAddress();
        if (nexusBuildings_ == address(0)) revert ZeroAddress();
        if (collectiveNFT_.code.length == 0) revert InvalidCollectiveNFT();
        if (communityBuildings_.code.length == 0) revert InvalidCommunity();
        if (borderlineBuildings_.code.length == 0) revert InvalidBorderline();
        if (nexusBuildings_.code.length == 0) revert InvalidNexus();

        collectiveNFT = ICityCollectiveBuildingNFTMigrationView(collectiveNFT_);
        communityBuildings = ICommunityBuildingsMigrationView(communityBuildings_);
        borderlineBuildings = IBorderlineBuildingsMigrationView(borderlineBuildings_);
        nexusBuildings = INexusBuildingsMigrationView(nexusBuildings_);

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

    function setCollectiveNFT(address target_) external onlyRole(EXPORT_ADMIN_ROLE) {
        if (target_ == address(0)) revert ZeroAddress();
        if (target_.code.length == 0) revert InvalidCollectiveNFT();
        collectiveNFT = ICityCollectiveBuildingNFTMigrationView(target_);
        emit CollectiveNFTSet(target_, msg.sender);
    }

    function setCommunityBuildings(address target_) external onlyRole(EXPORT_ADMIN_ROLE) {
        if (target_ == address(0)) revert ZeroAddress();
        if (target_.code.length == 0) revert InvalidCommunity();
        communityBuildings = ICommunityBuildingsMigrationView(target_);
        emit CommunityBuildingsSet(target_, msg.sender);
    }

    function setBorderlineBuildings(address target_) external onlyRole(EXPORT_ADMIN_ROLE) {
        if (target_ == address(0)) revert ZeroAddress();
        if (target_.code.length == 0) revert InvalidBorderline();
        borderlineBuildings = IBorderlineBuildingsMigrationView(target_);
        emit BorderlineBuildingsSet(target_, msg.sender);
    }

    function setNexusBuildings(address target_) external onlyRole(EXPORT_ADMIN_ROLE) {
        if (target_ == address(0)) revert ZeroAddress();
        if (target_.code.length == 0) revert InvalidNexus();
        nexusBuildings = INexusBuildingsMigrationView(target_);
        emit NexusBuildingsSet(target_, msg.sender);
    }

    function previewCommunityBundle(
        uint256 tokenId,
        uint256 roundId,
        address contributor,
        bytes32 exportTag
    ) public view returns (CityBuildingMigrationTypes.CommunityMigrationBundle memory bundle) {
        bundle.envelope = _buildEnvelope(exportTag);
        bundle.nft = _buildCollectiveSnapshot(tokenId);
        bundle.record = _buildCommunityRecord(tokenId);

        uint256 resolvedRoundId = roundId == 0 ? communityBuildings.getCurrentFundingRoundId(tokenId) : roundId;
        bundle.activeRound = _buildCommunityRound(tokenId, resolvedRoundId);
        bundle.contributor = _buildCommunityContributor(tokenId, resolvedRoundId, contributor);
    }

    function previewBorderlineBundle(
        uint256 tokenId,
        uint256 roundId,
        address contributor,
        bytes32 exportTag
    ) public view returns (CityBuildingMigrationTypes.BorderlineMigrationBundle memory bundle) {
        bundle.envelope = _buildEnvelope(exportTag);
        bundle.nft = _buildCollectiveSnapshot(tokenId);
        bundle.record = _buildBorderlineRecord(tokenId);

        uint256 resolvedRoundId = roundId == 0 ? borderlineBuildings.getCurrentFundingRoundId(tokenId) : roundId;
        bundle.activeRound = _buildBorderlineRound(tokenId, resolvedRoundId);
        bundle.contributor = _buildBorderlineContributor(tokenId, resolvedRoundId, contributor);
    }

    function previewNexusBundle(
        uint256 tokenId,
        uint256 roundId,
        address contributor,
        bytes32 exportTag
    ) public view returns (CityBuildingMigrationTypes.NexusMigrationBundle memory bundle) {
        bundle.envelope = _buildEnvelope(exportTag);
        bundle.nft = _buildCollectiveSnapshot(tokenId);
        bundle.record = _buildNexusRecord(tokenId);

        uint256 resolvedRoundId = roundId == 0 ? nexusBuildings.getCurrentFundingRoundId(tokenId) : roundId;
        bundle.activeRound = _buildNexusRound(tokenId, resolvedRoundId);
        bundle.contributor = _buildNexusContributor(tokenId, resolvedRoundId, contributor);
        bundle.globalState = nexusBuildings.getNexusGlobalState();
    }

    function hashCommunityBundle(
        uint256 tokenId,
        uint256 roundId,
        address contributor,
        bytes32 exportTag
    ) public view returns (bytes32) {
        return keccak256(abi.encode(previewCommunityBundle(tokenId, roundId, contributor, exportTag)));
    }

    function hashBorderlineBundle(
        uint256 tokenId,
        uint256 roundId,
        address contributor,
        bytes32 exportTag
    ) public view returns (bytes32) {
        return keccak256(abi.encode(previewBorderlineBundle(tokenId, roundId, contributor, exportTag)));
    }

    function hashNexusBundle(
        uint256 tokenId,
        uint256 roundId,
        address contributor,
        bytes32 exportTag
    ) public view returns (bytes32) {
        return keccak256(abi.encode(previewNexusBundle(tokenId, roundId, contributor, exportTag)));
    }

    function announceCommunityBundle(
        uint256 tokenId,
        uint256 roundId,
        address contributor,
        bytes32 exportTag
    ) external onlyRole(EXPORTER_ROLE) whenNotPaused returns (bytes32 bundleHash) {
        CityBuildingMigrationTypes.CommunityMigrationBundle memory bundle =
            previewCommunityBundle(tokenId, roundId, contributor, exportTag);
        bundleHash = keccak256(abi.encode(bundle));
        lastCommunityBundleHashOf[tokenId] = bundleHash;
        uint256 nonce = ++communityExportNonceOf[tokenId];
        emit CommunityBundleAnnounced(tokenId, exportTag, bundleHash, bundle.envelope.exportedAt, nonce);
    }

    function announceBorderlineBundle(
        uint256 tokenId,
        uint256 roundId,
        address contributor,
        bytes32 exportTag
    ) external onlyRole(EXPORTER_ROLE) whenNotPaused returns (bytes32 bundleHash) {
        CityBuildingMigrationTypes.BorderlineMigrationBundle memory bundle =
            previewBorderlineBundle(tokenId, roundId, contributor, exportTag);
        bundleHash = keccak256(abi.encode(bundle));
        lastBorderlineBundleHashOf[tokenId] = bundleHash;
        uint256 nonce = ++borderlineExportNonceOf[tokenId];
        emit BorderlineBundleAnnounced(tokenId, exportTag, bundleHash, bundle.envelope.exportedAt, nonce);
    }

    function announceNexusBundle(
        uint256 tokenId,
        uint256 roundId,
        address contributor,
        bytes32 exportTag
    ) external onlyRole(EXPORTER_ROLE) whenNotPaused returns (bytes32 bundleHash) {
        CityBuildingMigrationTypes.NexusMigrationBundle memory bundle =
            previewNexusBundle(tokenId, roundId, contributor, exportTag);
        bundleHash = keccak256(abi.encode(bundle));
        lastNexusBundleHashOf[tokenId] = bundleHash;
        uint256 nonce = ++nexusExportNonceOf[tokenId];
        emit NexusBundleAnnounced(tokenId, exportTag, bundleHash, bundle.envelope.exportedAt, nonce);
    }

    function hashChronicleChunk(
        uint256 tokenId,
        uint256 start,
        uint256 limit
    ) external view returns (bytes32 chunkHash, uint256 endExclusive) {
        uint256 count = collectiveNFT.getChronicleCount(tokenId);
        if (start > count) revert InvalidChronicleRange();

        endExclusive = count;
        if (limit != 0 && start + limit < count) {
            endExclusive = start + limit;
        }

        bytes32 rolling;
        for (uint256 i = start; i < endExclusive; ++i) {
            CityBuildingTypes.ChronicleEntry memory c = collectiveNFT.getChronicleEntry(tokenId, i);
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

    function _buildCollectiveSnapshot(
        uint256 tokenId
    ) internal view returns (CityBuildingMigrationTypes.CollectiveBuildingSnapshot memory s) {
        address owner = collectiveNFT.ownerOf(tokenId);
        CollectiveBuildingTypes.CollectiveIdentity memory identity = collectiveNFT.getCollectiveIdentity(tokenId);
        ICityCollectiveBuildingNFTMigrationView.CollectiveAssetMetaView memory assetMeta =
            collectiveNFT.getCollectiveAssetMeta(tokenId);
        ICityCollectiveBuildingNFTMigrationView.CollectiveBranchSelectionView memory branches =
            collectiveNFT.getSelectedBranches(tokenId);
        ICityCollectiveBuildingNFTMigrationView.CollectiveVisualStateView memory visual =
            collectiveNFT.getCollectiveVisualState(tokenId);
        ICityCollectiveBuildingNFTMigrationView.CollectiveProvenanceView memory provenance =
            collectiveNFT.getCollectiveProvenance(tokenId);

        s = CityBuildingMigrationTypes.CollectiveBuildingSnapshot({
            tokenId: tokenId,
            owner: owner,
            identity: identity,
            assetMeta: CityBuildingMigrationTypes.CollectiveAssetMetaView({
                customName: assetMeta.customName,
                versionTag: assetMeta.versionTag,
                totalUpgrades: assetMeta.totalUpgrades,
                prestigeScore: assetMeta.prestigeScore,
                historyScore: assetMeta.historyScore
            }),
            branches: CityBuildingMigrationTypes.CollectiveBranchSelectionView({
                communityBranch: branches.communityBranch,
                borderlineBranch: branches.borderlineBranch,
                nexusBranch: branches.nexusBranch
            }),
            visualState: CityBuildingMigrationTypes.CollectiveVisualStateView({
                visualVariant: visual.visualVariant,
                level: visual.level,
                state: visual.state,
                archived: visual.archived,
                migrationPrepared: visual.migrationPrepared,
                imageURI: visual.imageURI,
                metadataURI: visual.metadataURI
            }),
            provenance: CityBuildingMigrationTypes.CollectiveProvenanceView({
                category: provenance.category,
                creator: provenance.creator,
                custodyHolder: provenance.custodyHolder,
                custodyMode: provenance.custodyMode,
                primaryFaction: provenance.primaryFaction,
                secondaryFaction: provenance.secondaryFaction,
                plotId: provenance.plotId,
                campaignId: provenance.campaignId,
                createdAt: provenance.createdAt,
                activatedAt: provenance.activatedAt,
                versionTag: provenance.versionTag,
                prestigeScore: provenance.prestigeScore,
                historyScore: provenance.historyScore
            })
        });
    }

    function _buildCommunityRecord(
        uint256 tokenId
    ) internal view returns (CityBuildingMigrationTypes.CommunityBuildingRecordSnapshot memory s) {
        ICommunityBuildingsMigrationView.CommunityBuildingRecord memory record =
            communityBuildings.getCommunityBuildingRecord(tokenId);
        s = CityBuildingMigrationTypes.CommunityBuildingRecordSnapshot({
            tokenId: record.tokenId,
            kind: record.kind,
            faction: record.faction,
            plotId: record.plotId,
            creationCampaignId: record.creationCampaignId,
            campaignStarter: record.campaignStarter,
            exists: record.exists,
            active: record.active
        });
    }

    function _buildCommunityRound(
        uint256 tokenId,
        uint256 roundId
    ) internal view returns (CityBuildingMigrationTypes.CommunityFundingRoundSnapshot memory s) {
        ICommunityBuildingsMigrationView.CommunityFundingRoundView memory round =
            communityBuildings.getFundingRound(tokenId, roundId);
        s = CityBuildingMigrationTypes.CommunityFundingRoundSnapshot({
            roundId: round.roundId,
            exists: round.exists,
            isUpgrade: round.isUpgrade,
            targetLevel: round.targetLevel,
            campaignState: round.campaignState,
            contributorCount: round.contributorCount,
            campaignOpenedAt: round.campaignOpenedAt,
            campaignClosedAt: round.campaignClosedAt,
            fundedAt: round.fundedAt,
            activatedAt: round.activatedAt,
            targetAmounts: round.targetAmounts,
            raisedAmounts: round.raisedAmounts
        });
    }

    function _buildCommunityContributor(
        uint256 tokenId,
        uint256 roundId,
        address contributor
    ) internal view returns (CityBuildingMigrationTypes.CollectiveContributorSnapshot memory s) {
        s.contributor = contributor;
        if (contributor == address(0)) return s;
        (s.amounts, s.refunded, s.countedAsContributor) =
            communityBuildings.getContributionOf(tokenId, roundId, contributor);
    }

    function _buildBorderlineRecord(
        uint256 tokenId
    ) internal view returns (CityBuildingMigrationTypes.BorderlineBuildingRecordSnapshot memory s) {
        IBorderlineBuildingsMigrationView.BorderlineBuildingRecord memory record =
            borderlineBuildings.getBorderlineBuildingRecord(tokenId);
        s = CityBuildingMigrationTypes.BorderlineBuildingRecordSnapshot({
            tokenId: record.tokenId,
            kind: record.kind,
            primaryFaction: record.primaryFaction,
            secondaryFaction: record.secondaryFaction,
            plotId: record.plotId,
            creationCampaignId: record.creationCampaignId,
            campaignStarter: record.campaignStarter,
            exists: record.exists,
            active: record.active
        });
    }

    function _buildBorderlineRound(
        uint256 tokenId,
        uint256 roundId
    ) internal view returns (CityBuildingMigrationTypes.BorderlineFundingRoundSnapshot memory s) {
        IBorderlineBuildingsMigrationView.BorderlineFundingRoundView memory round =
            borderlineBuildings.getFundingRound(tokenId, roundId);
        s = CityBuildingMigrationTypes.BorderlineFundingRoundSnapshot({
            roundId: round.roundId,
            exists: round.exists,
            isUpgrade: round.isUpgrade,
            targetLevel: round.targetLevel,
            primaryFactionParticipated: round.primaryFactionParticipated,
            secondaryFactionParticipated: round.secondaryFactionParticipated,
            campaignState: round.campaignState,
            contributorCount: round.contributorCount,
            campaignOpenedAt: round.campaignOpenedAt,
            campaignClosedAt: round.campaignClosedAt,
            fundedAt: round.fundedAt,
            activatedAt: round.activatedAt,
            targetAmounts: round.targetAmounts,
            raisedAmounts: round.raisedAmounts
        });
    }

    function _buildBorderlineContributor(
        uint256 tokenId,
        uint256 roundId,
        address contributor
    ) internal view returns (CityBuildingMigrationTypes.CollectiveContributorSnapshot memory s) {
        s.contributor = contributor;
        if (contributor == address(0)) return s;
        (s.amounts, s.refunded, s.countedAsContributor) =
            borderlineBuildings.getContributionOf(tokenId, roundId, contributor);
    }

    function _buildNexusRecord(
        uint256 tokenId
    ) internal view returns (CityBuildingMigrationTypes.NexusBuildingRecordSnapshot memory s) {
        INexusBuildingsMigrationView.NexusBuildingRecord memory record =
            nexusBuildings.getNexusBuildingRecord(tokenId);
        s = CityBuildingMigrationTypes.NexusBuildingRecordSnapshot({
            tokenId: record.tokenId,
            kind: record.kind,
            plotId: record.plotId,
            creationCampaignId: record.creationCampaignId,
            campaignStarter: record.campaignStarter,
            exists: record.exists,
            active: record.active,
            portalRelevant: record.portalRelevant,
            dungeonRelevant: record.dungeonRelevant
        });
    }

    function _buildNexusRound(
        uint256 tokenId,
        uint256 roundId
    ) internal view returns (CityBuildingMigrationTypes.NexusFundingRoundSnapshot memory s) {
        INexusBuildingsMigrationView.NexusFundingRoundView memory round =
            nexusBuildings.getFundingRound(tokenId, roundId);
        s = CityBuildingMigrationTypes.NexusFundingRoundSnapshot({
            roundId: round.roundId,
            exists: round.exists,
            isUpgrade: round.isUpgrade,
            targetLevel: round.targetLevel,
            fundsSwept: round.fundsSwept,
            fundsSink: round.fundsSink,
            campaignState: round.campaignState,
            contributorCount: round.contributorCount,
            campaignOpenedAt: round.campaignOpenedAt,
            campaignClosedAt: round.campaignClosedAt,
            fundedAt: round.fundedAt,
            activatedAt: round.activatedAt,
            targetAmounts: round.targetAmounts,
            raisedAmounts: round.raisedAmounts
        });
    }

    function _buildNexusContributor(
        uint256 tokenId,
        uint256 roundId,
        address contributor
    ) internal view returns (CityBuildingMigrationTypes.CollectiveContributorSnapshot memory s) {
        s.contributor = contributor;
        if (contributor == address(0)) return s;
        (s.amounts, s.refunded, s.countedAsContributor) =
            nexusBuildings.getContributionOf(tokenId, roundId, contributor);
    }
}
