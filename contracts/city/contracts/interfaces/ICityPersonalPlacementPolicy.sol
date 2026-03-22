// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ICityPersonalPlacementPolicy {
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