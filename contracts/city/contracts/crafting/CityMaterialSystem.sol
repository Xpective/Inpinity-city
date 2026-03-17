// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/CityErrors.sol";
import "../interfaces/ICityMateriaItems.sol";
import "./CityWeapons.sol";
import "./CityWeaponSockets.sol";

contract CityMateriaSystem is Ownable {
    CityWeapons public immutable cityWeapons;
    CityWeaponSockets public immutable cityWeaponSockets;
    ICityMateriaItems public immutable cityMateriaItems;

    mapping(address => bool) public authorizedCallers;

    event AuthorizedCallerSet(address indexed caller, bool allowed);

    event MateriaItemApplied(
        address indexed user,
        uint256 indexed weaponTokenId,
        uint256 indexed materiaItemId,
        uint256 slotIndex,
        uint256 materiaDefinitionId,
        uint256 level,
        bool burned
    );

    constructor(
        address initialOwner,
        address cityWeaponsAddress,
        address cityWeaponSocketsAddress,
        address cityMateriaItemsAddress
    ) Ownable(initialOwner) {
        if (
            initialOwner == address(0) ||
            cityWeaponsAddress == address(0) ||
            cityWeaponSocketsAddress == address(0) ||
            cityMateriaItemsAddress == address(0)
        ) {
            revert CityErrors.ZeroAddress();
        }

        cityWeapons = CityWeapons(cityWeaponsAddress);
        cityWeaponSockets = CityWeaponSockets(cityWeaponSocketsAddress);
        cityMateriaItems = ICityMateriaItems(cityMateriaItemsAddress);
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

    function applyMateriaItem(
        uint256 weaponTokenId,
        uint256 slotIndex,
        uint256 materiaItemId
    ) external {
        if (cityWeapons.ownerOf(weaponTokenId) != msg.sender) {
            revert CityErrors.NotPlotOwner();
        }

        (
            uint256 materiaDefinitionId,
            uint256 level,
            ,
            bool burnOnUse,
            bool enabled
        ) = cityMateriaItems.getMateriaItemMeta(materiaItemId);

        if (!enabled) revert CityErrors.InvalidValue();
        if (materiaDefinitionId == 0 || level == 0) revert CityErrors.InvalidValue();

        if (burnOnUse) {
            cityMateriaItems.burnMateriaItem(msg.sender, materiaItemId, 1);
        }

        cityWeaponSockets.attachMateria(
            weaponTokenId,
            slotIndex,
            materiaDefinitionId,
            level
        );

        emit MateriaItemApplied(
            msg.sender,
            weaponTokenId,
            materiaItemId,
            slotIndex,
            materiaDefinitionId,
            level,
            burnOnUse
        );
    }

    function adminApplyMateriaItem(
        address user,
        uint256 weaponTokenId,
        uint256 slotIndex,
        uint256 materiaItemId
    ) external onlyAuthorized {
        if (user == address(0)) revert CityErrors.ZeroAddress();
        if (cityWeapons.ownerOf(weaponTokenId) != user) {
            revert CityErrors.NotPlotOwner();
        }

        (
            uint256 materiaDefinitionId,
            uint256 level,
            ,
            bool burnOnUse,
            bool enabled
        ) = cityMateriaItems.getMateriaItemMeta(materiaItemId);

        if (!enabled) revert CityErrors.InvalidValue();
        if (materiaDefinitionId == 0 || level == 0) revert CityErrors.InvalidValue();

        if (burnOnUse) {
            cityMateriaItems.burnMateriaItem(user, materiaItemId, 1);
        }

        cityWeaponSockets.attachMateria(
            weaponTokenId,
            slotIndex,
            materiaDefinitionId,
            level
        );

        emit MateriaItemApplied(
            user,
            weaponTokenId,
            materiaItemId,
            slotIndex,
            materiaDefinitionId,
            level,
            burnOnUse
        );
    }

    function removeMateriaFromSlot(
        uint256 weaponTokenId,
        uint256 slotIndex
    ) external {
        if (cityWeapons.ownerOf(weaponTokenId) != msg.sender) {
            revert CityErrors.NotPlotOwner();
        }

        cityWeaponSockets.removeMateria(weaponTokenId, slotIndex);
    }

    function adminRemoveMateriaFromSlot(
        uint256 weaponTokenId,
        uint256 slotIndex
    ) external onlyAuthorized {
        cityWeaponSockets.removeMateria(weaponTokenId, slotIndex);
    }
}