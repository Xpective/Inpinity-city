/* FILE: contracts/city/contracts/interfaces/migration/ICityPersonalBuildingNFTMigrationView.sol */
/* TYPE: personal building NFT migration read interface */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../libraries/CityBuildingTypes.sol";

interface ICityPersonalBuildingNFTMigrationView {
    struct BuildingIdentityView {
        uint256 buildingId;
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
    }

    struct VisualStateView {
        uint32 visualVariant;
        uint8 level;
        CityBuildingTypes.BuildingSpecialization specialization;
        CityBuildingTypes.FactionVariant factionVariant;
        bool placed;
        bool archived;
        bool migrationPrepared;
        CityBuildingTypes.BuildingState state;
        string imageURI;
        string metadataURI;
    }

    struct ProvenanceCoreView {
        uint8 originFaction;
        uint8 originDistrictKind;
        uint8 resonanceType;
        uint32 founderEra;
        uint32 genesisEra;
        address creator;
        address originalMinter;
        uint64 mintedAt;
        uint32 versionTag;
        uint32 prestigeScore;
        uint32 historyScore;
    }

    function ownerOf(uint256 buildingId) external view returns (address);
    function isArchived(uint256 buildingId) external view returns (bool);
    function isMigrationPrepared(uint256 buildingId) external view returns (bool);
    function getBuildingIdentity(uint256 buildingId) external view returns (BuildingIdentityView memory);
    function getVisualState(uint256 buildingId) external view returns (VisualStateView memory);
    function getProvenanceCore(uint256 buildingId) external view returns (ProvenanceCoreView memory);
    function getBuildingUsageStats(uint256 buildingId) external view returns (CityBuildingTypes.BuildingUsageStats memory);
    function getBuildingHistoryCounters(uint256 buildingId) external view returns (CityBuildingTypes.BuildingHistoryCounters memory);
    function getChronicleCount(uint256 buildingId) external view returns (uint256);
    function getChronicleEntry(uint256 buildingId, uint256 index) external view returns (CityBuildingTypes.ChronicleEntry memory);
}
