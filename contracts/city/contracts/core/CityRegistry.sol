// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IInpinityNFT.sol";
import "../interfaces/ICityHistory.sol";
import "../libraries/CityTypes.sol";
import "../libraries/CityErrors.sol";
import "../libraries/CityEvents.sol";
import "./CityConfig.sol";

contract CityRegistry is Ownable {
    CityConfig public immutable cityConfig;
    ICityHistory public cityHistory;

    uint256 public nextPlotId = 1;

    mapping(address => uint256) public cityKeyTokenOf;
    mapping(address => CityTypes.Faction) public chosenFactionOf;

    mapping(address => uint8) public personalPlotCountOf;
    mapping(address => mapping(uint8 => CityTypes.PlotSlot)) public personalPlotSlotsOf;

    mapping(uint256 => CityTypes.PlotCore) public plotCoreOf;
    mapping(CityTypes.Faction => uint256) public factionPlotCount;

    constructor(address initialOwner, address cityConfigAddress) Ownable(initialOwner) {
        if (initialOwner == address(0) || cityConfigAddress == address(0)) {
            revert CityErrors.ZeroAddress();
        }
        cityConfig = CityConfig(cityConfigAddress);
    }

    function setCityHistory(address cityHistoryAddress) external onlyOwner {
        if (cityHistoryAddress == address(0)) revert CityErrors.ZeroAddress();
        cityHistory = ICityHistory(cityHistoryAddress);
    }

    function setCityKeyToken(uint256 tokenId) external {
        if (personalPlotCountOf[msg.sender] > 0) {
            revert CityErrors.InvalidValue();
        }

        address nftAddress = cityConfig.getAddressConfig(cityConfig.KEY_INPINITY_NFT());
        if (nftAddress == address(0)) revert CityErrors.InvalidConfig();

        address ownerOfToken = IInpinityNFT(nftAddress).ownerOf(tokenId);
        if (ownerOfToken != msg.sender) revert CityErrors.NotPlotOwner();

        cityKeyTokenOf[msg.sender] = tokenId;
        emit CityEvents.CityKeyTokenSet(msg.sender, tokenId);
    }

    function chooseFaction(CityTypes.Faction faction) external {
        if (cityKeyTokenOf[msg.sender] == 0) revert CityErrors.InvalidValue();
        if (chosenFactionOf[msg.sender] != CityTypes.Faction.None) {
            revert CityErrors.InvalidFaction();
        }
        if (faction != CityTypes.Faction.Inpinity && faction != CityTypes.Faction.Inphinity) {
            revert CityErrors.InvalidFaction();
        }

        chosenFactionOf[msg.sender] = faction;
        emit CityEvents.FactionChosen(msg.sender, faction);
    }

    function reserveNextPersonalPlot(uint8 slotIndex) external returns (uint256 plotId) {
        if (cityKeyTokenOf[msg.sender] == 0) revert CityErrors.InvalidValue();

        CityTypes.Faction faction = chosenFactionOf[msg.sender];
        if (faction != CityTypes.Faction.Inpinity && faction != CityTypes.Faction.Inphinity) {
            revert CityErrors.InvalidFaction();
        }

        uint256 maxPlots = cityConfig.getUintConfig(cityConfig.KEY_MAX_PERSONAL_PLOTS());
        if (slotIndex >= maxPlots) revert CityErrors.InvalidValue();
        if (personalPlotCountOf[msg.sender] >= maxPlots) {
            revert CityErrors.MaxPersonalPlotsReached();
        }

        uint8 expectedNextSlot = personalPlotCountOf[msg.sender];
        if (slotIndex != expectedNextSlot) {
            revert CityErrors.InvalidValue();
        }

        if (personalPlotSlotsOf[msg.sender][slotIndex].occupied) {
            revert CityErrors.PlotSlotOccupied();
        }

        plotId = nextPlotId++;
        personalPlotSlotsOf[msg.sender][slotIndex] = CityTypes.PlotSlot({
            plotId: plotId,
            occupied: true
        });

        unchecked {
            personalPlotCountOf[msg.sender] += 1;
            factionPlotCount[faction] += 1;
        }

        plotCoreOf[plotId] = CityTypes.PlotCore({
            id: plotId,
            plotType: CityTypes.PlotType.Personal,
            faction: faction,
            status: CityTypes.PlotStatus.Reserved,
            owner: msg.sender,
            width: uint32(cityConfig.getUintConfig(cityConfig.KEY_PERSONAL_WIDTH())),
            height: uint32(cityConfig.getUintConfig(cityConfig.KEY_PERSONAL_HEIGHT())),
            createdAt: uint64(block.timestamp),
            exists: true
        });

        emit CityEvents.PersonalPlotReserved(msg.sender, plotId, slotIndex, faction);

        if (address(cityHistory) != address(0)) {
            cityHistory.initializePlotHistory(plotId, msg.sender, faction, true);
        }
    }

    function reserveCommunityPlot(CityTypes.CommunityBuildingKind buildingKind)
        external
        onlyOwner
        returns (uint256 plotId)
    {
        if (buildingKind == CityTypes.CommunityBuildingKind.None) {
            revert CityErrors.InvalidValue();
        }

        plotId = nextPlotId++;

        plotCoreOf[plotId] = CityTypes.PlotCore({
            id: plotId,
            plotType: CityTypes.PlotType.Community,
            faction: CityTypes.Faction.Neutral,
            status: CityTypes.PlotStatus.Reserved,
            owner: address(this),
            width: uint32(cityConfig.getUintConfig(cityConfig.KEY_COMMUNITY_WIDTH())),
            height: uint32(cityConfig.getUintConfig(cityConfig.KEY_COMMUNITY_HEIGHT())),
            createdAt: uint64(block.timestamp),
            exists: true
        });

        emit CityEvents.CommunityPlotReserved(plotId, buildingKind);

        if (address(cityHistory) != address(0)) {
            cityHistory.initializePlotHistory(
                plotId,
                owner(),
                CityTypes.Faction.Neutral,
                true
            );
        }
    }

    function getPersonalPlot(address user, uint8 slotIndex) external view returns (uint256, bool) {
        CityTypes.PlotSlot memory slot = personalPlotSlotsOf[user][slotIndex];
        return (slot.plotId, slot.occupied);
    }

    function getPlotCore(uint256 plotId) external view returns (CityTypes.PlotCore memory) {
        CityTypes.PlotCore memory plot = plotCoreOf[plotId];
        if (!plot.exists) revert CityErrors.PlotNotFound();
        return plot;
    }
}