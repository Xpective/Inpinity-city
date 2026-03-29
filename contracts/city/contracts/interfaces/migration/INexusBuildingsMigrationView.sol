/* FILE: contracts/city/contracts/interfaces/migration/INexusBuildingsMigrationView.sol */
/* TYPE: nexus buildings migration read interface */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../libraries/CollectiveBuildingTypes.sol";
import "../../libraries/NexusTypes.sol";

interface INexusBuildingsMigrationView {
    struct NexusBuildingRecord {
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

    struct NexusFundingRoundView {
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

    function getNexusBuildingRecord(uint256 tokenId) external view returns (NexusBuildingRecord memory);
    function getFundingRound(uint256 tokenId, uint256 roundId) external view returns (NexusFundingRoundView memory);
    function getCurrentFundingRoundId(uint256 tokenId) external view returns (uint256);
    function getContributionOf(uint256 tokenId, uint256 roundId, address contributor) external view returns (
        uint256[10] memory amounts,
        bool refunded,
        bool countedAsContributor
    );
    function getNexusGlobalState() external view returns (NexusTypes.NexusGlobalState memory);
}
