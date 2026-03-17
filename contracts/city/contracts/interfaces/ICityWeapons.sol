// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ICityWeapons {
    function mintWeapon(
        address to,
        uint256 weaponDefinitionId,
        uint256 rarityTier,
        uint256 frameTier,
        uint256 originPlotId,
        uint256 originFaction,
        uint256 originDistrictKind,
        uint8 resonanceType,
        uint256 visualVariant,
        bool genesisEra,
        bool usedAether,
        uint256 nonce
    ) external returns (uint256 tokenId);
}