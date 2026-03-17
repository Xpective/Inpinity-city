// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/CityErrors.sol";

contract CityWeapons is Ownable {
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

    struct WeaponDefinition {
        uint256 id;
        string name;
        WeaponClass class;
        uint256 rarityTier;
        uint256 techTier;
        uint256 attackPower;
        uint256 durability;

        // Vorbereitung für FF7 / Enchant / Upgrades
        uint256 enchantmentSlots;
        uint256 materiaSlots;
        uint256 visualVariant;
        uint256 maxUpgradeLevel;

        bool enabled;
    }

    mapping(uint256 => WeaponDefinition) public weaponOf;
    mapping(address => bool) public authorizedCallers;

    event AuthorizedCallerSet(address indexed caller, bool allowed);

    event WeaponSet(
        uint256 indexed weaponId,
        string name,
        WeaponClass class,
        uint256 rarityTier,
        uint256 techTier,
        bool enabled
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

    function setWeapon(
        uint256 weaponId,
        string calldata name,
        WeaponClass class,
        uint256 rarityTier,
        uint256 techTier,
        uint256 attackPower,
        uint256 durability,
        uint256 enchantmentSlots,
        uint256 materiaSlots,
        uint256 visualVariant,
        uint256 maxUpgradeLevel,
        bool enabled
    ) external onlyAuthorized {
        if (weaponId == 0) revert CityErrors.InvalidValue();
        if (bytes(name).length == 0) revert CityErrors.InvalidValue();
        if (class == WeaponClass.None) revert CityErrors.InvalidValue();

        weaponOf[weaponId] = WeaponDefinition({
            id: weaponId,
            name: name,
            class: class,
            rarityTier: rarityTier,
            techTier: techTier,
            attackPower: attackPower,
            durability: durability,
            enchantmentSlots: enchantmentSlots,
            materiaSlots: materiaSlots,
            visualVariant: visualVariant,
            maxUpgradeLevel: maxUpgradeLevel,
            enabled: enabled
        });

        emit WeaponSet(
            weaponId,
            name,
            class,
            rarityTier,
            techTier,
            enabled
        );
    }

    function getWeapon(uint256 weaponId) external view returns (WeaponDefinition memory) {
        return weaponOf[weaponId];
    }
}