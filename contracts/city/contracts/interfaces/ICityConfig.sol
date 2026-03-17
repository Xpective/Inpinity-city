// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ICityConfig {
    function getAddressConfig(bytes32 key) external view returns (address);
    function getUintConfig(bytes32 key) external view returns (uint256);

    function KEY_INPINITY_NFT() external view returns (bytes32);
    function KEY_RESOURCE_TOKEN() external view returns (bytes32);
    function KEY_FARMING() external view returns (bytes32);
    function KEY_PIRATES() external view returns (bytes32);
    function KEY_MERCENARY() external view returns (bytes32);
    function KEY_PARTNERSHIP() external view returns (bytes32);
    function KEY_INPI() external view returns (bytes32);
    function KEY_PITRONE() external view returns (bytes32);
    function KEY_TREASURY() external view returns (bytes32);

    function KEY_MAX_PERSONAL_PLOTS() external view returns (bytes32);
    function KEY_INACTIVITY_DAYS() external view returns (bytes32);
    function KEY_DORMANT_THRESHOLD_DAYS() external view returns (bytes32);
    function KEY_DECAYED_THRESHOLD_DAYS() external view returns (bytes32);
    function KEY_LAYER_ELIGIBLE_THRESHOLD_DAYS() external view returns (bytes32);

    function KEY_PERSONAL_WIDTH() external view returns (bytes32);
    function KEY_PERSONAL_HEIGHT() external view returns (bytes32);
    function KEY_COMMUNITY_WIDTH() external view returns (bytes32);
    function KEY_COMMUNITY_HEIGHT() external view returns (bytes32);

    function KEY_QUBIQ_OIL_COST() external view returns (bytes32);
    function KEY_QUBIQ_LEMONS_COST() external view returns (bytes32);
    function KEY_QUBIQ_IRON_COST() external view returns (bytes32);

    function KEY_BUILDING_OIL_COST() external view returns (bytes32);
    function KEY_BUILDING_LEMONS_COST() external view returns (bytes32);
    function KEY_BUILDING_IRON_COST() external view returns (bytes32);
    function KEY_BUILDING_GOLD_COST() external view returns (bytes32);

    function KEY_INITIAL_FEE_BPS() external view returns (bytes32);
}