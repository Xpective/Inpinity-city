/* FILE: contracts/city/contracts/adapters/CityPlacementCoreAdapter.sol */
/* TYPE: live-core aligned placement adapter — NOT NFT, NOT PersonalBuildings */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

import "../interfaces/ICityPlacementCoreAdapter.sol";
import "./interfaces/ICityRegistryLike.sol";
import "./interfaces/ICityLandLike.sol";
import "./interfaces/ICityDistrictsLike.sol";
import "./interfaces/ICityStatusLike.sol";

/*//////////////////////////////////////////////////////////////
                    OPTIONAL VALIDATION INTERFACE
//////////////////////////////////////////////////////////////*/

/// @dev Optional, fail-soft interface for deployments that expose additional district/faction checks.
///      The current live core does not require these exact methods, so all calls are wrapped in try/catch.
interface ICityValidationPlacementLike {
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
/// @notice Normalized placement read adapter aligned to the live CityRegistry / CityLand / CityDistricts / CityStatus stack.
/// @dev This contract keeps the stable ICityPlacementCoreAdapter surface while internally using live-core reads:
///      - plot owner / plot type / faction via CityRegistry.getPlotCore(plotId)
///      - completion via CityLand.isPlotFullyCompleted(plotId)
///      - district metadata via CityDistricts.getDistrict(plotId)
///      - lifecycle eligibility via !CityStatus.isLayerEligible(plotId)
///      District/faction allowlists are treated as optional extension hooks and default to `true` when the
///      configured validation contract does not expose those helpers.
contract CityPlacementCoreAdapter is ICityPlacementCoreAdapter, AccessControl, Pausable {
    bytes32 public constant ADAPTER_ADMIN_ROLE = keccak256("ADAPTER_ADMIN_ROLE");

    uint8 internal constant PLOT_TYPE_PERSONAL = 1;

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
        if (admin_ == address(0)) revert ZeroAddress();

        _validateCoreContracts(registry_, land_, status_, districts_);

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
        _validateCoreContracts(registry_, land_, status_, districts_);

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

    function isPersonalPlot(uint256 plotId) external view override whenNotPaused returns (bool) {
        ICityRegistryLike.PlotCore memory core = ICityRegistryLike(cityRegistry).getPlotCore(plotId);
        return core.exists && core.plotType == PLOT_TYPE_PERSONAL;
    }

    function isPlotOwner(address user, uint256 plotId) external view override whenNotPaused returns (bool) {
        ICityRegistryLike.PlotCore memory core = ICityRegistryLike(cityRegistry).getPlotCore(plotId);
        return core.owner == user;
    }

    function isPlotCompleted(uint256 plotId) external view override whenNotPaused returns (bool) {
        return ICityLandLike(cityLand).isPlotFullyCompleted(plotId);
    }

    function isPlotEligibleForPlacement(uint256 plotId) external view override whenNotPaused returns (bool) {
        // Live-core truth: plots become blocked for building expansion once they are layer-eligible.
        return !ICityStatusLike(cityStatus).isLayerEligible(plotId);
    }

    function isDistrictAllowedForPersonalBuilding(
        uint256 plotId,
        uint8 buildingType
    ) external view override whenNotPaused returns (bool) {
        if (cityValidation == address(0)) return true;

        try ICityValidationPlacementLike(cityValidation).isDistrictAllowedForPersonalBuilding(
            plotId,
            buildingType
        ) returns (bool allowed) {
            return allowed;
        } catch {
            return true;
        }
    }

    function isFactionAllowedForPersonalBuilding(
        address user,
        uint256 plotId,
        uint8 buildingType
    ) external view override whenNotPaused returns (bool) {
        if (cityValidation == address(0)) return true;

        try ICityValidationPlacementLike(cityValidation).isFactionAllowedForPersonalBuilding(
            user,
            plotId,
            buildingType
        ) returns (bool allowed) {
            return allowed;
        } catch {
            return true;
        }
    }

    function getPlotFaction(uint256 plotId) external view override whenNotPaused returns (uint8) {
        ICityRegistryLike.PlotCore memory core = ICityRegistryLike(cityRegistry).getPlotCore(plotId);
        if (core.faction != 0) {
            return core.faction;
        }

        try ICityDistrictsLike(cityDistricts).getDistrict(plotId) returns (
            ICityDistrictsLike.DistrictData memory district
        ) {
            return district.faction;
        } catch {
            return 0;
        }
    }

    function getPlotDistrictKind(uint256 plotId) external view override whenNotPaused returns (uint8) {
        try ICityDistrictsLike(cityDistricts).getDistrict(plotId) returns (
            ICityDistrictsLike.DistrictData memory district
        ) {
            return district.kind;
        } catch {
            return 0;
        }
    }

    function getPlotOwner(uint256 plotId) external view override whenNotPaused returns (address) {
        ICityRegistryLike.PlotCore memory core = ICityRegistryLike(cityRegistry).getPlotCore(plotId);
        return core.owner;
    }

    function _validateCoreContracts(
        address registry_,
        address land_,
        address status_,
        address districts_
    ) internal pure {
        if (registry_ == address(0)) revert ZeroAddress();
        if (land_ == address(0)) revert ZeroAddress();
        if (status_ == address(0)) revert ZeroAddress();
        if (districts_ == address(0)) revert ZeroAddress();
    }
}
