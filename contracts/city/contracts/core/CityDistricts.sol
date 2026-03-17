// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/CityTypes.sol";
import "../libraries/CityErrors.sol";
import "./CityRegistry.sol";

contract CityDistricts is Ownable {
    enum DistrictKind {
        None,
        Nexus,
        InpinityResidential,
        InphinityResidential,
        Borderline,
        CommunityCore,
        Research,
        Defense,
        Trade
    }

    struct DistrictData {
        DistrictKind kind;
        CityTypes.Faction faction;
        uint32 bonusBps;
        bool exists;
    }

    CityRegistry public immutable cityRegistry;

    mapping(uint256 => DistrictData) public districtOfPlot;
    mapping(address => bool) public authorizedCallers;

    constructor(address initialOwner, address cityRegistryAddress) Ownable(initialOwner) {
        if (initialOwner == address(0) || cityRegistryAddress == address(0)) {
            revert CityErrors.ZeroAddress();
        }
        cityRegistry = CityRegistry(cityRegistryAddress);
    }

    modifier onlyAuthorized() {
        if (!(msg.sender == owner() || authorizedCallers[msg.sender])) {
            revert CityErrors.NotPlotOwner();
        }
        _;
    }

    function setAuthorizedCaller(address caller, bool allowed) external onlyOwner {
        if (caller == address(0)) revert CityErrors.ZeroAddress();
        authorizedCallers[caller] = allowed;
    }

    function assignDistrict(
        uint256 plotId,
        DistrictKind kind,
        CityTypes.Faction faction,
        uint32 bonusBps
    ) external onlyAuthorized {
        cityRegistry.getPlotCore(plotId);

        districtOfPlot[plotId] = DistrictData({
            kind: kind,
            faction: faction,
            bonusBps: bonusBps,
            exists: true
        });
    }

    function assignDistrictAuto(uint256 plotId) external onlyAuthorized {
        CityTypes.PlotCore memory plot = cityRegistry.getPlotCore(plotId);

        (DistrictKind kind, CityTypes.Faction faction, uint32 bonusBps) =
            deriveDistrict(plot.plotType, plot.faction);

        districtOfPlot[plotId] = DistrictData({
            kind: kind,
            faction: faction,
            bonusBps: bonusBps,
            exists: true
        });
    }

    function deriveDistrict(
        CityTypes.PlotType plotType,
        CityTypes.Faction faction
    )
        public
        pure
        returns (DistrictKind kind, CityTypes.Faction resolvedFaction, uint32 bonusBps)
    {
        if (plotType == CityTypes.PlotType.Personal) {
            if (faction == CityTypes.Faction.Inpinity) {
                return (DistrictKind.InpinityResidential, CityTypes.Faction.Inpinity, 0);
            }
            if (faction == CityTypes.Faction.Inphinity) {
                return (DistrictKind.InphinityResidential, CityTypes.Faction.Inphinity, 0);
            }
        }

        if (plotType == CityTypes.PlotType.Community) {
            return (DistrictKind.CommunityCore, CityTypes.Faction.Neutral, 0);
        }

        if (plotType == CityTypes.PlotType.Borderline) {
            return (DistrictKind.Borderline, CityTypes.Faction.Neutral, 0);
        }

        return (DistrictKind.None, CityTypes.Faction.None, 0);
    }

    function getDistrict(uint256 plotId) external view returns (DistrictData memory) {
        cityRegistry.getPlotCore(plotId);
        return districtOfPlot[plotId];
    }

    function isBorderline(uint256 plotId) external view returns (bool) {
        return districtOfPlot[plotId].kind == DistrictKind.Borderline;
    }
}