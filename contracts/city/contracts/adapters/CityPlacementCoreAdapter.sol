// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

import "../../interfaces/buildings/ICityPlacementCoreAdapter.sol";

interface ICityRegistryLike {
    function ownerOfPlot(uint256 plotId) external view returns (address);
    function isPersonalPlot(uint256 plotId) external view returns (bool);
}

interface ICityLandLike {
    function isPlotFullyCompleted(uint256 plotId) external view returns (bool);
}

interface ICityStatusLike {
    function isPlotEligibleForBuilding(uint256 plotId) external view returns (bool);
}

interface ICityDistrictsLike {
    function districtKindOfPlot(uint256 plotId) external view returns (uint8);
    function factionOfPlot(uint256 plotId) external view returns (uint8);
}

interface ICityValidationLike {
    function isDistrictAllowedForPersonalBuilding(
        uint256 plotId,
        uint8 buildingType
    ) external view returns (bool);

    function isFactionAllowedForPersonalBuilding(
        address user,
        uint256 plotId,
        uint8 buildingType
    ) external view returns (bool);
}

/// @title CityPlacementCoreAdapter
/// @notice Adapter that normalizes reads from City core contracts for placement policy.
/// @dev Replace only this adapter if core signatures evolve.
contract CityPlacementCoreAdapter is ICityPlacementCoreAdapter, AccessControl, Pausable {
    bytes32 public constant ADAPTER_ADMIN_ROLE = keccak256("ADAPTER_ADMIN_ROLE");

    error ZeroAddress();

    event CoreContractsSet(
        address indexed registry,
        address indexed land,
        address indexed status,
        address districts,
        address validation,
        address executor
    );

    address public cityRegistry;
    address public cityLand;
    address public cityStatus;
    address public cityDistricts;
    address public cityValidation;

    constructor(
        address registry_,
        address land_,
        address status_,
        address districts_,
        address validation_,
        address admin_
    ) {
        if (
            registry_ == address(0) ||
            land_ == address(0) ||
            status_ == address(0) ||
            districts_ == address(0) ||
            validation_ == address(0) ||
            admin_ == address(0)
        ) revert ZeroAddress();

        cityRegistry = registry_;
        cityLand = land_;
        cityStatus = status_;
        cityDistricts = districts_;
        cityValidation = validation_;

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADAPTER_ADMIN_ROLE, admin_);
    }

    function pause() external onlyRole(ADAPTER_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADAPTER_ADMIN_ROLE) {
        _unpause();
    }

    function setCoreContracts(
        address registry_,
        address land_,
        address status_,
        address districts_,
        address validation_
    ) external onlyRole(ADAPTER_ADMIN_ROLE) {
        if (
            registry_ == address(0) ||
            land_ == address(0) ||
            status_ == address(0) ||
            districts_ == address(0) ||
            validation_ == address(0)
        ) revert ZeroAddress();

        cityRegistry = registry_;
        cityLand = land_;
        cityStatus = status_;
        cityDistricts = districts_;
        cityValidation = validation_;

        emit CoreContractsSet(
            registry_,
            land_,
            status_,
            districts_,
            validation_,
            msg.sender
        );
    }

    function isPersonalPlot(uint256 plotId) external view whenNotPaused returns (bool) {
        return ICityRegistryLike(cityRegistry).isPersonalPlot(plotId);
    }

    function isPlotOwner(address user, uint256 plotId) external view whenNotPaused returns (bool) {
        return ICityRegistryLike(cityRegistry).ownerOfPlot(plotId) == user;
    }

    function isPlotCompleted(uint256 plotId) external view whenNotPaused returns (bool) {
        return ICityLandLike(cityLand).isPlotFullyCompleted(plotId);
    }

    function isPlotEligibleForPlacement(uint256 plotId) external view whenNotPaused returns (bool) {
        return ICityStatusLike(cityStatus).isPlotEligibleForBuilding(plotId);
    }

    function isDistrictAllowedForPersonalBuilding(
        uint256 plotId,
        uint8 buildingType
    ) external view whenNotPaused returns (bool) {
        return ICityValidationLike(cityValidation).isDistrictAllowedForPersonalBuilding(
            plotId,
            buildingType
        );
    }

    function isFactionAllowedForPersonalBuilding(
        address user,
        uint256 plotId,
        uint8 buildingType
    ) external view whenNotPaused returns (bool) {
        return ICityValidationLike(cityValidation).isFactionAllowedForPersonalBuilding(
            user,
            plotId,
            buildingType
        );
    }

    function getPlotFaction(uint256 plotId) external view whenNotPaused returns (uint8) {
        return ICityDistrictsLike(cityDistricts).factionOfPlot(plotId);
    }

    function getPlotDistrictKind(uint256 plotId) external view whenNotPaused returns (uint8) {
        return ICityDistrictsLike(cityDistricts).districtKindOfPlot(plotId);
    }

    function getPlotOwner(uint256 plotId) external view whenNotPaused returns (address) {
        return ICityRegistryLike(cityRegistry).ownerOfPlot(plotId);
    }
}