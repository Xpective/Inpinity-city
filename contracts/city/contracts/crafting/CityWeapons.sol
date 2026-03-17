// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../libraries/CityErrors.sol";
import "../interfaces/ICityWeaponSockets.sol";

contract CityWeapons is ERC721, Ownable {
    using Strings for uint256;

    enum WeaponClass {
        None,
        Sword,
        Axe,
        Spear,
        Bow,
        Pistol,
        Rifle,
        LaserPistol,
        LaserRifle,
        PlasmaRifle,
        LaserBlade,
        Railgun,
        EnergyStaff,
        CrystalBow,
        Relic
    }

    enum DamageType {
        None,
        Physical,
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

    enum ResonanceType {
        None,
        Pi,
        Phi,
        Borderline
    }

    struct WeaponDefinition {
        uint256 id;
        string name;
        WeaponClass class;
        DamageType damageType;

        uint256 techTier;
        uint256 requiredLevel;
        uint256 requiredTechTier;

        uint256 minDamage;
        uint256 maxDamage;
        uint256 attackSpeed;
        uint256 critChanceBps;
        uint256 critMultiplierBps;
        uint256 accuracyBps;
        uint256 range;

        uint256 maxDurability;
        uint256 armorPenBps;
        uint256 blockChanceBps;
        uint256 lifeStealBps;
        uint256 energyCost;
        uint256 heatGeneration;
        uint256 stability;
        uint256 cooldownMs;
        uint256 projectileSpeed;
        uint256 aoeRadius;

        uint256 enchantmentSlots;
        uint256 materiaSlots;
        uint256 visualVariant;
        uint256 maxUpgradeLevel;
        uint256 familySetId;

        bool enabled;
    }

    struct WeaponInstance {
        uint256 tokenId;
        uint256 weaponDefinitionId;

        uint256 rarityTier;
        uint256 frameTier;
        uint256 durability;
        uint256 upgradeLevel;
        uint256 metadataRevision;

        uint256 originPlotId;
        uint256 originFaction;
        uint256 originDistrictKind;
        uint256 craftedAt;
        uint256 visualVariant;

        ResonanceType resonanceType;

        bytes32 craftSeed;
        bytes32 provenanceHash;

        bool genesisEra;
        bool usedAether;
    }

    struct WeaponBonuses {
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

    struct CombatProfile {
        uint256 minDamage;
        uint256 maxDamage;
        uint256 attackSpeed;
        uint256 baseDps;
        uint256 critChanceBps;
        uint256 critMultiplierBps;
        uint256 accuracyBps;
        uint256 range;
        uint256 durability;
        uint256 maxDurability;
        uint256 armorPenBps;
        uint256 blockChanceBps;
        uint256 lifeStealBps;
        uint256 energyCost;
        uint256 heatGeneration;
        uint256 stability;
        uint256 cooldownMs;
        uint256 projectileSpeed;
        uint256 aoeRadius;
        uint256 enchantmentSlots;
        uint256 materiaSlots;
        uint256 upgradeLevel;
        uint256 maxUpgradeLevel;
    }

    string public baseTokenURI;
    uint256 public nextTokenId = 1;

    mapping(uint256 => WeaponDefinition) public weaponDefinitionOf;
    mapping(uint256 => WeaponInstance) public weaponInstanceOf;
    mapping(uint256 => WeaponBonuses) public weaponBonusesOf;
    mapping(address => bool) public authorizedMinters;

    ICityWeaponSockets public cityWeaponSockets;

    event AuthorizedMinterSet(address indexed minter, bool allowed);
    event BaseURISet(string newBaseURI);
    event WeaponSocketsSet(address indexed weaponSockets);

    event WeaponDefinitionSet(
        uint256 indexed weaponDefinitionId,
        string name,
        WeaponClass class,
        DamageType damageType,
        uint256 techTier,
        bool enabled
    );

    event WeaponMinted(
        uint256 indexed tokenId,
        address indexed to,
        uint256 indexed weaponDefinitionId,
        bytes32 craftSeed,
        bytes32 provenanceHash
    );

    event WeaponMetadataRevisionSet(uint256 indexed tokenId, uint256 metadataRevision);
    event WeaponUpgradeLevelSet(uint256 indexed tokenId, uint256 upgradeLevel);
    event WeaponDurabilitySet(uint256 indexed tokenId, uint256 durability);
    event WeaponBonusesSet(uint256 indexed tokenId);

    constructor(address initialOwner)
        ERC721("Inpinity City Weapons", "ICW")
        Ownable(initialOwner)
    {
        if (initialOwner == address(0)) revert CityErrors.ZeroAddress();
    }

    modifier onlyAuthorizedMinter() {
        if (!(msg.sender == owner() || authorizedMinters[msg.sender])) {
            revert CityErrors.NotAuthorized();
        }
        _;
    }

    function setAuthorizedMinter(address minter, bool allowed) external onlyOwner {
        if (minter == address(0)) revert CityErrors.ZeroAddress();
        authorizedMinters[minter] = allowed;
        emit AuthorizedMinterSet(minter, allowed);
    }

    function setBaseURI(string calldata newBaseTokenURI) external onlyOwner {
        baseTokenURI = newBaseTokenURI;
        emit BaseURISet(newBaseTokenURI);
    }

    function setWeaponSockets(address weaponSocketsAddress) external onlyOwner {
        if (weaponSocketsAddress == address(0)) revert CityErrors.ZeroAddress();
        cityWeaponSockets = ICityWeaponSockets(weaponSocketsAddress);
        emit WeaponSocketsSet(weaponSocketsAddress);
    }

    function setWeaponDefinition(
        uint256 weaponDefinitionId,
        string calldata name,
        WeaponClass class,
        DamageType damageType,
        uint256 techTier,
        uint256 requiredLevel,
        uint256 requiredTechTier,
        uint256 minDamage,
        uint256 maxDamage,
        uint256 attackSpeed,
        uint256 critChanceBps,
        uint256 critMultiplierBps,
        uint256 accuracyBps,
        uint256 range,
        uint256 maxDurability,
        uint256 armorPenBps,
        uint256 blockChanceBps,
        uint256 lifeStealBps,
        uint256 energyCost,
        uint256 heatGeneration,
        uint256 stability,
        uint256 cooldownMs,
        uint256 projectileSpeed,
        uint256 aoeRadius,
        uint256 enchantmentSlots,
        uint256 materiaSlots,
        uint256 visualVariant,
        uint256 maxUpgradeLevel,
        uint256 familySetId,
        bool enabled
    ) external onlyOwner {
        if (weaponDefinitionId == 0) revert CityErrors.InvalidValue();
        if (bytes(name).length == 0) revert CityErrors.InvalidValue();
        if (class == WeaponClass.None) revert CityErrors.InvalidValue();
        if (damageType == DamageType.None) revert CityErrors.InvalidValue();
        if (maxDamage < minDamage) revert CityErrors.InvalidValue();
        if (maxDurability == 0) revert CityErrors.InvalidValue();

        weaponDefinitionOf[weaponDefinitionId] = WeaponDefinition({
            id: weaponDefinitionId,
            name: name,
            class: class,
            damageType: damageType,
            techTier: techTier,
            requiredLevel: requiredLevel,
            requiredTechTier: requiredTechTier,
            minDamage: minDamage,
            maxDamage: maxDamage,
            attackSpeed: attackSpeed,
            critChanceBps: critChanceBps,
            critMultiplierBps: critMultiplierBps,
            accuracyBps: accuracyBps,
            range: range,
            maxDurability: maxDurability,
            armorPenBps: armorPenBps,
            blockChanceBps: blockChanceBps,
            lifeStealBps: lifeStealBps,
            energyCost: energyCost,
            heatGeneration: heatGeneration,
            stability: stability,
            cooldownMs: cooldownMs,
            projectileSpeed: projectileSpeed,
            aoeRadius: aoeRadius,
            enchantmentSlots: enchantmentSlots,
            materiaSlots: materiaSlots,
            visualVariant: visualVariant,
            maxUpgradeLevel: maxUpgradeLevel,
            familySetId: familySetId,
            enabled: enabled
        });

        emit WeaponDefinitionSet(
            weaponDefinitionId,
            name,
            class,
            damageType,
            techTier,
            enabled
        );
    }

    function mintWeapon(
        address to,
        uint256 weaponDefinitionId,
        uint256 rarityTier,
        uint256 frameTier,
        uint256 originPlotId,
        uint256 originFaction,
        uint256 originDistrictKind,
        ResonanceType resonanceType,
        uint256 visualVariant,
        bool genesisEra,
        bool usedAether,
        uint256 nonce
    ) external onlyAuthorizedMinter returns (uint256 tokenId) {
        if (to == address(0)) revert CityErrors.ZeroAddress();

        WeaponDefinition memory def = weaponDefinitionOf[weaponDefinitionId];
        if (def.id == 0 || !def.enabled) revert CityErrors.InvalidValue();

        tokenId = nextTokenId++;
        _safeMint(to, tokenId);

        uint256 resolvedVisualVariant = visualVariant == 0 ? def.visualVariant : visualVariant;

        bytes32 craftSeed = computeCraftSeed(
            to,
            weaponDefinitionId,
            originPlotId,
            originFaction,
            originDistrictKind,
            uint256(resonanceType),
            nonce
        );

        bytes32 provenanceHash = computeProvenanceHash(
            weaponDefinitionId,
            rarityTier,
            frameTier,
            uint256(resonanceType),
            resolvedVisualVariant,
            craftSeed,
            originPlotId,
            0
        );

        weaponInstanceOf[tokenId] = WeaponInstance({
            tokenId: tokenId,
            weaponDefinitionId: weaponDefinitionId,
            rarityTier: rarityTier,
            frameTier: frameTier,
            durability: def.maxDurability,
            upgradeLevel: 0,
            metadataRevision: 1,
            originPlotId: originPlotId,
            originFaction: originFaction,
            originDistrictKind: originDistrictKind,
            craftedAt: block.timestamp,
            visualVariant: resolvedVisualVariant,
            resonanceType: resonanceType,
            craftSeed: craftSeed,
            provenanceHash: provenanceHash,
            genesisEra: genesisEra,
            usedAether: usedAether
        });

        emit WeaponMinted(tokenId, to, weaponDefinitionId, craftSeed, provenanceHash);
    }

    function setMetadataRevision(uint256 tokenId, uint256 metadataRevision) external onlyOwner {
        _requireMinted(tokenId);
        weaponInstanceOf[tokenId].metadataRevision = metadataRevision;
        emit WeaponMetadataRevisionSet(tokenId, metadataRevision);
    }

    function setUpgradeLevel(uint256 tokenId, uint256 upgradeLevel) external onlyAuthorizedMinter {
        _requireMinted(tokenId);

        WeaponInstance storage inst = weaponInstanceOf[tokenId];
        WeaponDefinition memory def = weaponDefinitionOf[inst.weaponDefinitionId];

        if (upgradeLevel > def.maxUpgradeLevel) revert CityErrors.InvalidValue();

        inst.upgradeLevel = upgradeLevel;
        _refreshProvenanceHash(tokenId);

        emit WeaponUpgradeLevelSet(tokenId, upgradeLevel);
    }

    function setDurability(uint256 tokenId, uint256 durability) external onlyAuthorizedMinter {
        _requireMinted(tokenId);

        WeaponInstance storage inst = weaponInstanceOf[tokenId];
        uint256 maxDurability = _toUint256(
            int256(weaponDefinitionOf[inst.weaponDefinitionId].maxDurability) +
            weaponBonusesOf[tokenId].maxDurabilityBonus
        );

        if (durability > maxDurability) revert CityErrors.InvalidValue();

        inst.durability = durability;
        emit WeaponDurabilitySet(tokenId, durability);
    }

    function setWeaponBonuses(
        uint256 tokenId,
        WeaponBonuses calldata bonuses
    ) external onlyAuthorizedMinter {
        _requireMinted(tokenId);

        weaponBonusesOf[tokenId] = bonuses;
        _refreshProvenanceHash(tokenId);

        emit WeaponBonusesSet(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireMinted(tokenId);
        return string(abi.encodePacked(baseTokenURI, tokenId.toString(), ".json"));
    }

    function getWeaponStats(uint256 tokenId)
        external
        view
        returns (
            WeaponDefinition memory def,
            WeaponInstance memory inst,
            WeaponBonuses memory bonuses
        )
    {
        _requireMinted(tokenId);
        inst = weaponInstanceOf[tokenId];
        def = weaponDefinitionOf[inst.weaponDefinitionId];
        bonuses = weaponBonusesOf[tokenId];
    }

    function getCombatProfile(uint256 tokenId) external view returns (CombatProfile memory profile) {
        _requireMinted(tokenId);

        WeaponInstance memory inst = weaponInstanceOf[tokenId];
        WeaponDefinition memory def = weaponDefinitionOf[inst.weaponDefinitionId];
        WeaponBonuses memory b = weaponBonusesOf[tokenId];

        uint256 minDamage = _toUint256(int256(def.minDamage) + b.minDamageBonus);
        uint256 maxDamage = _toUint256(int256(def.maxDamage) + b.maxDamageBonus);
        if (maxDamage < minDamage) revert CityErrors.InvalidValue();

        uint256 attackSpeed = _toUint256(int256(def.attackSpeed) + b.attackSpeedBonus);
        uint256 critChanceBps = _toUint256(int256(def.critChanceBps) + b.critChanceBpsBonus);
        uint256 critMultiplierBps = _toUint256(int256(def.critMultiplierBps) + b.critMultiplierBpsBonus);
        uint256 accuracyBps = _toUint256(int256(def.accuracyBps) + b.accuracyBpsBonus);
        uint256 range = _toUint256(int256(def.range) + b.rangeBonus);
        uint256 maxDurability = _toUint256(int256(def.maxDurability) + b.maxDurabilityBonus);
        uint256 armorPenBps = _toUint256(int256(def.armorPenBps) + b.armorPenBpsBonus);
        uint256 blockChanceBps = _toUint256(int256(def.blockChanceBps) + b.blockChanceBpsBonus);
        uint256 lifeStealBps = _toUint256(int256(def.lifeStealBps) + b.lifeStealBpsBonus);
        uint256 energyCost = _toUint256(int256(def.energyCost) + b.energyCostBonus);
        uint256 heatGeneration = _toUint256(int256(def.heatGeneration) + b.heatGenerationBonus);
        uint256 stability = _toUint256(int256(def.stability) + b.stabilityBonus);
        uint256 cooldownMs = _toUint256(int256(def.cooldownMs) + b.cooldownMsBonus);
        uint256 projectileSpeed = _toUint256(int256(def.projectileSpeed) + b.projectileSpeedBonus);
        uint256 aoeRadius = _toUint256(int256(def.aoeRadius) + b.aoeRadiusBonus);
        uint256 enchantmentSlots = _toUint256(int256(def.enchantmentSlots) + b.enchantmentSlotsBonus);
        uint256 materiaSlots = _toUint256(int256(def.materiaSlots) + b.materiaSlotsBonus);

        uint256 avgDamage = (minDamage + maxDamage) / 2;
        uint256 baseDps = avgDamage * attackSpeed;

        profile = CombatProfile({
            minDamage: minDamage,
            maxDamage: maxDamage,
            attackSpeed: attackSpeed,
            baseDps: baseDps,
            critChanceBps: critChanceBps,
            critMultiplierBps: critMultiplierBps,
            accuracyBps: accuracyBps,
            range: range,
            durability: inst.durability,
            maxDurability: maxDurability,
            armorPenBps: armorPenBps,
            blockChanceBps: blockChanceBps,
            lifeStealBps: lifeStealBps,
            energyCost: energyCost,
            heatGeneration: heatGeneration,
            stability: stability,
            cooldownMs: cooldownMs,
            projectileSpeed: projectileSpeed,
            aoeRadius: aoeRadius,
            enchantmentSlots: enchantmentSlots,
            materiaSlots: materiaSlots,
            upgradeLevel: inst.upgradeLevel,
            maxUpgradeLevel: def.maxUpgradeLevel
        });
    }

    function getEffectiveCombatProfile(uint256 tokenId) external view returns (CombatProfile memory profile) {
        _requireMinted(tokenId);

        WeaponInstance memory inst = weaponInstanceOf[tokenId];
        WeaponDefinition memory def = weaponDefinitionOf[inst.weaponDefinitionId];
        WeaponBonuses memory localBonuses = weaponBonusesOf[tokenId];
        ICityWeaponSockets.TotalBonuses memory socketBonuses;

        if (address(cityWeaponSockets) != address(0)) {
            socketBonuses = cityWeaponSockets.getTotalBonuses(tokenId);
        }

        uint256 minDamage = _toUint256(
            int256(def.minDamage)
                + localBonuses.minDamageBonus
                + socketBonuses.minDamageBonus
        );

        uint256 maxDamage = _toUint256(
            int256(def.maxDamage)
                + localBonuses.maxDamageBonus
                + socketBonuses.maxDamageBonus
        );

        if (maxDamage < minDamage) revert CityErrors.InvalidValue();

        uint256 attackSpeed = _toUint256(
            int256(def.attackSpeed)
                + localBonuses.attackSpeedBonus
                + socketBonuses.attackSpeedBonus
        );

        uint256 critChanceBps = _toUint256(
            int256(def.critChanceBps)
                + localBonuses.critChanceBpsBonus
                + socketBonuses.critChanceBpsBonus
        );

        uint256 critMultiplierBps = _toUint256(
            int256(def.critMultiplierBps)
                + localBonuses.critMultiplierBpsBonus
                + socketBonuses.critMultiplierBpsBonus
        );

        uint256 accuracyBps = _toUint256(
            int256(def.accuracyBps)
                + localBonuses.accuracyBpsBonus
                + socketBonuses.accuracyBpsBonus
        );

        uint256 range = _toUint256(
            int256(def.range)
                + localBonuses.rangeBonus
                + socketBonuses.rangeBonus
        );

        uint256 maxDurability = _toUint256(
            int256(def.maxDurability)
                + localBonuses.maxDurabilityBonus
                + socketBonuses.maxDurabilityBonus
        );

        uint256 armorPenBps = _toUint256(
            int256(def.armorPenBps)
                + localBonuses.armorPenBpsBonus
                + socketBonuses.armorPenBpsBonus
        );

        uint256 blockChanceBps = _toUint256(
            int256(def.blockChanceBps)
                + localBonuses.blockChanceBpsBonus
                + socketBonuses.blockChanceBpsBonus
        );

        uint256 lifeStealBps = _toUint256(
            int256(def.lifeStealBps)
                + localBonuses.lifeStealBpsBonus
                + socketBonuses.lifeStealBpsBonus
        );

        uint256 energyCost = _toUint256(
            int256(def.energyCost)
                + localBonuses.energyCostBonus
                + socketBonuses.energyCostBonus
        );

        uint256 heatGeneration = _toUint256(
            int256(def.heatGeneration)
                + localBonuses.heatGenerationBonus
                + socketBonuses.heatGenerationBonus
        );

        uint256 stability = _toUint256(
            int256(def.stability)
                + localBonuses.stabilityBonus
                + socketBonuses.stabilityBonus
        );

        uint256 cooldownMs = _toUint256(
            int256(def.cooldownMs)
                + localBonuses.cooldownMsBonus
                + socketBonuses.cooldownMsBonus
        );

        uint256 projectileSpeed = _toUint256(
            int256(def.projectileSpeed)
                + localBonuses.projectileSpeedBonus
                + socketBonuses.projectileSpeedBonus
        );

        uint256 aoeRadius = _toUint256(
            int256(def.aoeRadius)
                + localBonuses.aoeRadiusBonus
                + socketBonuses.aoeRadiusBonus
        );

        uint256 enchantmentSlots = _toUint256(
            int256(def.enchantmentSlots)
                + localBonuses.enchantmentSlotsBonus
                + socketBonuses.enchantmentSlotsBonus
        );

        uint256 materiaSlots = _toUint256(
            int256(def.materiaSlots)
                + localBonuses.materiaSlotsBonus
                + socketBonuses.materiaSlotsBonus
        );

        uint256 avgDamage = (minDamage + maxDamage) / 2;
        uint256 baseDps = avgDamage * attackSpeed;

        profile = CombatProfile({
            minDamage: minDamage,
            maxDamage: maxDamage,
            attackSpeed: attackSpeed,
            baseDps: baseDps,
            critChanceBps: critChanceBps,
            critMultiplierBps: critMultiplierBps,
            accuracyBps: accuracyBps,
            range: range,
            durability: inst.durability,
            maxDurability: maxDurability,
            armorPenBps: armorPenBps,
            blockChanceBps: blockChanceBps,
            lifeStealBps: lifeStealBps,
            energyCost: energyCost,
            heatGeneration: heatGeneration,
            stability: stability,
            cooldownMs: cooldownMs,
            projectileSpeed: projectileSpeed,
            aoeRadius: aoeRadius,
            enchantmentSlots: enchantmentSlots,
            materiaSlots: materiaSlots,
            upgradeLevel: inst.upgradeLevel,
            maxUpgradeLevel: def.maxUpgradeLevel
        });
    }

    function computeCraftSeed(
        address crafter,
        uint256 weaponDefinitionId,
        uint256 originPlotId,
        uint256 originFaction,
        uint256 originDistrictKind,
        uint256 resonanceType,
        uint256 nonce
    ) public view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                crafter,
                weaponDefinitionId,
                originPlotId,
                originFaction,
                originDistrictKind,
                resonanceType,
                block.timestamp,
                nonce
            )
        );
    }

    function computeProvenanceHash(
        uint256 weaponDefinitionId,
        uint256 rarityTier,
        uint256 frameTier,
        uint256 resonanceType,
        uint256 visualVariant,
        bytes32 craftSeed,
        uint256 originPlotId,
        uint256 upgradeLevel
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                weaponDefinitionId,
                rarityTier,
                frameTier,
                resonanceType,
                visualVariant,
                craftSeed,
                originPlotId,
                upgradeLevel
            )
        );
    }

    function _refreshProvenanceHash(uint256 tokenId) internal {
        WeaponInstance storage inst = weaponInstanceOf[tokenId];
        inst.provenanceHash = computeProvenanceHash(
            inst.weaponDefinitionId,
            inst.rarityTier,
            inst.frameTier,
            uint256(inst.resonanceType),
            inst.visualVariant,
            inst.craftSeed,
            inst.originPlotId,
            inst.upgradeLevel
        );
    }

    function _requireMinted(uint256 tokenId) internal view {
        if (_ownerOf(tokenId) == address(0)) revert CityErrors.InvalidValue();
    }

    function _toUint256(int256 value) internal pure returns (uint256) {
        return value < 0 ? 0 : uint256(value);
    }
}