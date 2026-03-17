// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/CityErrors.sol";
import "./BonusTypes.sol";

contract CityMateria is Ownable {
    enum MateriaCategory {
        None,
        Offensive,
        Defensive,
        Utility,
        Support,
        Elemental,
        Resonance,
        Legendary
    }

    enum MateriaElement {
        None,
        Fire,
        Water,
        Ice,
        Lightning,
        Earth,
        Crystal,
        Shadow,
        Light,
        Aether,
        Plasma,
        Energy
    }

    struct MateriaDefinition {
        uint256 id;
        string name;
        MateriaCategory category;
        MateriaElement element;
        uint256 rarityTier;
        uint256 maxLevel;
        bool enabled;
    }

    mapping(uint256 => MateriaDefinition) public materiaDefinitionOf;
    mapping(uint256 => mapping(uint256 => BonusTypes.BonusSet)) public materiaBonusesOf;
    mapping(address => bool) public authorizedCallers;

    event AuthorizedCallerSet(address indexed caller, bool allowed);

    event MateriaDefinitionSet(
        uint256 indexed materiaId,
        string name,
        MateriaCategory category,
        MateriaElement element,
        uint256 rarityTier,
        uint256 maxLevel,
        bool enabled
    );

    event MateriaBonusesSet(
        uint256 indexed materiaId,
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

    function setMateriaDefinition(
        uint256 materiaId,
        string calldata name,
        MateriaCategory category,
        MateriaElement element,
        uint256 rarityTier,
        uint256 maxLevel,
        bool enabled
    ) external onlyAuthorized {
        if (materiaId == 0) revert CityErrors.InvalidValue();
        if (bytes(name).length == 0) revert CityErrors.InvalidValue();
        if (category == MateriaCategory.None) revert CityErrors.InvalidValue();
        if (maxLevel == 0) revert CityErrors.InvalidValue();

        materiaDefinitionOf[materiaId] = MateriaDefinition({
            id: materiaId,
            name: name,
            category: category,
            element: element,
            rarityTier: rarityTier,
            maxLevel: maxLevel,
            enabled: enabled
        });

        emit MateriaDefinitionSet(
            materiaId,
            name,
            category,
            element,
            rarityTier,
            maxLevel,
            enabled
        );
    }

    function setMateriaBonuses(
        uint256 materiaId,
        uint256 level,
        BonusTypes.BonusSet calldata bonuses
    ) external onlyAuthorized {
        MateriaDefinition memory def = materiaDefinitionOf[materiaId];
        if (def.id == 0 || !def.enabled) revert CityErrors.InvalidValue();
        if (level == 0 || level > def.maxLevel) revert CityErrors.InvalidValue();

        materiaBonusesOf[materiaId][level] = bonuses;
        emit MateriaBonusesSet(materiaId, level);
    }

    function getMateriaBonuses(
        uint256 materiaId,
        uint256 level
    ) external view returns (BonusTypes.BonusSet memory) {
        return materiaBonusesOf[materiaId][level];
    }

    function getMateriaDefinition(
        uint256 materiaId
    ) external view returns (MateriaDefinition memory) {
        return materiaDefinitionOf[materiaId];
    }

    function materiaExists(uint256 materiaId) external view returns (bool) {
        return materiaDefinitionOf[materiaId].id != 0;
    }

    function isMateriaEnabled(uint256 materiaId) external view returns (bool) {
        return materiaDefinitionOf[materiaId].enabled;
    }

    function isMateriaUsable(
        uint256 materiaId,
        uint256 level
    ) external view returns (bool) {
        MateriaDefinition memory def = materiaDefinitionOf[materiaId];
        if (def.id == 0) return false;
        if (!def.enabled) return false;
        if (level == 0 || level > def.maxLevel) return false;
        return true;
    }

    function hasBonusesForLevel(
        uint256 materiaId,
        uint256 level
    ) external view returns (bool) {
        MateriaDefinition memory def = materiaDefinitionOf[materiaId];
        if (def.id == 0) return false;
        if (level == 0 || level > def.maxLevel) return false;

        BonusTypes.BonusSet memory b = materiaBonusesOf[materiaId][level];

        return (
            b.minDamageBonus != 0 ||
            b.maxDamageBonus != 0 ||
            b.attackSpeedBonus != 0 ||
            b.critChanceBpsBonus != 0 ||
            b.critMultiplierBpsBonus != 0 ||
            b.accuracyBpsBonus != 0 ||
            b.rangeBonus != 0 ||
            b.maxDurabilityBonus != 0 ||
            b.armorPenBpsBonus != 0 ||
            b.blockChanceBpsBonus != 0 ||
            b.lifeStealBpsBonus != 0 ||
            b.energyCostBonus != 0 ||
            b.heatGenerationBonus != 0 ||
            b.stabilityBonus != 0 ||
            b.cooldownMsBonus != 0 ||
            b.projectileSpeedBonus != 0 ||
            b.aoeRadiusBonus != 0 ||
            b.enchantmentSlotsBonus != 0 ||
            b.materiaSlotsBonus != 0
        );
    }

    function getMateriaMeta(
        uint256 materiaId
    )
        external
        view
        returns (
            string memory name,
            MateriaCategory category,
            MateriaElement element,
            uint256 rarityTier,
            uint256 maxLevel,
            bool enabled
        )
    {
        MateriaDefinition memory def = materiaDefinitionOf[materiaId];
        return (
            def.name,
            def.category,
            def.element,
            def.rarityTier,
            def.maxLevel,
            def.enabled
        );
    }
}