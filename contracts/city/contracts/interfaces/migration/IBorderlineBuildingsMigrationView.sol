/* FILE: contracts/city/contracts/interfaces/migration/IBorderlineBuildingsMigrationView.sol */
/* TYPE: borderline buildings migration read interface */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../libraries/CollectiveBuildingTypes.sol";

interface IBorderlineBuildingsMigrationView {
    struct BorderlineBuildingRecord {
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

    struct BorderlineFundingRoundView {
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

    function getBorderlineBuildingRecord(uint256 tokenId) external view returns (BorderlineBuildingRecord memory);
    function getFundingRound(uint256 tokenId, uint256 roundId) external view returns (BorderlineFundingRoundView memory);
    function getCurrentFundingRoundId(uint256 tokenId) external view returns (uint256);
    function getContributionOf(uint256 tokenId, uint256 roundId, address contributor) external view returns (
        uint256[10] memory amounts,
        bool refunded,
        bool countedAsContributor
    );
}
