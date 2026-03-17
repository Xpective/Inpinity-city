// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/CityTypes.sol";
import "../libraries/CityErrors.sol";
import "./CityConfig.sol";
import "./CityRegistry.sol";
import "./CityStatus.sol";
import "./CityLand.sol";

contract CityValidation is Ownable {
    CityConfig public immutable cityConfig;
    CityRegistry public immutable cityRegistry;
    CityStatus public cityStatus;
    CityLand public cityLand;

    constructor(
        address initialOwner,
        address cityConfigAddress,
        address cityRegistryAddress
    ) Ownable(initialOwner) {
        if (
            initialOwner == address(0) ||
            cityConfigAddress == address(0) ||
            cityRegistryAddress == address(0)
        ) {
            revert CityErrors.ZeroAddress();
        }

        cityConfig = CityConfig(cityConfigAddress);
        cityRegistry = CityRegistry(cityRegistryAddress);
    }

    function setHooks(address cityStatusAddress, address cityLandAddress) external onlyOwner {
        if (cityStatusAddress != address(0)) {
            cityStatus = CityStatus(cityStatusAddress);
        }
        if (cityLandAddress != address(0)) {
            cityLand = CityLand(cityLandAddress);
        }
    }

    function canReservePersonalPlot(address user, uint8 slotIndex) external view returns (bool) {
        if (!cityRegistry.hasCityKeyOf(user)) return false;

        CityTypes.Faction faction = cityRegistry.chosenFactionOf(user);
        if (
            faction != CityTypes.Faction.Inpinity &&
            faction != CityTypes.Faction.Inphinity
        ) {
            return false;
        }

        uint256 maxPlots = cityConfig.getUintConfig(cityConfig.KEY_MAX_PERSONAL_PLOTS());
        if (slotIndex >= maxPlots) return false;
        if (cityRegistry.personalPlotCountOf(user) >= maxPlots) return false;

        uint8 expectedNextSlot = cityRegistry.personalPlotCountOf(user);
        if (slotIndex != expectedNextSlot) return false;

        (, bool occupied) = cityRegistry.getPersonalPlot(user, slotIndex);
        if (occupied) return false;

        return true;
    }

    function isValidPersonalPlotSize(uint256 plotId) external view returns (bool) {
        CityTypes.PlotCore memory plot = cityRegistry.getPlotCore(plotId);
        if (plot.plotType != CityTypes.PlotType.Personal) return false;

        return (
            plot.width == cityConfig.getUintConfig(cityConfig.KEY_PERSONAL_WIDTH()) &&
            plot.height == cityConfig.getUintConfig(cityConfig.KEY_PERSONAL_HEIGHT())
        );
    }

    function isValidCommunityPlotSize(uint256 plotId) external view returns (bool) {
        CityTypes.PlotCore memory plot = cityRegistry.getPlotCore(plotId);
        if (plot.plotType != CityTypes.PlotType.Community) return false;

        return (
            plot.width == cityConfig.getUintConfig(cityConfig.KEY_COMMUNITY_WIDTH()) &&
            plot.height == cityConfig.getUintConfig(cityConfig.KEY_COMMUNITY_HEIGHT())
        );
    }

    function canUseFaction(address user, CityTypes.Faction faction) external view returns (bool) {
        if (!cityRegistry.hasCityKeyOf(user)) return false;
        if (cityRegistry.chosenFactionOf(user) != CityTypes.Faction.None) return false;

        return (
            faction == CityTypes.Faction.Inpinity ||
            faction == CityTypes.Faction.Inphinity
        );
    }

    function canFillQubiq(
        address user,
        uint256 plotId,
        uint32 x,
        uint32 y
    ) external view returns (bool) {
        CityTypes.PlotCore memory plot = cityRegistry.getPlotCore(plotId);

        if (!plot.exists) return false;
        if (x >= plot.width || y >= plot.height) return false;

        if (plot.plotType == CityTypes.PlotType.Personal && plot.owner != user) {
            return false;
        }

        if (address(cityStatus) != address(0)) {
            CityTypes.PlotStatus status = cityStatus.getDerivedStatus(plotId);
            if (status == CityTypes.PlotStatus.LayerEligible) {
                return false;
            }
        }

        return true;
    }

    function canUseAetherOnQubiq(
        address user,
        uint256 plotId,
        uint32 x,
        uint32 y
    ) external view returns (bool) {
        CityTypes.PlotCore memory plot = cityRegistry.getPlotCore(plotId);

        if (!plot.exists) return false;
        if (x >= plot.width || y >= plot.height) return false;

        if (plot.plotType == CityTypes.PlotType.Personal && plot.owner != user) {
            return false;
        }

        if (address(cityStatus) != address(0)) {
            CityTypes.PlotStatus status = cityStatus.getDerivedStatus(plotId);
            if (status == CityTypes.PlotStatus.LayerEligible) {
                return false;
            }
        }

        return true;
    }
}