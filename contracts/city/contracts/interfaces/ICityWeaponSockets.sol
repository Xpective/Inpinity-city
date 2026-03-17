// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ICityWeaponSockets {
    struct TotalBonuses {
        int256 minDamageBonus;
        int256 maxDamageBonus;
        int256 attackSpeedBonus;
        int256 critChanceBpsBonus;
        int256 critMultiplierBpsBonus;
        int256 accuracyBpsBonus;
        int256 rangeBonus;
        int256 maxDurabilityBonus;
        int256 armorPenBpsBonus;
        int256 blockChanceBpsBonus;
        int256 lifeStealBpsBonus;
        int256 energyCostBonus;
        int256 heatGenerationBonus;
        int256 stabilityBonus;
        int256 cooldownMsBonus;
        int256 projectileSpeedBonus;
        int256 aoeRadiusBonus;
        int256 enchantmentSlotsBonus;
        int256 materiaSlotsBonus;
    }

    function getTotalBonuses(
        uint256 tokenId
    ) external view returns (TotalBonuses memory);
}