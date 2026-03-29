/* FILE: contracts/city/contracts/interfaces/ICityCollectiveBuildingNFTV1Like.sol */
/* TYPE: shared collective building NFT interface for Community / Borderline / Nexus orchestrators */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../libraries/CityBuildingTypes.sol";
import "../libraries/CollectiveBuildingTypes.sol";

interface ICityCollectiveBuildingNFTV1Like {
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

    function mintCommunityBuilding(
        address custodyHolder,
        CollectiveBuildingTypes.CommunityBuildingKind kind,
        uint8 faction,
        uint256 plotId,
        uint256 campaignId,
        CollectiveBuildingTypes.CollectiveCustodyMode custodyMode,
        uint32 versionTag
    ) external returns (uint256 tokenId);

    function mintBorderlineBuilding(
        address custodyHolder,
        CollectiveBuildingTypes.BorderlineBuildingKind kind,
        uint8 primaryFaction,
        uint8 secondaryFaction,
        uint256 plotId,
        uint256 campaignId,
        CollectiveBuildingTypes.CollectiveCustodyMode custodyMode,
        uint32 versionTag
    ) external returns (uint256 tokenId);

    function mintNexusBuilding(
        address custodyHolder,
        CollectiveBuildingTypes.NexusBuildingKind kind,
        uint256 plotId,
        uint256 campaignId,
        CollectiveBuildingTypes.CollectiveCustodyMode custodyMode,
        uint32 versionTag
    ) external returns (uint256 tokenId);

    function ownerOf(uint256 tokenId) external view returns (address);
    function getCollectiveIdentity(uint256 tokenId) external view returns (CollectiveBuildingTypes.CollectiveIdentity memory);
    function getCollectiveAssetMeta(uint256 tokenId) external view returns (CollectiveAssetMetaView memory);
    function getCollectiveState(uint256 tokenId) external view returns (CollectiveBuildingTypes.CollectiveBuildingState);
    function isArchived(uint256 tokenId) external view returns (bool);
    function isMigrationPrepared(uint256 tokenId) external view returns (bool);
    function getSelectedBranches(uint256 tokenId) external view returns (CollectiveBranchSelectionView memory);
    function getCollectiveVisualState(uint256 tokenId) external view returns (CollectiveVisualStateView memory);
    function getCollectiveProvenance(uint256 tokenId) external view returns (CollectiveProvenanceView memory);

    function setCollectiveState(uint256 tokenId, CollectiveBuildingTypes.CollectiveBuildingState newState) external;
    function upgradeCollectiveBuilding(uint256 tokenId, uint8 newLevel) external;
    function setCommunityBranch(uint256 tokenId, CollectiveBuildingTypes.CommunityBuildingBranch newBranch) external;
    function setBorderlineBranch(uint256 tokenId, CollectiveBuildingTypes.BorderlineBuildingBranch newBranch) external;
    function setNexusBranch(uint256 tokenId, CollectiveBuildingTypes.NexusBuildingBranch newBranch) external;
    function addPrestigeScore(uint256 tokenId, uint32 amount) external;
    function addHistoryScore(uint256 tokenId, uint32 amount) external;
}
