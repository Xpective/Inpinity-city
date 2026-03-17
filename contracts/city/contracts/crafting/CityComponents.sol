// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/CityErrors.sol";

contract CityComponents is Ownable {
    enum ComponentCategory {
        None,
        Core,
        Barrel,
        Blade,
        Grip,
        Scope,
        EnergyCell,
        Frame,
        Catalyst,
        MateriaSocket
    }

    enum ElementType {
        None,
        Fire,
        Water,
        Ice,
        Lightning,
        Earth,
        Crystal,
        Shadow,
        Light,
        Aether
    }

    struct ComponentDefinition {
        uint256 id;
        string name;
        ComponentCategory category;
        ElementType element;
        uint256 rarityTier;
        uint256 techTier;
        uint256 familyId;
        uint256 powerScore;
        bool enabled;
    }

    mapping(uint256 => ComponentDefinition) public componentOf;
    mapping(address => bool) public authorizedCallers;

    event AuthorizedCallerSet(address indexed caller, bool allowed);

    event ComponentSet(
        uint256 indexed componentId,
        string name,
        ComponentCategory category,
        ElementType element,
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

    function setComponent(
        uint256 componentId,
        string calldata name,
        ComponentCategory category,
        ElementType element,
        uint256 rarityTier,
        uint256 techTier,
        uint256 familyId,
        uint256 powerScore,
        bool enabled
    ) external onlyAuthorized {
        if (componentId == 0) revert CityErrors.InvalidValue();
        if (bytes(name).length == 0) revert CityErrors.InvalidValue();
        if (category == ComponentCategory.None) revert CityErrors.InvalidValue();

        componentOf[componentId] = ComponentDefinition({
            id: componentId,
            name: name,
            category: category,
            element: element,
            rarityTier: rarityTier,
            techTier: techTier,
            familyId: familyId,
            powerScore: powerScore,
            enabled: enabled
        });

        emit ComponentSet(
            componentId,
            name,
            category,
            element,
            rarityTier,
            techTier,
            enabled
        );
    }

    function getComponent(uint256 componentId) external view returns (ComponentDefinition memory) {
        return componentOf[componentId];
    }
}