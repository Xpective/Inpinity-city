// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ICityMateriaItems {
    function mintMateriaItem(
        address to,
        uint256 itemId,
        uint256 amount
    ) external;

    function burnMateriaItem(
        address from,
        uint256 itemId,
        uint256 amount
    ) external;

    function getMateriaItemMeta(
        uint256 itemId
    )
        external
        view
        returns (
            uint256 materiaDefinitionId,
            uint256 level,
            uint256 rarityTier,
            bool burnOnUse,
            bool enabled
        );
}