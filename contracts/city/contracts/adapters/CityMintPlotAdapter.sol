/* FILE: contracts/city/contracts/adapters/CityMintPlotAdapter.sol */
/* TYPE: mint plot adapter — NOT NFT, NOT PersonalBuildings */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";

import "./interfaces/ICityRegistryLike.sol";
import "./interfaces/ICityLandLike.sol";
import "./interfaces/ICityDistrictsLike.sol";

/// @title CityMintPlotAdapter
/// @notice Adapter for player-facing personal building mint checks.
/// @dev Reads live city plot data and returns normalized mint-eligibility info.
contract CityMintPlotAdapter is AccessControl {
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

    function getMintPlotInfo(
        uint256 plotId
    )
        external
        view
        returns (
            address owner,
            bool exists,
            bool completed,
            bool personalPlot,
            bool eligible,
            uint8 districtKind,
            uint8 faction
        )
    {
        ICityRegistryLike.PlotCore memory core = registry.getPlotCore(plotId);
        ICityDistrictsLike.DistrictData memory district = districts.getDistrict(plotId);

        exists = core.exists;
        if (!exists) {
            return (address(0), false, false, false, false, 0, 0);
        }

        owner = core.owner;
        personalPlot = core.plotType == PLOT_TYPE_PERSONAL;
        completed = land.isPlotFullyCompleted(plotId);

        eligible = personalPlot && completed;

        districtKind = district.kind;
        faction = core.faction;
    }
}