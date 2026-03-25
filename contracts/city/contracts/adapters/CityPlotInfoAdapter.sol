/* FILE: contracts/city/contracts/adapters/CityPlotInfoAdapter.sol */
/* TYPE: plot info adapter — NOT NFT, NOT PersonalBuildings */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";

import "./interfaces/ICityRegistryLike.sol";
import "./interfaces/ICityLandLike.sol";
import "./interfaces/ICityDistrictsLike.sol";

contract CityPlotInfoAdapter is AccessControl {
    bytes32 public constant ADAPTER_ADMIN_ROLE = keccak256("ADAPTER_ADMIN_ROLE");

    error ZeroAddress();
    error InvalidRegistry();
    error InvalidLand();
    error InvalidDistricts();

    event RegistrySet(address indexed registry, address indexed executor);
    event LandSet(address indexed land, address indexed executor);
    event DistrictsSet(address indexed districts, address indexed executor);

    ICityRegistryLike public registry;
    ICityLandLike public land;
    ICityDistrictsLike public districts;

    uint8 internal constant PLOT_TYPE_PERSONAL = 1;

    constructor(
        address registry_,
        address land_,
        address districts_,
        address admin_
    ) {
        if (
            registry_ == address(0) ||
            land_ == address(0) ||
            districts_ == address(0) ||
            admin_ == address(0)
        ) revert ZeroAddress();

        if (registry_.code.length == 0) revert InvalidRegistry();
        if (land_.code.length == 0) revert InvalidLand();
        if (districts_.code.length == 0) revert InvalidDistricts();

        registry = ICityRegistryLike(registry_);
        land = ICityLandLike(land_);
        districts = ICityDistrictsLike(districts_);

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADAPTER_ADMIN_ROLE, admin_);
    }

    function setRegistry(address registry_) external onlyRole(ADAPTER_ADMIN_ROLE) {
        if (registry_ == address(0)) revert ZeroAddress();
        if (registry_.code.length == 0) revert InvalidRegistry();

        registry = ICityRegistryLike(registry_);
        emit RegistrySet(registry_, msg.sender);
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
        ICityRegistryLike.PlotCore memory core = registry.getPlotCore(plotId);
        ICityDistrictsLike.DistrictData memory district = districts.getDistrict(plotId);

        exists = core.exists;
        completed = exists && land.isPlotFullyCompleted(plotId);
        personalPlot = exists && core.plotType == PLOT_TYPE_PERSONAL;
        districtKind = district.kind;
        faction = core.faction;
    }
}