import { BigInt } from "@graphprotocol/graph-ts";
import {
  CityKeyTokenSet,
  FactionChosen,
  PersonalPlotReserved,
  CommunityPlotReserved,
  OwnershipTransferred
} from "../generated/CityRegistry/CityRegistry";

import {
  Player,
  Plot,
  OwnershipTransferredEvent
} from "../generated/schema";

// --------------------------------------------------
// Helpers
// --------------------------------------------------

function getOrCreatePlayer(id: string): Player {
  let player = Player.load(id);
  if (player == null) {
    player = new Player(id);
    player.personalPlotCount = 0;
  }
  return player as Player;
}

function getOrCreatePlot(id: string): Plot {
  let plot = Plot.load(id);
  if (plot == null) {
    plot = new Plot(id);
    plot.plotId = BigInt.fromString(id);
    plot.plotType = "unknown";
    plot.faction = "unknown";
    plot.status = "unknown";
    plot.width = BigInt.zero();
    plot.height = BigInt.zero();
    plot.createdAt = BigInt.zero();
    plot.exists = false;
  }
  return plot as Plot;
}

function factionToString(value: i32): string {
  if (value == 0) return "none";
  if (value == 1) return "pi";
  if (value == 2) return "phi";
  if (value == 3) return "community";
  return value.toString();
}

// --------------------------------------------------
// Event handlers
// --------------------------------------------------

export function handleCityKeyTokenSet(event: CityKeyTokenSet): void {
  let playerId = event.params.user.toHexString();
  let player = getOrCreatePlayer(playerId);

  player.cityKeyTokenId = event.params.tokenId;
  player.save();
}

export function handleFactionChosen(event: FactionChosen): void {
  let playerId = event.params.user.toHexString();
  let player = getOrCreatePlayer(playerId);

  player.faction = factionToString(event.params.faction);
  player.save();
}

export function handlePersonalPlotReserved(event: PersonalPlotReserved): void {
  let playerId = event.params.owner.toHexString();
  let player = getOrCreatePlayer(playerId);

  player.personalPlotCount = player.personalPlotCount + 1;

  if (player.faction == null) {
    player.faction = factionToString(event.params.faction);
  }

  player.save();

  let plotId = event.params.plotId.toString();
  let plot = getOrCreatePlot(plotId);

  plot.plotId = event.params.plotId;
  plot.owner = playerId;
  plot.plotType = "personal";
  plot.faction = factionToString(event.params.faction);
  plot.status = "reserved";
  plot.width = BigInt.fromI32(5);
  plot.height = BigInt.fromI32(5);

  if (plot.createdAt.equals(BigInt.zero())) {
    plot.createdAt = event.block.timestamp;
  }

  plot.exists = true;
  plot.save();
}

export function handleCommunityPlotReserved(event: CommunityPlotReserved): void {
  let plotId = event.params.plotId.toString();
  let plot = getOrCreatePlot(plotId);

  plot.plotId = event.params.plotId;
  plot.plotType = "community";
  plot.faction = "community";
  plot.status = "reserved";
  plot.width = BigInt.fromI32(25);
  plot.height = BigInt.fromI32(25);

  if (plot.createdAt.equals(BigInt.zero())) {
    plot.createdAt = event.block.timestamp;
  }

  plot.exists = true;
  plot.save();
}

export function handleOwnershipTransferred(event: OwnershipTransferred): void {
  let id = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
  let entity = new OwnershipTransferredEvent(id);

  entity.previousOwner = event.params.previousOwner;
  entity.newOwner = event.params.newOwner;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;

  entity.save();
}