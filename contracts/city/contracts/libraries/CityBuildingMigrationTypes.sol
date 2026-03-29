/* FILE: contracts/city/contracts/libraries/CityBuildingMigrationTypes.sol */
/* TYPE: shared V2 migration structs / snapshot envelopes — NOT runtime gameplay logic */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./CityBuildingTypes.sol";
import "./CollectiveBuildingTypes.sol";
import "./NexusTypes.sol";

/// @title CityBuildingMigrationTypes
/// @notice Shared V2 migration snapshot structs for Personal / Community / Borderline / Nexus.
/// @dev These structs are intended for off-chain export, deterministic snapshot hashing and
///      future migration coordinators. They deliberately separate migration data from runtime
///      gameplay storage so V2 exporters can evolve without mutating the live contracts.
library CityBuildingMigrationTypes {
    uint32 internal constant MIGRATION_SCHEMA_V1 = 1;

    struct MigrationEnvelope {
        uint32 schemaVersion;
        uint64 exportedAt;
        uint256 chainId;
        address coordinator;
        bytes32 exportTag;
    }

    struct PersonalBuildingSnapshot {
        uint256 buildingId;
        address owner;
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
        uint8 level;
        CityBuildingTypes.BuildingSpecialization specialization;
        CityBuildingTypes.FactionVariant factionVariant;
        bool placed;
        bool archived;
        bool migrationPrepared;
        CityBuildingTypes.BuildingState state;
        string imageURI;
        string metadataURI;
        uint8 originFaction;
        uint8 originDistrictKind;
        uint32 founderEra;
        uint32 genesisEra;
        uint32 prestigeScore;
        uint32 historyScore;
        CityBuildingTypes.BuildingUsageStats usageStats;
        CityBuildingTypes.BuildingHistoryCounters historyCounters;
    }

    struct PersonalPlacementSnapshot {
        uint256 currentPlotId;
        uint256 firstPlotId;
        uint8 firstFaction;
        uint8 firstDistrictKind;
        uint64 firstPlacedTimestamp;
        uint64 currentPlacedAt;
        uint64 lastPlacedAt;
        uint64 lastUnplacedTimestamp;
        address currentPlacedBy;
        bool currentlyPlaced;
        bool placementPreparedForMigration;
        bool placementArchivedToV2;
    }

    struct PersonalMigrationBundle {
        MigrationEnvelope envelope;
        PersonalBuildingSnapshot building;
        PersonalPlacementSnapshot placement;
    }

    struct CollectiveAssetMetaView {
        string customName;
        uint32 versionTag;
        uint32 totalUpgrades;
        uint32 prestigeScore;
        uint32 historyScore;
    }

    struct CollectiveBranchSelectionView {
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

    struct CollectiveBuildingSnapshot {
        uint256 tokenId;
        address owner;
        CollectiveBuildingTypes.CollectiveIdentity identity;
        CollectiveAssetMetaView assetMeta;
        CollectiveBranchSelectionView branches;
        CollectiveVisualStateView visualState;
        CollectiveProvenanceView provenance;
    }

    struct CollectiveContributorSnapshot {
        address contributor;
        uint256[10] amounts;
        bool refunded;
        bool countedAsContributor;
    }

    struct CommunityBuildingRecordSnapshot {
        uint256 tokenId;
        CollectiveBuildingTypes.CommunityBuildingKind kind;
        uint8 faction;
        uint256 plotId;
        uint256 creationCampaignId;
        address campaignStarter;
        bool exists;
        bool active;
    }

    struct CommunityFundingRoundSnapshot {
        uint256 roundId;
        bool exists;
        bool isUpgrade;
        uint8 targetLevel;
        CollectiveBuildingTypes.CollectiveCampaignState campaignState;
        uint32 contributorCount;
        uint64 campaignOpenedAt;
        uint64 campaignClosedAt;
        uint64 fundedAt;
        uint64 activatedAt;
        uint256[10] targetAmounts;
        uint256[10] raisedAmounts;
    }

    struct CommunityMigrationBundle {
        MigrationEnvelope envelope;
        CollectiveBuildingSnapshot nft;
        CommunityBuildingRecordSnapshot record;
        CommunityFundingRoundSnapshot activeRound;
        CollectiveContributorSnapshot contributor;
    }

    struct BorderlineBuildingRecordSnapshot {
        uint256 tokenId;
        CollectiveBuildingTypes.BorderlineBuildingKind kind;
        uint8 primaryFaction;
        uint8 secondaryFaction;
        uint256 plotId;
        uint256 creationCampaignId;
        address campaignStarter;
        bool exists;
        bool active;
    }

    struct BorderlineFundingRoundSnapshot {
        uint256 roundId;
        bool exists;
        bool isUpgrade;
        uint8 targetLevel;
        bool primaryFactionParticipated;
        bool secondaryFactionParticipated;
        CollectiveBuildingTypes.CollectiveCampaignState campaignState;
        uint32 contributorCount;
        uint64 campaignOpenedAt;
        uint64 campaignClosedAt;
        uint64 fundedAt;
        uint64 activatedAt;
        uint256[10] targetAmounts;
        uint256[10] raisedAmounts;
    }

    struct BorderlineMigrationBundle {
        MigrationEnvelope envelope;
        CollectiveBuildingSnapshot nft;
        BorderlineBuildingRecordSnapshot record;
        BorderlineFundingRoundSnapshot activeRound;
        CollectiveContributorSnapshot contributor;
    }

    struct NexusBuildingRecordSnapshot {
        uint256 tokenId;
        CollectiveBuildingTypes.NexusBuildingKind kind;
        uint256 plotId;
        uint256 creationCampaignId;
        address campaignStarter;
        bool exists;
        bool active;
        bool portalRelevant;
        bool dungeonRelevant;
    }

    struct NexusFundingRoundSnapshot {
        uint256 roundId;
        bool exists;
        bool isUpgrade;
        uint8 targetLevel;
        bool fundsSwept;
        address fundsSink;
        CollectiveBuildingTypes.CollectiveCampaignState campaignState;
        uint32 contributorCount;
        uint64 campaignOpenedAt;
        uint64 campaignClosedAt;
        uint64 fundedAt;
        uint64 activatedAt;
        uint256[10] targetAmounts;
        uint256[10] raisedAmounts;
    }

    struct NexusMigrationBundle {
        MigrationEnvelope envelope;
        CollectiveBuildingSnapshot nft;
        NexusBuildingRecordSnapshot record;
        NexusFundingRoundSnapshot activeRound;
        CollectiveContributorSnapshot contributor;
        NexusTypes.NexusGlobalState globalState;
    }
}
