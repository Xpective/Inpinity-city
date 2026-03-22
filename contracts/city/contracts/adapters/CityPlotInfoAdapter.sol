// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";

import "./interfaces/ICityLandLike.sol";
import "./interfaces/ICityDistrictsLike.sol";

contract CityPlotInfoAdapter is AccessControl {
    bytes32 public constant ADAPTER_ADMIN_ROLE = keccak256("ADAPTER_ADMIN_ROLE");

    error ZeroAddress();
    error InvalidLand();
    error InvalidDistricts();

    event LandSet(address indexed land, address indexed executor);
    event DistrictsSet(address indexed districts, address indexed executor);

    ICityLandLike public land;
    ICityDistrictsLike public districts;

    constructor(address land_, address districts_, address admin_) {
        if (land_ == address(0) || districts_ == address(0) || admin_ == address(0)) {
            revert ZeroAddress();
        }
        if (land_.code.length == 0) revert InvalidLand();
        if (districts_.code.length == 0) revert InvalidDistricts();

        land = ICityLandLike(land_);
        districts = ICityDistrictsLike(districts_);

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADAPTER_ADMIN_ROLE, admin_);
    }

    function setLand(address land_) external onlyRole(ADAPTER_ADMIN_ROLE) {
        if (land_ == address(0)) revert ZeroAddress();
        if (land_.code.length == 0) revert InvalidLand();

        land = ICityLandLike(land_);
        emit LandSet(land_, msg.sender);
    }

    function setDistricts(address districts_) external onlyRole(ADAPTER_ADMIN_ROLE) {
        if (districts_ == address(0)) revert ZeroAddress();
        if (districts_.code.length == 0) revert InvalidDistricts();

        districts = ICityDistrictsLike(districts_);
        emit DistrictsSet(districts_, msg.sender);
    }

    function getPlotPlacementInfo(
        uint256 plotId
    )
        external
        view
        returns (
            bool exists,
            bool completed,
            bool personalPlot,
            uint8 districtKind,
            uint8 faction
        )
    {
        exists = districts.plotExists(plotId);
        completed = land.isPlotFullyCompleted(plotId);
        personalPlot = districts.isPersonalPlot(plotId);
        districtKind = districts.getPlotDistrictKind(plotId);
        faction = districts.getPlotFaction(plotId);
    }
}