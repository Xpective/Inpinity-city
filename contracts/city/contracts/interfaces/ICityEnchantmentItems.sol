// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ICityEnchantmentItems {
    function mintEnchantmentItem(
        address to,
        uint256 itemId,
        uint256 amount
    ) external;

    function burnEnchantmentItem(
        address from,
        uint256 itemId,
        uint256 amount
    ) external;

    function getEnchantmentItemMeta(
        uint256 itemId
    )
        external
        view
        returns (
            uint256 enchantmentDefinitionId,
            uint256 level,
            uint256 rarityTier,
            bool burnOnUse,
            bool enabled
        );
}