// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/ICityStatusLike.sol";

contract CityPlotStatusAdapter is AccessControl {
    bytes32 public constant ADAPTER_ADMIN_ROLE = keccak256("ADAPTER_ADMIN_ROLE");

    error ZeroAddress();
    error InvalidStatus();

    event StatusSet(address indexed status, address indexed executor);

    ICityStatusLike public status;

    constructor(address status_, address admin_) {
        if (status_ == address(0) || admin_ == address(0)) revert ZeroAddress();
        if (status_.code.length == 0) revert InvalidStatus();

        status = ICityStatusLike(status_);
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADAPTER_ADMIN_ROLE, admin_);
    }

    function setStatus(address status_) external onlyRole(ADAPTER_ADMIN_ROLE) {
        if (status_ == address(0)) revert ZeroAddress();
        if (status_.code.length == 0) revert InvalidStatus();

        status = ICityStatusLike(status_);
        emit StatusSet(status_, msg.sender);
    }

    function getPlotStatusFlags(
        uint256 plotId
    )
        external
        view
        returns (
            bool dormant,
            bool decayed,
            bool layerEligible
        )
    {
        dormant = status.isPlotDormant(plotId);
        decayed = status.isPlotDecayed(plotId);
        layerEligible = status.isPlotLayerEligibleBlocked(plotId);
    }
}