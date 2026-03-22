// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/*//////////////////////////////////////////////////////////////
                         ROUTER INTERFACES
//////////////////////////////////////////////////////////////*/

/// @notice Common personal-placement policy interface used by CityBuildingPlacement.
interface ICityPersonalPlacementPolicy {
    function validatePersonalPlacement(
        address owner,
        uint256 plotId,
        uint256 buildingId
    )
        external
        view
        returns (
            bool allowed,
            bool ownerMatches,
            bool plotCompleted,
            bool plotEligible,
            bool personalPlot,
            bool districtAllowed,
            bool factionAllowed,
            bytes32 reasonCode
        );
}

/*//////////////////////////////////////////////////////////////
                    CITY BUILDING POLICY ROUTER
//////////////////////////////////////////////////////////////*/

/// @title CityBuildingPolicyRouter
/// @notice Shared router for building policy contracts across Personal / Community / Borderline / Nexus.
/// @dev V1 actively routes Personal placement validation.
///      Community / Borderline / Nexus hooks are intentionally pre-wired for later expansion.
contract CityBuildingPolicyRouter is AccessControl, Pausable {
    /*//////////////////////////////////////////////////////////////
                                 ROLES
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant ROUTER_ADMIN_ROLE = keccak256("ROUTER_ADMIN_ROLE");

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error InvalidPolicy();
    error PersonalPolicyNotSet();
    error RouterPaused();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event PersonalPlacementPolicySet(address indexed policy, address indexed executor);

    /// @notice Reserved for future phases.
    event CommunityPolicySet(address indexed policy, address indexed executor);
    event BorderlinePolicySet(address indexed policy, address indexed executor);
    event NexusPolicySet(address indexed policy, address indexed executor);

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Active policy for personal building placement.
    address public personalPlacementPolicy;

    /// @notice Reserved for future contracts.
    address public communityPolicy;
    address public borderlinePolicy;
    address public nexusPolicy;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address admin_) {
        if (admin_ == address(0)) revert ZeroAddress();

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ROUTER_ADMIN_ROLE, admin_);
    }

    /*//////////////////////////////////////////////////////////////
                               ADMIN
    //////////////////////////////////////////////////////////////*/

    function pause() external onlyRole(ROUTER_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ROUTER_ADMIN_ROLE) {
        _unpause();
    }

    function setPersonalPlacementPolicy(address policy_) external onlyRole(ROUTER_ADMIN_ROLE) {
        if (policy_ == address(0)) revert ZeroAddress();
        if (policy_.code.length == 0) revert InvalidPolicy();

        personalPlacementPolicy = policy_;
        emit PersonalPlacementPolicySet(policy_, msg.sender);
    }

    /// @dev Reserved for later integration.
    function setCommunityPolicy(address policy_) external onlyRole(ROUTER_ADMIN_ROLE) {
        if (policy_ != address(0) && policy_.code.length == 0) revert InvalidPolicy();
        communityPolicy = policy_;
        emit CommunityPolicySet(policy_, msg.sender);
    }

    /// @dev Reserved for later integration.
    function setBorderlinePolicy(address policy_) external onlyRole(ROUTER_ADMIN_ROLE) {
        if (policy_ != address(0) && policy_.code.length == 0) revert InvalidPolicy();
        borderlinePolicy = policy_;
        emit BorderlinePolicySet(policy_, msg.sender);
    }

    /// @dev Reserved for later integration.
    function setNexusPolicy(address policy_) external onlyRole(ROUTER_ADMIN_ROLE) {
        if (policy_ != address(0) && policy_.code.length == 0) revert InvalidPolicy();
        nexusPolicy = policy_;
        emit NexusPolicySet(policy_, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                         PERSONAL ROUTING
    //////////////////////////////////////////////////////////////*/

    /// @notice Called by CityBuildingPlacement for personal building validation.
    function validatePersonalPlacement(
        address owner,
        uint256 plotId,
        uint256 buildingId
    )
        external
        view
        returns (
            bool allowed,
            bool ownerMatches,
            bool plotCompleted,
            bool plotEligible,
            bool personalPlot,
            bool districtAllowed,
            bool factionAllowed,
            bytes32 reasonCode
        )
    {
        if (paused()) revert RouterPaused();
        if (personalPlacementPolicy == address(0)) revert PersonalPolicyNotSet();

        return ICityPersonalPlacementPolicy(personalPlacementPolicy).validatePersonalPlacement(
            owner,
            plotId,
            buildingId
        );
    }

    /*//////////////////////////////////////////////////////////////
                                  READS
    //////////////////////////////////////////////////////////////*/

    function getRouterSummary()
        external
        view
        returns (
            address personalPlacementPolicy_,
            address communityPolicy_,
            address borderlinePolicy_,
            address nexusPolicy_,
            bool paused_
        )
    {
        return (
            personalPlacementPolicy,
            communityPolicy,
            borderlinePolicy,
            nexusPolicy,
            paused()
        );
    }
}