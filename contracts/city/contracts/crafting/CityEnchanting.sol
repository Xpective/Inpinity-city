// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/CityErrors.sol";
import "../interfaces/ICityEnchantmentItems.sol";
import "./CityWeapons.sol";
import "./CityWeaponSockets.sol";

contract CityEnchanting is Ownable {
    CityWeapons public immutable cityWeapons;
    CityWeaponSockets public immutable cityWeaponSockets;
    ICityEnchantmentItems public immutable cityEnchantmentItems;

    mapping(address => bool) public authorizedCallers;
    bool public enchantingPaused;

    event AuthorizedCallerSet(address indexed caller, bool allowed);
    event EnchantingPausedSet(bool paused);

    event EnchantmentItemApplied(
        address indexed user,
        uint256 indexed weaponTokenId,
        uint256 indexed enchantmentItemId,
        uint256 slotIndex,
        uint256 enchantmentDefinitionId,
        uint256 level,
        bool burned
    );

    event EnchantmentRemovedBySystem(
        address indexed user,
        uint256 indexed weaponTokenId,
        uint256 indexed slotIndex
    );

    constructor(
        address initialOwner,
        address cityWeaponsAddress,
        address cityWeaponSocketsAddress,
        address cityEnchantmentItemsAddress
    ) Ownable(initialOwner) {
        if (
            initialOwner == address(0) ||
            cityWeaponsAddress == address(0) ||
            cityWeaponSocketsAddress == address(0) ||
            cityEnchantmentItemsAddress == address(0)
        ) {
            revert CityErrors.ZeroAddress();
        }

        cityWeapons = CityWeapons(cityWeaponsAddress);
        cityWeaponSockets = CityWeaponSockets(cityWeaponSocketsAddress);
        cityEnchantmentItems = ICityEnchantmentItems(cityEnchantmentItemsAddress);
    }

    modifier onlyAuthorized() {
        if (!(msg.sender == owner() || authorizedCallers[msg.sender])) {
            revert CityErrors.NotAuthorized();
        }
        _;
    }

    modifier whenEnchantingNotPaused() {
        if (enchantingPaused) revert CityErrors.InvalidValue();
        _;
    }

    function setAuthorizedCaller(address caller, bool allowed) external onlyOwner {
        if (caller == address(0)) revert CityErrors.ZeroAddress();
        authorizedCallers[caller] = allowed;
        emit AuthorizedCallerSet(caller, allowed);
    }

    function setEnchantingPaused(bool paused) external onlyOwner {
        enchantingPaused = paused;
        emit EnchantingPausedSet(paused);
    }

    function applyEnchantmentItem(
        uint256 weaponTokenId,
        uint256 slotIndex,
        uint256 enchantmentItemId
    ) external whenEnchantingNotPaused {
        _requireWeaponOwner(weaponTokenId, msg.sender);

        (
            uint256 enchantmentDefinitionId,
            uint256 level,
            ,
            bool burnOnUse,
            bool enabled
        ) = cityEnchantmentItems.getEnchantmentItemMeta(enchantmentItemId);

        if (!enabled) revert CityErrors.InvalidValue();
        if (enchantmentDefinitionId == 0 || level == 0) revert CityErrors.InvalidValue();

        if (burnOnUse) {
            cityEnchantmentItems.burnEnchantmentItem(msg.sender, enchantmentItemId, 1);
        }

        cityWeaponSockets.attachEnchantment(
            weaponTokenId,
            slotIndex,
            enchantmentDefinitionId,
            level
        );

        emit EnchantmentItemApplied(
            msg.sender,
            weaponTokenId,
            enchantmentItemId,
            slotIndex,
            enchantmentDefinitionId,
            level,
            burnOnUse
        );
    }

    function adminApplyEnchantmentItem(
        address user,
        uint256 weaponTokenId,
        uint256 slotIndex,
        uint256 enchantmentItemId
    ) external onlyAuthorized whenEnchantingNotPaused {
        if (user == address(0)) revert CityErrors.ZeroAddress();
        _requireWeaponOwner(weaponTokenId, user);

        (
            uint256 enchantmentDefinitionId,
            uint256 level,
            ,
            bool burnOnUse,
            bool enabled
        ) = cityEnchantmentItems.getEnchantmentItemMeta(enchantmentItemId);

        if (!enabled) revert CityErrors.InvalidValue();
        if (enchantmentDefinitionId == 0 || level == 0) revert CityErrors.InvalidValue();

        if (burnOnUse) {
            cityEnchantmentItems.burnEnchantmentItem(user, enchantmentItemId, 1);
        }

        cityWeaponSockets.attachEnchantment(
            weaponTokenId,
            slotIndex,
            enchantmentDefinitionId,
            level
        );

        emit EnchantmentItemApplied(
            user,
            weaponTokenId,
            enchantmentItemId,
            slotIndex,
            enchantmentDefinitionId,
            level,
            burnOnUse
        );
    }

    function removeEnchantmentFromSlot(
        uint256 weaponTokenId,
        uint256 slotIndex
    ) external whenEnchantingNotPaused {
        _requireWeaponOwner(weaponTokenId, msg.sender);

        cityWeaponSockets.removeEnchantment(weaponTokenId, slotIndex);

        emit EnchantmentRemovedBySystem(msg.sender, weaponTokenId, slotIndex);
    }

    function adminRemoveEnchantmentFromSlot(
        uint256 weaponTokenId,
        uint256 slotIndex
    ) external onlyAuthorized whenEnchantingNotPaused {
        address owner = cityWeapons.ownerOf(weaponTokenId);

        cityWeaponSockets.removeEnchantment(weaponTokenId, slotIndex);

        emit EnchantmentRemovedBySystem(owner, weaponTokenId, slotIndex);
    }

    function _requireWeaponOwner(uint256 weaponTokenId, address expectedOwner) internal view {
        if (cityWeapons.ownerOf(weaponTokenId) != expectedOwner) {
            revert CityErrors.NotPlotOwner();
        }
    }
}