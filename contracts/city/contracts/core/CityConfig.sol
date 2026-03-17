// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/CityErrors.sol";
import "../libraries/CityEvents.sol";

contract CityConfig is Ownable {
    mapping(bytes32 => address) private _addressConfig;
    mapping(bytes32 => uint256) private _uintConfig;

    bytes32 public constant KEY_INPINITY_NFT = keccak256("INPINITY_NFT");
    bytes32 public constant KEY_RESOURCE_TOKEN = keccak256("RESOURCE_TOKEN");
    bytes32 public constant KEY_FARMING = keccak256("FARMING");
    bytes32 public constant KEY_PIRATES = keccak256("PIRATES");
    bytes32 public constant KEY_MERCENARY = keccak256("MERCENARY");
    bytes32 public constant KEY_PARTNERSHIP = keccak256("PARTNERSHIP");
    bytes32 public constant KEY_INPI = keccak256("INPI");
    bytes32 public constant KEY_PITRONE = keccak256("PITRONE");
    bytes32 public constant KEY_TREASURY = keccak256("TREASURY");

    bytes32 public constant KEY_MAX_PERSONAL_PLOTS = keccak256("MAX_PERSONAL_PLOTS");
    bytes32 public constant KEY_INACTIVITY_DAYS = keccak256("INACTIVITY_DAYS");
    bytes32 public constant KEY_PERSONAL_WIDTH = keccak256("PERSONAL_WIDTH");
    bytes32 public constant KEY_PERSONAL_HEIGHT = keccak256("PERSONAL_HEIGHT");
    bytes32 public constant KEY_COMMUNITY_WIDTH = keccak256("COMMUNITY_WIDTH");
    bytes32 public constant KEY_COMMUNITY_HEIGHT = keccak256("COMMUNITY_HEIGHT");

    bytes32 public constant KEY_QUBIQ_OIL_COST = keccak256("QUBIQ_OIL_COST");
    bytes32 public constant KEY_QUBIQ_LEMONS_COST = keccak256("QUBIQ_LEMONS_COST");
    bytes32 public constant KEY_QUBIQ_IRON_COST = keccak256("QUBIQ_IRON_COST");


    bytes32 public constant KEY_BUILDING_OIL_COST = keccak256("BUILDING_OIL_COST");
    bytes32 public constant KEY_BUILDING_LEMONS_COST = keccak256("BUILDING_LEMONS_COST");
    bytes32 public constant KEY_BUILDING_IRON_COST = keccak256("BUILDING_IRON_COST");
    bytes32 public constant KEY_BUILDING_GOLD_COST = keccak256("BUILDING_GOLD_COST");

    bytes32 public constant KEY_INITIAL_FEE_BPS = keccak256("INITIAL_FEE_BPS");
    bytes32 public constant KEY_DORMANT_THRESHOLD_DAYS = keccak256("DORMANT_THRESHOLD_DAYS");
    bytes32 public constant KEY_DECAYED_THRESHOLD_DAYS = keccak256("DECAYED_THRESHOLD_DAYS");
    bytes32 public constant KEY_LAYER_ELIGIBLE_THRESHOLD_DAYS = keccak256("LAYER_ELIGIBLE_THRESHOLD_DAYS");
    
    constructor(address initialOwner) Ownable(initialOwner) {
        if (initialOwner == address(0)) revert CityErrors.ZeroAddress();
        emit CityEvents.ConfigInitialized(initialOwner);
    }

    function setAddressConfig(bytes32 key, address value) external onlyOwner {
        if (value == address(0)) revert CityErrors.ZeroAddress();
        _addressConfig[key] = value;
        emit CityEvents.CoreAddressSet(key, value);
    }

    function setUintConfig(bytes32 key, uint256 value) external onlyOwner {
        if (value == 0) revert CityErrors.InvalidValue();
        _uintConfig[key] = value;
        emit CityEvents.UintConfigSet(key, value);
    }

    function getAddressConfig(bytes32 key) external view returns (address) {
        return _addressConfig[key];
    }

    function getUintConfig(bytes32 key) external view returns (uint256) {
        return _uintConfig[key];
    }
}