// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ICityBuildingPlacementPolicy
/// @notice Gemeinsames Interface für Placement-Policies.
/// @dev Wird von CityBuildingPlacement und CityBuildingPolicyRouter genutzt.
///      V1 nutzt primär validatePersonalPlacement.
///      Weitere Kategorien können später als Zusatzfunktionen ergänzt werden.
interface ICityBuildingPlacementPolicy {
    function validatePersonalPlacement(
        address owner,
        uint256 plotId,
        uint256 buildingId
    )
        external
        view
        returns (
            bool allowed,
            bool ownerMatches,
            bool plotCompleted,
            bool plotEligible,
            bool personalPlot,
            bool districtAllowed,
            bool factionAllowed,
            bytes32 reasonCode
        );
}