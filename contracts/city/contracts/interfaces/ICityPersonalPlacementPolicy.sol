/* FILE: contracts/city/contracts/interfaces/ICityPersonalPlacementPolicy.sol */
/* TYPE: shared placement policy interface */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ICityBuildingPlacementPolicy
/// @notice Shared interface for building placement policy contracts.
/// @dev Used by CityBuildingPlacement and CityBuildingPolicyRouter.
///      V1 uses validatePersonalPlacement.
///      Future community / borderline / nexus policies can extend this pattern.
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