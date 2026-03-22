// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface IResourceToken is IERC1155 {
    function burn(address from, uint256 id, uint256 amount) external;
}

/// @title CityResourceAdapter
/// @notice Burns resource bundles from the live ResourceToken contract for PersonalBuildings logic.
/// @dev Admin config is separated from runtime caller authorization.
///      PersonalBuildings should receive CALLER_ROLE.
contract CityResourceAdapter is AccessControl {
    bytes32 public constant ADAPTER_ADMIN_ROLE = keccak256("ADAPTER_ADMIN_ROLE");
    bytes32 public constant CALLER_ROLE = keccak256("CALLER_ROLE");

    uint256 public constant RESOURCE_SLOT_COUNT = 10;

    error ZeroAddress();
    error InvalidResourceToken();
    error BurnFailed(uint256 resourceId, uint256 amount);
    error ArrayLengthMismatch();

    event ResourceTokenSet(address indexed token, address indexed executor);
    event ResourceBundleBurned(
        address indexed caller,
        address indexed from,
        bytes32 indexed reason,
        uint256 totalEntries
    );

    IResourceToken public resourceToken;

    constructor(address resourceToken_, address admin_) {
        if (resourceToken_ == address(0) || admin_ == address(0)) revert ZeroAddress();
        if (resourceToken_.code.length == 0) revert InvalidResourceToken();

        resourceToken = IResourceToken(resourceToken_);

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADAPTER_ADMIN_ROLE, admin_);
    }

    function setResourceToken(address resourceToken_) external onlyRole(ADAPTER_ADMIN_ROLE) {
        if (resourceToken_ == address(0)) revert ZeroAddress();
        if (resourceToken_.code.length == 0) revert InvalidResourceToken();

        resourceToken = IResourceToken(resourceToken_);
        emit ResourceTokenSet(resourceToken_, msg.sender);
    }

    /// @notice Burns the standard 10-slot resource bundle from a user wallet.
    /// @dev Caller must be trusted game logic, e.g. PersonalBuildings.
    function burnResourceBundle(
        address from,
        uint256[RESOURCE_SLOT_COUNT] calldata amounts,
        bytes32 reason
    ) external onlyRole(CALLER_ROLE) {
        if (from == address(0)) revert ZeroAddress();

        uint256 nonZeroEntries = 0;

        for (uint256 i = 0; i < RESOURCE_SLOT_COUNT; i++) {
            uint256 amount = amounts[i];
            if (amount == 0) continue;

            nonZeroEntries++;

            try resourceToken.burn(from, i, amount) {
                // success
            } catch {
                revert BurnFailed(i, amount);
            }
        }

        emit ResourceBundleBurned(msg.sender, from, reason, nonZeroEntries);
    }
}