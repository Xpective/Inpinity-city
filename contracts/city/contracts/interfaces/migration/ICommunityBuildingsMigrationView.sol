/* FILE: contracts/city/contracts/interfaces/migration/ICommunityBuildingsMigrationView.sol */
/* TYPE: community buildings migration read interface */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../libraries/CollectiveBuildingTypes.sol";

interface ICommunityBuildingsMigrationView {
    struct CommunityBuildingRecord {
        uint256 tokenId;
        CollectiveBuildingTypes.CommunityBuildingKind kind;
        uint8 faction;
        uint256 plotId;
        uint256 creationCampaignId;
        address campaignStarter;
        bool exists;
        bool active;
    }

    struct CommunityFundingRoundView {
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

    function getCommunityBuildingRecord(uint256 tokenId) external view returns (CommunityBuildingRecord memory);
    function getFundingRound(uint256 tokenId, uint256 roundId) external view returns (CommunityFundingRoundView memory);
    function getCurrentFundingRoundId(uint256 tokenId) external view returns (uint256);
    function getContributionOf(uint256 tokenId, uint256 roundId, address contributor) external view returns (
        uint256[10] memory amounts,
        bool refunded,
        bool countedAsContributor
    );
}
