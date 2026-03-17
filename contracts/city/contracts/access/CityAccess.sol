// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/CityErrors.sol";

abstract contract CityAccess is Ownable {
    mapping(bytes32 => mapping(address => bool)) internal _roleMembers;

    event RoleAccessSet(bytes32 indexed role, address indexed account, bool allowed);

    constructor(address initialOwner) Ownable(initialOwner) {
        if (initialOwner == address(0)) revert CityErrors.ZeroAddress();
    }

    modifier onlyRole(bytes32 role) {
        if (!(msg.sender == owner() || _roleMembers[role][msg.sender])) {
            revert CityErrors.NotPlotOwner();
        }
        _;
    }

    function setRoleAccess(bytes32 role, address account, bool allowed) external onlyOwner {
        if (account == address(0)) revert CityErrors.ZeroAddress();
        _roleMembers[role][account] = allowed;
        emit RoleAccessSet(role, account, allowed);
    }

    function hasRoleAccess(bytes32 role, address account) external view returns (bool) {
        return account == owner() || _roleMembers[role][account];
    }
}