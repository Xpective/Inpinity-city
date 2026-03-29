/* FILE: contracts/city/contracts/interfaces/migration/ICityPersonalBuildingPlacementMigrationView.sol */
/* TYPE: personal building placement migration read interface */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ICityPersonalBuildingPlacementMigrationView {
    struct PlacementProvenance {
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

    function isPlacedBuilding(uint256 buildingId) external view returns (bool);
    function getPlacementSummary(uint256 buildingId) external view returns (
        uint256 plotId,
        bool placed,
        bool prepared,
        bool archived,
        uint64 placedAt,
        uint64 lastPlacedAt,
        address placedBy
    );
    function getPlacementProvenance(uint256 buildingId) external view returns (PlacementProvenance memory);
}
