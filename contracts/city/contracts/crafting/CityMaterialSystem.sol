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
    bool public materiaSystemPaused;

    event AuthorizedCallerSet(address indexed caller, bool allowed);
    event MateriaSystemPausedSet(bool paused);

    event MateriaItemApplied(
        address indexed user,
        uint256 indexed weaponTokenId,
        uint256 indexed materiaItemId,
        uint256 slotIndex,
        uint256 materiaDefinitionId,
        uint256 level,
        bool burned
    );

    event MateriaRemovedBySystem(
        address indexed user,
        uint256 indexed weaponTokenId,
        uint256 indexed slotIndex
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

    modifier whenMateriaSystemNotPaused() {
        if (materiaSystemPaused) revert CityErrors.InvalidValue();
        _;
    }

    function setAuthorizedCaller(address caller, bool allowed) external onlyOwner {
        if (caller == address(0)) revert CityErrors.ZeroAddress();
        authorizedCallers[caller] = allowed;
        emit AuthorizedCallerSet(caller, allowed);
    }

    function setMateriaSystemPaused(bool paused) external onlyOwner {
        materiaSystemPaused = paused;
        emit MateriaSystemPausedSet(paused);
    }

    function applyMateriaItem(
        uint256 weaponTokenId,
        uint256 slotIndex,
        uint256 materiaItemId
    ) external whenMateriaSystemNotPaused {
        _requireWeaponOwner(weaponTokenId, msg.sender);

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
    ) external onlyAuthorized whenMateriaSystemNotPaused {
        if (user == address(0)) revert CityErrors.ZeroAddress();
        _requireWeaponOwner(weaponTokenId, user);

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
    ) external whenMateriaSystemNotPaused {
        _requireWeaponOwner(weaponTokenId, msg.sender);

        cityWeaponSockets.removeMateria(weaponTokenId, slotIndex);

        emit MateriaRemovedBySystem(msg.sender, weaponTokenId, slotIndex);
    }

    function adminRemoveMateriaFromSlot(
        uint256 weaponTokenId,
        uint256 slotIndex
    ) external onlyAuthorized whenMateriaSystemNotPaused {
        address owner = cityWeapons.ownerOf(weaponTokenId);

        cityWeaponSockets.removeMateria(weaponTokenId, slotIndex);

        emit MateriaRemovedBySystem(owner, weaponTokenId, slotIndex);
    }

    function _requireWeaponOwner(uint256 weaponTokenId, address expectedOwner) internal view {
        if (cityWeapons.ownerOf(weaponTokenId) != expectedOwner) {
            revert CityErrors.NotPlotOwner();
        }
    }
}