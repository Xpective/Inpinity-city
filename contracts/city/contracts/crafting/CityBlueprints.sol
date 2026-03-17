// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/CityErrors.sol";

contract CityBlueprints is Ownable {
    struct BlueprintDefinition {
        uint256 id;
        string name;

        // v1-Komponentenlogik
        uint256 requiredCore;
        uint256 requiredFrame;
        uint256 requiredGrip;
        uint256 requiredBarrelOrBlade;

        // Output
        uint256 outputWeaponType;
        uint256 rarityTier;
        uint256 techTier;

        // Requirements
        uint256 requiredFaction;      // 0 none, 1 Inpinity, 2 Inphinity, 3 Borderline/Neutral
        uint256 requiredDistrictKind; // 0 none
        bool requiresDiscovery;
        bool enabled;
    }

    mapping(uint256 => BlueprintDefinition) public blueprintOf;
    mapping(address => bool) public authorizedCallers;
    mapping(address => mapping(uint256 => bool)) public discoveredBy;

    event AuthorizedCallerSet(address indexed caller, bool allowed);
    event BlueprintDiscovered(address indexed user, uint256 indexed blueprintId);

    event BlueprintSet(
        uint256 indexed blueprintId,
        string name,
        uint256 outputWeaponType,
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

    function discoverBlueprint(address user, uint256 blueprintId) external onlyAuthorized {
        if (user == address(0)) revert CityErrors.ZeroAddress();
        if (blueprintOf[blueprintId].id == 0) revert CityErrors.InvalidValue();

        discoveredBy[user][blueprintId] = true;
        emit BlueprintDiscovered(user, blueprintId);
    }

    function setBlueprint(
        uint256 blueprintId,
        string calldata name,
        uint256 requiredCore,
        uint256 requiredFrame,
        uint256 requiredGrip,
        uint256 requiredBarrelOrBlade,
        uint256 outputWeaponType,
        uint256 rarityTier,
        uint256 techTier,
        uint256 requiredFaction,
        uint256 requiredDistrictKind,
        bool requiresDiscovery,
        bool enabled
    ) external onlyAuthorized {
        if (blueprintId == 0) revert CityErrors.InvalidValue();
        if (bytes(name).length == 0) revert CityErrors.InvalidValue();

        blueprintOf[blueprintId] = BlueprintDefinition({
            id: blueprintId,
            name: name,
            requiredCore: requiredCore,
            requiredFrame: requiredFrame,
            requiredGrip: requiredGrip,
            requiredBarrelOrBlade: requiredBarrelOrBlade,
            outputWeaponType: outputWeaponType,
            rarityTier: rarityTier,
            techTier: techTier,
            requiredFaction: requiredFaction,
            requiredDistrictKind: requiredDistrictKind,
            requiresDiscovery: requiresDiscovery,
            enabled: enabled
        });

        emit BlueprintSet(
            blueprintId,
            name,
            outputWeaponType,
            rarityTier,
            techTier,
            enabled
        );
    }

    function getBlueprint(uint256 blueprintId) external view returns (BlueprintDefinition memory) {
        return blueprintOf[blueprintId];
    }
}