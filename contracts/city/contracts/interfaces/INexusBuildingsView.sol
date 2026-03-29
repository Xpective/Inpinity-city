/* FILE: contracts/city/contracts/interfaces/INexusBuildingsView.sol */
/* TYPE: shared nexus buildings read/write interface for Portal / Dungeon / migration tooling */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../libraries/CollectiveBuildingTypes.sol";
import "../libraries/NexusTypes.sol";

interface INexusBuildingsView {
    function getTokenIdForKind(
        CollectiveBuildingTypes.NexusBuildingKind kind
    ) external view returns (uint256);

    function kindIsActive(
        CollectiveBuildingTypes.NexusBuildingKind kind
    ) external view returns (bool);

    function getNexusGlobalState()
        external
        view
        returns (NexusTypes.NexusGlobalState memory);

    function isCityMemberEligible(address account) external view returns (bool);

    function syncNexusMetrics(
        uint32 activeRouteCount,
        uint32 hiddenRouteCount,
        uint32 activeDungeonCount,
        uint32 cityStabilityBps,
        uint32 cityInstabilityBps
    ) external;
}
