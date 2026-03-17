// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library CityRoles {
    bytes32 internal constant ROLE_REGISTRY = keccak256("ROLE_REGISTRY");
    bytes32 internal constant ROLE_LAND = keccak256("ROLE_LAND");
    bytes32 internal constant ROLE_STATUS = keccak256("ROLE_STATUS");
    bytes32 internal constant ROLE_HISTORY = keccak256("ROLE_HISTORY");
    bytes32 internal constant ROLE_DISTRICTS = keccak256("ROLE_DISTRICTS");
    bytes32 internal constant ROLE_BUILDINGS = keccak256("ROLE_BUILDINGS");
    bytes32 internal constant ROLE_CROWDFUNDING = keccak256("ROLE_CROWDFUNDING");
    bytes32 internal constant ROLE_MARKETPLACE = keccak256("ROLE_MARKETPLACE");
    bytes32 internal constant ROLE_CRAFTING = keccak256("ROLE_CRAFTING");
}