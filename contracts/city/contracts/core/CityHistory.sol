// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/CityTypes.sol";
import "../libraries/CityErrors.sol";
import "../libraries/CityEvents.sol";
import "./CityRegistry.sol";

contract CityHistory is Ownable {
    struct PlotProvenance {
        address firstBuilder;
        uint64 createdAt;
        uint32 layerCount;
        uint32 ownershipTransfers;
        uint32 aetherUses;
        uint32 historicScore;
        CityTypes.Faction originFaction;
        bool genesisEra;
    }

    CityRegistry public immutable cityRegistry;
    mapping(address => bool) public authorizedCallers;

    mapping(uint256 => PlotProvenance) public provenanceOf;

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

    function initializePlotHistory(
        uint256 plotId,
        address firstBuilder,
        CityTypes.Faction faction,
        bool genesisEra
    ) external onlyAuthorized {
        if (firstBuilder == address(0)) revert CityErrors.ZeroAddress();

        CityTypes.PlotCore memory plot = cityRegistry.getPlotCore(plotId);

        PlotProvenance storage p = provenanceOf[plotId];
        if (p.createdAt != 0) revert CityErrors.PlotAlreadyExists();

        p.firstBuilder = firstBuilder;
        p.createdAt = uint64(block.timestamp);
        p.layerCount = 1;
        p.originFaction = faction;
        p.genesisEra = genesisEra;
        p.historicScore = plot.plotType == CityTypes.PlotType.Personal ? 100 : 250;

        emit CityEvents.PlotHistoryInitialized(plotId, firstBuilder, faction, genesisEra);
    }

    function recordOwnershipTransfer(uint256 plotId) external onlyAuthorized {
        cityRegistry.getPlotCore(plotId);
        PlotProvenance storage p = provenanceOf[plotId];
        p.ownershipTransfers += 1;
        p.historicScore += 5;

        emit CityEvents.OwnershipTransferRecorded(plotId, p.ownershipTransfers);
    }

    function recordLayerAdded(uint256 plotId) external onlyAuthorized {
        cityRegistry.getPlotCore(plotId);
        PlotProvenance storage p = provenanceOf[plotId];
        p.layerCount += 1;
        p.historicScore += 10;

        emit CityEvents.LayerAdded(plotId, p.layerCount);
    }

    function recordAetherUse(uint256 plotId) external onlyAuthorized {
        cityRegistry.getPlotCore(plotId);
        PlotProvenance storage p = provenanceOf[plotId];
        p.aetherUses += 1;
        p.historicScore += 25;

        emit CityEvents.AetherUseRecorded(plotId, p.aetherUses);
    }
}