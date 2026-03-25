/* FILE: contracts/city/contracts/adapters/CityPlotStatusAdapter.sol */
/* TYPE: plot status adapter — NOT NFT, NOT PersonalBuildings */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/ICityStatusLike.sol";

contract CityPlotStatusAdapter is AccessControl {
    bytes32 public constant ADAPTER_ADMIN_ROLE = keccak256("ADAPTER_ADMIN_ROLE");

    error ZeroAddress();
    error InvalidStatus();

    event StatusSet(address indexed status, address indexed executor);
    event DerivedStatusCodesSet(
        uint8 dormantCode,
        uint8 decayedCode,
        address indexed executor
    );

    ICityStatusLike public status;

    uint8 public dormantStatusCode = 2;
    uint8 public decayedStatusCode = 3;

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

    function setDerivedStatusCodes(
        uint8 dormantCode_,
        uint8 decayedCode_
    ) external onlyRole(ADAPTER_ADMIN_ROLE) {
        dormantStatusCode = dormantCode_;
        decayedStatusCode = decayedCode_;

        emit DerivedStatusCodesSet(dormantCode_, decayedCode_, msg.sender);
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
        uint8 derived = status.getDerivedStatus(plotId);

        dormant = derived == dormantStatusCode;
        decayed = derived == decayedStatusCode;
        layerEligible = status.isLayerEligible(plotId);
    }
}