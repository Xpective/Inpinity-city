// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../libraries/CityTypes.sol";

interface ICityHistory {
    function initializePlotHistory(
        uint256 plotId,
        address firstBuilder,
        CityTypes.Faction faction,
        bool genesisEra
    ) external;

    function recordOwnershipTransfer(uint256 plotId) external;
    function recordLayerAdded(uint256 plotId) external;
    function recordAetherUse(uint256 plotId) external;
}