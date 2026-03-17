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

    event AuthorizedCallerSet(address indexed caller, bool allowed);

    event EnchantmentItemApplied(
        address indexed user,
        uint256 indexed weaponTokenId,
        uint256 indexed enchantmentItemId,
        uint256 slotIndex,
        uint256 enchantmentDefinitionId,
        uint256 level,
        bool burned
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

    function setAuthorizedCaller(address caller, bool allowed) external onlyOwner {
        if (caller == address(0)) revert CityErrors.ZeroAddress();
        authorizedCallers[caller] = allowed;
        emit AuthorizedCallerSet(caller, allowed);
    }

    function applyEnchantmentItem(
        uint256 weaponTokenId,
        uint256 slotIndex,
        uint256 enchantmentItemId
    ) external {
        if (cityWeapons.ownerOf(weaponTokenId) != msg.sender) {
            revert CityErrors.NotPlotOwner();
        }

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
    ) external onlyAuthorized {
        if (user == address(0)) revert CityErrors.ZeroAddress();
        if (cityWeapons.ownerOf(weaponTokenId) != user) {
            revert CityErrors.NotPlotOwner();
        }

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
    ) external {
        if (cityWeapons.ownerOf(weaponTokenId) != msg.sender) {
            revert CityErrors.NotPlotOwner();
        }

        cityWeaponSockets.removeEnchantment(weaponTokenId, slotIndex);
    }

    function adminRemoveEnchantmentFromSlot(
        uint256 weaponTokenId,
        uint256 slotIndex
    ) external onlyAuthorized {
        cityWeaponSockets.removeEnchantment(weaponTokenId, slotIndex);
    }
}