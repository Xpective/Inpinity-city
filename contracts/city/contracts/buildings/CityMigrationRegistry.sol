/* FILE: contracts/city/contracts/buildings/CityMigrationRegistry.sol */
/* TYPE: migration endpoint registry / V2 prep utility — NOT gameplay runtime */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/// @title CityMigrationRegistry
/// @notice Central source/target registry for Personal / Community / Borderline / Nexus V2 preparation.
/// @dev Keeps migration wiring separate from gameplay contracts so source and target endpoints can be
///      coordinated before a cutover. Endpoints can be cleared by setting them to address(0).
contract CityMigrationRegistry is AccessControl, Pausable {
    bytes32 public constant REGISTRY_ADMIN_ROLE = keccak256("REGISTRY_ADMIN_ROLE");

    bytes32 public constant KEY_PERSONAL_BUILDING_NFT = keccak256("CITY_PERSONAL_BUILDING_NFT");
    bytes32 public constant KEY_PERSONAL_BUILDING_PLACEMENT = keccak256("CITY_PERSONAL_BUILDING_PLACEMENT");
    bytes32 public constant KEY_PERSONAL_BUILDINGS_LOGIC = keccak256("CITY_PERSONAL_BUILDINGS_LOGIC");
    bytes32 public constant KEY_COLLECTIVE_BUILDING_NFT = keccak256("CITY_COLLECTIVE_BUILDING_NFT");
    bytes32 public constant KEY_COMMUNITY_BUILDINGS = keccak256("CITY_COMMUNITY_BUILDINGS");
    bytes32 public constant KEY_BORDERLINE_BUILDINGS = keccak256("CITY_BORDERLINE_BUILDINGS");
    bytes32 public constant KEY_NEXUS_BUILDINGS = keccak256("CITY_NEXUS_BUILDINGS");
    bytes32 public constant KEY_NEXUS_PORTAL = keccak256("CITY_NEXUS_PORTAL");
    bytes32 public constant KEY_NEXUS_DUNGEON = keccak256("CITY_NEXUS_DUNGEON");
    bytes32 public constant KEY_NEXUS_REWARD_ROUTER = keccak256("CITY_NEXUS_REWARD_ROUTER");
    bytes32 public constant KEY_NEXUS_PERMIT_REGISTRY = keccak256("CITY_NEXUS_PERMIT_REGISTRY");

    error ZeroAddressAdmin();
    error InvalidEndpoint(bytes32 key, address endpoint);
    error BatchLengthMismatch();

    event MigrationEndpointSet(
        bytes32 indexed key,
        address indexed endpoint,
        bool indexed targetSide,
        address executor
    );

    mapping(bytes32 => address) public sourceOf;
    mapping(bytes32 => address) public targetV2Of;

    constructor(address admin_) {
        if (admin_ == address(0)) revert ZeroAddressAdmin();
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(REGISTRY_ADMIN_ROLE, admin_);
    }

    function pause() external onlyRole(REGISTRY_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(REGISTRY_ADMIN_ROLE) {
        _unpause();
    }

    function setSource(bytes32 key, address endpoint) external onlyRole(REGISTRY_ADMIN_ROLE) {
        _validateEndpoint(key, endpoint);
        sourceOf[key] = endpoint;
        emit MigrationEndpointSet(key, endpoint, false, msg.sender);
    }

    function setTargetV2(bytes32 key, address endpoint) external onlyRole(REGISTRY_ADMIN_ROLE) {
        _validateEndpoint(key, endpoint);
        targetV2Of[key] = endpoint;
        emit MigrationEndpointSet(key, endpoint, true, msg.sender);
    }

    function batchSetSources(
        bytes32[] calldata keys,
        address[] calldata endpoints
    ) external onlyRole(REGISTRY_ADMIN_ROLE) {
        if (keys.length != endpoints.length) revert BatchLengthMismatch();
        for (uint256 i = 0; i < keys.length; ++i) {
            _validateEndpoint(keys[i], endpoints[i]);
            sourceOf[keys[i]] = endpoints[i];
            emit MigrationEndpointSet(keys[i], endpoints[i], false, msg.sender);
        }
    }

    function batchSetTargetsV2(
        bytes32[] calldata keys,
        address[] calldata endpoints
    ) external onlyRole(REGISTRY_ADMIN_ROLE) {
        if (keys.length != endpoints.length) revert BatchLengthMismatch();
        for (uint256 i = 0; i < keys.length; ++i) {
            _validateEndpoint(keys[i], endpoints[i]);
            targetV2Of[keys[i]] = endpoints[i];
            emit MigrationEndpointSet(keys[i], endpoints[i], true, msg.sender);
        }
    }

    function getEndpointPair(bytes32 key) external view returns (address source, address targetV2) {
        return (sourceOf[key], targetV2Of[key]);
    }

    function allKnownKeys() external pure returns (bytes32[11] memory keys) {
        keys[0] = KEY_PERSONAL_BUILDING_NFT;
        keys[1] = KEY_PERSONAL_BUILDING_PLACEMENT;
        keys[2] = KEY_PERSONAL_BUILDINGS_LOGIC;
        keys[3] = KEY_COLLECTIVE_BUILDING_NFT;
        keys[4] = KEY_COMMUNITY_BUILDINGS;
        keys[5] = KEY_BORDERLINE_BUILDINGS;
        keys[6] = KEY_NEXUS_BUILDINGS;
        keys[7] = KEY_NEXUS_PORTAL;
        keys[8] = KEY_NEXUS_DUNGEON;
        keys[9] = KEY_NEXUS_REWARD_ROUTER;
        keys[10] = KEY_NEXUS_PERMIT_REGISTRY;
    }

    function _validateEndpoint(bytes32 key, address endpoint) internal view {
        if (endpoint == address(0)) {
            return;
        }
        if (endpoint.code.length == 0) revert InvalidEndpoint(key, endpoint);
    }
}
