// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPitrone is IERC20 {
    function exchangeRate() external view returns (uint256);
    function exchangeINPI(uint256 inpiAmount) external;
    function exchangePitrone(uint256 pitroneAmount) external;
}

/// @title CityPitAdapter
/// @notice Collects PIT/Pitrone fees for PersonalBuildings logic.
/// @dev Admin config is separated from runtime caller authorization.
///      PersonalBuildings should receive CALLER_ROLE.
contract CityPitAdapter is AccessControl {
    bytes32 public constant ADAPTER_ADMIN_ROLE = keccak256("ADAPTER_ADMIN_ROLE");
    bytes32 public constant CALLER_ROLE = keccak256("CALLER_ROLE");

    error ZeroAddress();
    error InvalidPitroneContract();
    error TransferFailed();
    error TreasuryNotSet();

    event PitroneTokenSet(address indexed token, address indexed executor);
    event TreasurySet(address indexed treasury, address indexed executor);
    event PitFeeCollected(
        address indexed caller,
        address indexed from,
        address indexed treasury,
        uint256 amount,
        bytes32 reason
    );

    IPitrone public pitroneToken;
    address public treasury;

    constructor(address pitroneToken_, address treasury_, address admin_) {
        if (pitroneToken_ == address(0) || admin_ == address(0)) revert ZeroAddress();
        if (pitroneToken_.code.length == 0) revert InvalidPitroneContract();

        pitroneToken = IPitrone(pitroneToken_);
        treasury = treasury_;

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADAPTER_ADMIN_ROLE, admin_);
    }

    function setPitroneToken(address pitroneToken_) external onlyRole(ADAPTER_ADMIN_ROLE) {
        if (pitroneToken_ == address(0)) revert ZeroAddress();
        if (pitroneToken_.code.length == 0) revert InvalidPitroneContract();

        pitroneToken = IPitrone(pitroneToken_);
        emit PitroneTokenSet(pitroneToken_, msg.sender);
    }

    function setTreasury(address treasury_) external onlyRole(ADAPTER_ADMIN_ROLE) {
        if (treasury_ == address(0)) revert ZeroAddress();

        treasury = treasury_;
        emit TreasurySet(treasury_, msg.sender);
    }

    /// @notice Collects PIT fee from a user and routes it to treasury.
    /// @dev Caller must be trusted game logic, e.g. PersonalBuildings.
    function collectPitFee(
        address from,
        uint256 amount,
        bytes32 reason
    ) external onlyRole(CALLER_ROLE) {
        if (from == address(0)) revert ZeroAddress();
        if (treasury == address(0)) revert TreasuryNotSet();
        if (amount == 0) return;

        bool success = pitroneToken.transferFrom(from, treasury, amount);
        if (!success) revert TransferFailed();

        emit PitFeeCollected(msg.sender, from, treasury, amount, reason);
    }
}