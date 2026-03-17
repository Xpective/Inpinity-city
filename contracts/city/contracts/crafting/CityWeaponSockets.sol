// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/CityErrors.sol";
import "./CityWeapons.sol";
import "./CityEnchantments.sol";
import "./CityMateria.sol";

contract CityWeaponSockets is Ownable {
    struct EnchantmentSlot {
        uint256 enchantmentId;
        uint256 level;
        bool occupied;
    }

    struct MateriaSlot {
        uint256 materiaId;
        uint256 level;
        bool occupied;
    }

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

    CityWeapons public immutable cityWeapons;
    CityEnchantments public immutable cityEnchantments;
    CityMateria public immutable cityMateria;

    mapping(address => bool) public authorizedCallers;

    mapping(uint256 => mapping(uint256 => EnchantmentSlot)) public enchantmentSlotOfWeapon;
    mapping(uint256 => mapping(uint256 => MateriaSlot)) public materiaSlotOfWeapon;

    event AuthorizedCallerSet(address indexed caller, bool allowed);

    event EnchantmentAttached(
        uint256 indexed tokenId,
        uint256 indexed slotIndex,
        uint256 indexed enchantmentId,
        uint256 level
    );

    event EnchantmentRemoved(
        uint256 indexed tokenId,
        uint256 indexed slotIndex
    );

    event MateriaAttached(
        uint256 indexed tokenId,
        uint256 indexed slotIndex,
        uint256 indexed materiaId,
        uint256 level
    );

    event MateriaRemoved(
        uint256 indexed tokenId,
        uint256 indexed slotIndex
    );

    constructor(
        address initialOwner,
        address cityWeaponsAddress,
        address cityEnchantmentsAddress,
        address cityMateriaAddress
    ) Ownable(initialOwner) {
        if (
            initialOwner == address(0) ||
            cityWeaponsAddress == address(0) ||
            cityEnchantmentsAddress == address(0) ||
            cityMateriaAddress == address(0)
        ) {
            revert CityErrors.ZeroAddress();
        }

        cityWeapons = CityWeapons(cityWeaponsAddress);
        cityEnchantments = CityEnchantments(cityEnchantmentsAddress);
        cityMateria = CityMateria(cityMateriaAddress);
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

    function attachEnchantment(
        uint256 tokenId,
        uint256 slotIndex,
        uint256 enchantmentId,
        uint256 level
    ) external onlyAuthorized {
        (CityWeapons.WeaponDefinition memory def,,) = cityWeapons.getWeaponStats(tokenId);

        if (slotIndex >= def.enchantmentSlots) revert CityErrors.InvalidValue();
        if (enchantmentSlotOfWeapon[tokenId][slotIndex].occupied) revert CityErrors.InvalidValue();

        (
            ,
            ,
            ,
            uint256 maxLevel,
            bool enabled
        ) = cityEnchantments.getEnchantmentMeta(enchantmentId);

        if (!enabled) revert CityErrors.InvalidValue();
        if (level == 0 || level > maxLevel) revert CityErrors.InvalidValue();

        enchantmentSlotOfWeapon[tokenId][slotIndex] = EnchantmentSlot({
            enchantmentId: enchantmentId,
            level: level,
            occupied: true
        });

        emit EnchantmentAttached(tokenId, slotIndex, enchantmentId, level);
    }

    function removeEnchantment(
        uint256 tokenId,
        uint256 slotIndex
    ) external onlyAuthorized {
        delete enchantmentSlotOfWeapon[tokenId][slotIndex];
        emit EnchantmentRemoved(tokenId, slotIndex);
    }

    function attachMateria(
        uint256 tokenId,
        uint256 slotIndex,
        uint256 materiaId,
        uint256 level
    ) external onlyAuthorized {
        (CityWeapons.WeaponDefinition memory def,,) = cityWeapons.getWeaponStats(tokenId);

        if (slotIndex >= def.materiaSlots) revert CityErrors.InvalidValue();
        if (materiaSlotOfWeapon[tokenId][slotIndex].occupied) revert CityErrors.InvalidValue();

        (
            ,
            ,
            ,
            ,
            uint256 maxLevel,
            bool enabled
        ) = cityMateria.getMateriaMeta(materiaId);

        if (!enabled) revert CityErrors.InvalidValue();
        if (level == 0 || level > maxLevel) revert CityErrors.InvalidValue();

        materiaSlotOfWeapon[tokenId][slotIndex] = MateriaSlot({
            materiaId: materiaId,
            level: level,
            occupied: true
        });

        emit MateriaAttached(tokenId, slotIndex, materiaId, level);
    }

    function removeMateria(
        uint256 tokenId,
        uint256 slotIndex
    ) external onlyAuthorized {
        delete materiaSlotOfWeapon[tokenId][slotIndex];
        emit MateriaRemoved(tokenId, slotIndex);
    }

    function getEnchantmentAtSlot(
        uint256 tokenId,
        uint256 slotIndex
    ) external view returns (EnchantmentSlot memory) {
        return enchantmentSlotOfWeapon[tokenId][slotIndex];
    }

    function getMateriaAtSlot(
        uint256 tokenId,
        uint256 slotIndex
    ) external view returns (MateriaSlot memory) {
        return materiaSlotOfWeapon[tokenId][slotIndex];
    }

    function getAllEnchantments(
        uint256 tokenId
    ) external view returns (EnchantmentSlot[] memory result) {
        (CityWeapons.WeaponDefinition memory def,,) = cityWeapons.getWeaponStats(tokenId);
        result = new EnchantmentSlot[](def.enchantmentSlots);

        for (uint256 i = 0; i < def.enchantmentSlots; i++) {
            result[i] = enchantmentSlotOfWeapon[tokenId][i];
        }
    }

    function getAllMateria(
        uint256 tokenId
    ) external view returns (MateriaSlot[] memory result) {
        (CityWeapons.WeaponDefinition memory def,,) = cityWeapons.getWeaponStats(tokenId);
        result = new MateriaSlot[](def.materiaSlots);

        for (uint256 i = 0; i < def.materiaSlots; i++) {
            result[i] = materiaSlotOfWeapon[tokenId][i];
        }
    }

    function getTotalBonuses(
        uint256 tokenId
    ) external view returns (TotalBonuses memory total) {
        (CityWeapons.WeaponDefinition memory def,,) = cityWeapons.getWeaponStats(tokenId);

        for (uint256 i = 0; i < def.enchantmentSlots; i++) {
            EnchantmentSlot memory s = enchantmentSlotOfWeapon[tokenId][i];
            if (s.occupied) {
                CityEnchantments.EnchantmentBonuses memory b =
                    cityEnchantments.getEnchantmentBonuses(s.enchantmentId, s.level);

                total.minDamageBonus += b.minDamageBonus;
                total.maxDamageBonus += b.maxDamageBonus;
                total.attackSpeedBonus += b.attackSpeedBonus;
                total.critChanceBpsBonus += b.critChanceBpsBonus;
                total.critMultiplierBpsBonus += b.critMultiplierBpsBonus;
                total.accuracyBpsBonus += b.accuracyBpsBonus;
                total.rangeBonus += b.rangeBonus;
                total.maxDurabilityBonus += b.maxDurabilityBonus;
                total.armorPenBpsBonus += b.armorPenBpsBonus;
                total.blockChanceBpsBonus += b.blockChanceBpsBonus;
                total.lifeStealBpsBonus += b.lifeStealBpsBonus;
                total.energyCostBonus += b.energyCostBonus;
                total.heatGenerationBonus += b.heatGenerationBonus;
                total.stabilityBonus += b.stabilityBonus;
                total.cooldownMsBonus += b.cooldownMsBonus;
                total.projectileSpeedBonus += b.projectileSpeedBonus;
                total.aoeRadiusBonus += b.aoeRadiusBonus;
                total.enchantmentSlotsBonus += b.enchantmentSlotsBonus;
                total.materiaSlotsBonus += b.materiaSlotsBonus;
            }
        }

        for (uint256 i = 0; i < def.materiaSlots; i++) {
            MateriaSlot memory s = materiaSlotOfWeapon[tokenId][i];
            if (s.occupied) {
                CityMateria.MateriaBonuses memory b =
                    cityMateria.getMateriaBonuses(s.materiaId, s.level);

                total.minDamageBonus += b.minDamageBonus;
                total.maxDamageBonus += b.maxDamageBonus;
                total.attackSpeedBonus += b.attackSpeedBonus;
                total.critChanceBpsBonus += b.critChanceBpsBonus;
                total.critMultiplierBpsBonus += b.critMultiplierBpsBonus;
                total.accuracyBpsBonus += b.accuracyBpsBonus;
                total.rangeBonus += b.rangeBonus;
                total.maxDurabilityBonus += b.maxDurabilityBonus;
                total.armorPenBpsBonus += b.armorPenBpsBonus;
                total.blockChanceBpsBonus += b.blockChanceBpsBonus;
                total.lifeStealBpsBonus += b.lifeStealBpsBonus;
                total.energyCostBonus += b.energyCostBonus;
                total.heatGenerationBonus += b.heatGenerationBonus;
                total.stabilityBonus += b.stabilityBonus;
                total.cooldownMsBonus += b.cooldownMsBonus;
                total.projectileSpeedBonus += b.projectileSpeedBonus;
                total.aoeRadiusBonus += b.aoeRadiusBonus;
                total.enchantmentSlotsBonus += b.enchantmentSlotsBonus;
                total.materiaSlotsBonus += b.materiaSlotsBonus;
            }
        }
    }
}