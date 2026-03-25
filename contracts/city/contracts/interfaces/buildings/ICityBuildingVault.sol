/* FILE: contracts/city/contracts/interfaces/buildings/ICityBuildingVault.sol */
/* TYPE: building vault interface — NOT NFT, NOT PersonalBuildings */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../libraries/CityBuildingTypes.sol";

interface ICityBuildingVault {
    struct WarehouseVaultProfile {
        bool vaultEnabled;
        bool raidEnabled;
        bool repairRequired;
        bool emergencyLocked;

        uint8 vaultTier;
        uint8 defenseTier;
        uint8 decayState;
        uint8 repairState;

        uint32 vaultCapBps;
        uint32 defenseBps;
        uint32 raidMitigationBps;
        uint32 damageBps;

        uint64 activatedAt;
        uint64 lastVaultActionAt;
        uint64 lastDecayCheckAt;
        uint64 lastRepairAt;
        uint64 lastRaidAt;
    }

    struct VaultResourceState {
        uint256 stored;
        uint256 reserved;
        uint256 protectedAmount;
        uint256 raidableAmount;
    }

    function getWarehouseVaultProfile(
        uint256 buildingId
    ) external view returns (WarehouseVaultProfile memory);

    function getWarehouseVaultResourceState(
        uint256 buildingId,
        uint8 resourceId
    ) external view returns (VaultResourceState memory);

    function isWarehouseVaultEnabled(
        uint256 buildingId
    ) external view returns (bool);

    function getWarehouseVaultCapBps(
        uint256 buildingId
    ) external view returns (uint32);

    function getWarehouseVaultDefenseProfile(
        uint256 buildingId
    )
        external
        view
        returns (
            uint8 defenseTier,
            uint32 defenseBps,
            uint32 raidMitigationBps,
            uint32 damageBps
        );

    function getWarehouseVaultTotals(
        uint256 buildingId
    )
        external
        view
        returns (
            uint256 totalStored,
            uint256 totalReserved,
            uint256 totalProtected,
            uint256 totalRaidable
        );

    function getBuildingDurabilityState(
        uint256 buildingId
    )
        external
        view
        returns (
            uint8 decayState,
            uint8 repairState,
            uint32 damageBps,
            bool repairRequired,
            uint64 lastDecayCheckAt,
            uint64 lastRepairAt
        );
}