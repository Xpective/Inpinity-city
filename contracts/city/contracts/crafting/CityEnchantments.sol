// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/CityErrors.sol";

contract CityEnchantments is Ownable {
    enum EnchantmentCategory {
        None,
        Damage,
        Crit,
        Accuracy,
        Range,
        Durability,
        ArmorPen,
        LifeSteal,
        Energy,
        Heat,
        Stability,
        Cooldown,
        Projectile,
        Area,
        Utility
    }

    struct EnchantmentDefinition {
        uint256 id;
        string name;
        EnchantmentCategory category;
        uint256 rarityTier;
        uint256 maxLevel;
        bool enabled;
    }

    struct EnchantmentBonuses {
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

    mapping(uint256 => EnchantmentDefinition) public enchantmentDefinitionOf;
    mapping(uint256 => mapping(uint256 => EnchantmentBonuses)) public enchantmentBonusesOf; // enchantId => level => bonuses
    mapping(address => bool) public authorizedCallers;

    event AuthorizedCallerSet(address indexed caller, bool allowed);
    event EnchantmentDefinitionSet(
        uint256 indexed enchantmentId,
        string name,
        EnchantmentCategory category,
        uint256 rarityTier,
        uint256 maxLevel,
        bool enabled
    );
    event EnchantmentBonusesSet(
        uint256 indexed enchantmentId,
        uint256 indexed level
    );

    constructor(address initialOwner) Ownable(initialOwner) {
        if (initialOwner == address(0)) revert CityErrors.ZeroAddress();
    }

    modifier onlyAuthorized() {
        if (!(msg.sender == owner() || authorizedCallers[msg.sender])) {
            revert CityErrors.NotAuthorized();
        }
        _;
    }

    function setAuthorizedCaller(address caller, bool allowed) external onlyOwner {
        if (caller == address(0)) revert CityErrors.ZeroAddress();
        authorizedCallers[caller] = allowed;
        emit AuthorizedCallerSet(caller, allowed);
    }

    function setEnchantmentDefinition(
        uint256 enchantmentId,
        string calldata name,
        EnchantmentCategory category,
        uint256 rarityTier,
        uint256 maxLevel,
        bool enabled
    ) external onlyAuthorized {
        if (enchantmentId == 0) revert CityErrors.InvalidValue();
        if (bytes(name).length == 0) revert CityErrors.InvalidValue();
        if (category == EnchantmentCategory.None) revert CityErrors.InvalidValue();
        if (maxLevel == 0) revert CityErrors.InvalidValue();

        enchantmentDefinitionOf[enchantmentId] = EnchantmentDefinition({
            id: enchantmentId,
            name: name,
            category: category,
            rarityTier: rarityTier,
            maxLevel: maxLevel,
            enabled: enabled
        });

        emit EnchantmentDefinitionSet(
            enchantmentId,
            name,
            category,
            rarityTier,
            maxLevel,
            enabled
        );
    }

    function setEnchantmentBonuses(
        uint256 enchantmentId,
        uint256 level,
        EnchantmentBonuses calldata bonuses
    ) external onlyAuthorized {
        EnchantmentDefinition memory def = enchantmentDefinitionOf[enchantmentId];
        if (def.id == 0 || !def.enabled) revert CityErrors.InvalidValue();
        if (level == 0 || level > def.maxLevel) revert CityErrors.InvalidValue();

        enchantmentBonusesOf[enchantmentId][level] = bonuses;
        emit EnchantmentBonusesSet(enchantmentId, level);
    }

    function getEnchantmentBonuses(
        uint256 enchantmentId,
        uint256 level
    ) external view returns (EnchantmentBonuses memory) {
        return enchantmentBonusesOf[enchantmentId][level];
    }

    function getEnchantmentDefinition(
        uint256 enchantmentId
    ) external view returns (EnchantmentDefinition memory) {
        return enchantmentDefinitionOf[enchantmentId];
    }

    function enchantmentExists(uint256 enchantmentId) external view returns (bool) {
        return enchantmentDefinitionOf[enchantmentId].id != 0;
    }

    function isEnchantmentEnabled(uint256 enchantmentId) external view returns (bool) {
        return enchantmentDefinitionOf[enchantmentId].enabled;
    }

    function isEnchantmentUsable(
        uint256 enchantmentId,
        uint256 level
    ) external view returns (bool) {
        EnchantmentDefinition memory def = enchantmentDefinitionOf[enchantmentId];
        if (def.id == 0) return false;
        if (!def.enabled) return false;
        if (level == 0 || level > def.maxLevel) return false;
        return true;
    }

    function getEnchantmentMeta(
        uint256 enchantmentId
    )
        external
        view
        returns (
            string memory name,
            EnchantmentCategory category,
            uint256 rarityTier,
            uint256 maxLevel,
            bool enabled
        )
    {
        EnchantmentDefinition memory def = enchantmentDefinitionOf[enchantmentId];
        return (
            def.name,
            def.category,
            def.rarityTier,
            def.maxLevel,
            def.enabled
        );
    }
}