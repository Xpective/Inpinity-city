/* FILE: contracts/city/contracts/interfaces/migration/ICityCollectiveBuildingNFTMigrationView.sol */
/* TYPE: collective building NFT migration read interface */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../libraries/CityBuildingTypes.sol";
import "../../libraries/CollectiveBuildingTypes.sol";

interface ICityCollectiveBuildingNFTMigrationView {
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

    function ownerOf(uint256 tokenId) external view returns (address);
    function getCollectiveIdentity(uint256 tokenId) external view returns (CollectiveBuildingTypes.CollectiveIdentity memory);
    function getCollectiveAssetMeta(uint256 tokenId) external view returns (CollectiveAssetMetaView memory);
    function getCollectiveState(uint256 tokenId) external view returns (CollectiveBuildingTypes.CollectiveBuildingState);
    function isArchived(uint256 tokenId) external view returns (bool);
    function isMigrationPrepared(uint256 tokenId) external view returns (bool);
    function getSelectedBranches(uint256 tokenId) external view returns (CollectiveBranchSelectionView memory);
    function getCollectiveVisualState(uint256 tokenId) external view returns (CollectiveVisualStateView memory);
    function getCollectiveProvenance(uint256 tokenId) external view returns (CollectiveProvenanceView memory);
    function getChronicleCount(uint256 tokenId) external view returns (uint256);
    function getChronicleEntry(uint256 tokenId, uint256 index) external view returns (CityBuildingTypes.ChronicleEntry memory);
}
