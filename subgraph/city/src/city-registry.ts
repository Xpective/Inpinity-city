import { BigInt } from "@graphprotocol/graph-ts";
import {
  CityKeyTokenSet,
  FactionChosen,
  PersonalPlotReserved,
  CommunityPlotReserved
} from "../generated/CityRegistry/CityRegistry";

import { Player, Plot } from "../generated/schema";

function getOrCreatePlayer(id: string): Player {
  let player = Player.load(id);

  if (player == null) {
    player = new Player(id);
    player.personalPlotCount = 0;
  }

  return player;
}

function getOrCreatePlot(id: string): Plot {
  let plot = Plot.load(id);

  if (plot == null) {
    plot = new Plot(id);
    plot.plotId = BigInt.fromString(id);
    plot.plotType = "unknown";
    plot.faction = "unknown";
    plot.createdAt = BigInt.zero();
    plot.exists = true;
  }

  return plot;
}

export function handleCityKeyTokenSet(event: CityKeyTokenSet): void {
  let playerId = event.params.user.toHexString();
  let player = getOrCreatePlayer(playerId);

  player.cityKeyTokenId = event.params.tokenId;
  player.save();
}

export function handleFactionChosen(event: FactionChosen): void {
  let playerId = event.params.user.toHexString();
  let player = getOrCreatePlayer(playerId);

  player.faction = event.params.faction.toString();
  player.save();
}

export function handlePersonalPlotReserved(event: PersonalPlotReserved): void {
  let playerId = event.params.owner.toHexString();
  let player = getOrCreatePlayer(playerId);

  player.personalPlotCount = player.personalPlotCount + 1;
  player.save();

  let plotId = event.params.plotId.toString();
  let plot = getOrCreatePlot(plotId);

  plot.owner = playerId;
  plot.plotId = event.params.plotId;
  plot.plotType = "personal";
  plot.faction = event.params.faction.toString();
  plot.createdAt = event.block.timestamp;
  plot.exists = true;

  plot.save();
}

export function handleCommunityPlotReserved(event: CommunityPlotReserved): void {
  let plotId = event.params.plotId.toString();
  let plot = getOrCreatePlot(plotId);

  plot.plotId = event.params.plotId;
  plot.plotType = "community-" + event.params.buildingKind.toString();
  plot.faction = "community";
  plot.createdAt = event.block.timestamp;
  plot.exists = true;

  plot.save();
}