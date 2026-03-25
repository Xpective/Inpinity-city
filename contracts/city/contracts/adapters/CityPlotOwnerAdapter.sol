/* FILE: contracts/city/contracts/adapters/CityPlotOwnerAdapter.sol */
/* TYPE: plot owner adapter — NOT NFT, NOT PersonalBuildings */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/ICityRegistryLike.sol";

contract CityPlotOwnerAdapter is AccessControl {
    bytes32 public constant ADAPTER_ADMIN_ROLE = keccak256("ADAPTER_ADMIN_ROLE");

    error ZeroAddress();
    error InvalidRegistry();

    event RegistrySet(address indexed registry, address indexed executor);

    ICityRegistryLike public registry;

    constructor(address registry_, address admin_) {
        if (registry_ == address(0) || admin_ == address(0)) revert ZeroAddress();
        if (registry_.code.length == 0) revert InvalidRegistry();

        registry = ICityRegistryLike(registry_);

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADAPTER_ADMIN_ROLE, admin_);
    }

    function setRegistry(address registry_) external onlyRole(ADAPTER_ADMIN_ROLE) {
        if (registry_ == address(0)) revert ZeroAddress();
        if (registry_.code.length == 0) revert InvalidRegistry();

        registry = ICityRegistryLike(registry_);
        emit RegistrySet(registry_, msg.sender);
    }

    function getPlotOwner(uint256 plotId) external view returns (address owner) {
        ICityRegistryLike.PlotCore memory core = registry.getPlotCore(plotId);
        return core.owner;
    }
}