import { BigInt } from "@graphprotocol/graph-ts";
import {
  AetherUsed,
  OwnershipTransferred,
  PlotCompleted,
  QubiqCompleted,
  QubiqContributed
} from "../generated/CityLand/CityLand";
import {
  Plot,
  PlotQubiq,
  AetherUse,
  PlotCompletion,
  QubiqContribution,
  PlotStats,
  OwnershipTransferredEvent
} from "../generated/schema";

// --------------------------------------------------
// Helpers
// --------------------------------------------------

function getOrCreatePlot(plotId: BigInt): Plot {
  let plot = Plot.load(plotId.toString());
  if (plot == null) {
    plot = new Plot(plotId.toString());
    plot.plotId = plotId;
    plot.plotType = "unknown";
    plot.faction = "unknown";
    plot.status = "unknown";
    plot.width = BigInt.zero();
    plot.height = BigInt.zero();
    plot.createdAt = BigInt.zero();
    plot.exists = false;
    plot.save();
  }
  return plot as Plot;
}

function getOrCreatePlotStats(plotId: BigInt): PlotStats {
  let id = plotId.toString();
  let stats = PlotStats.load(id);
  if (stats == null) {
    stats = new PlotStats(id);
    stats.plot = id;
    stats.completedQubiqCount = 0;
    stats.aetherUsesCount = 0;
    stats.totalOil = BigInt.zero();
    stats.totalLemons = BigInt.zero();
    stats.totalIron = BigInt.zero();
    stats.updatedAt = BigInt.zero();
  }
  return stats as PlotStats;
}

function getQubiqId(plotId: BigInt, x: BigInt, y: BigInt): string {
  return plotId.toString() + "-" + x.toString() + "-" + y.toString();
}

// --------------------------------------------------
// Event handlers
// --------------------------------------------------

export function handleAetherUsed(event: AetherUsed): void {
  let plotId = event.params.plotId;
  let x = event.params.x;
  let y = event.params.y;
  let user = event.params.user;

  getOrCreatePlot(plotId);

  let qubiqId = getQubiqId(plotId, x, y);
  let qubiq = PlotQubiq.load(qubiqId);
  if (qubiq != null) {
    qubiq.usedAether = true;
    qubiq.updatedAt = event.block.timestamp;
    qubiq.save();
  }

  let aetherUse = new AetherUse(
    event.transaction.hash.toHex() + "-" + event.logIndex.toString()
  );
  aetherUse.plot = plotId.toString();
  aetherUse.x = x.toI32();
  aetherUse.y = y.toI32();
  aetherUse.user = user;
  aetherUse.blockNumber = event.block.number;
  aetherUse.timestamp = event.block.timestamp;
  aetherUse.txHash = event.transaction.hash;
  aetherUse.save();

  let stats = getOrCreatePlotStats(plotId);
  stats.aetherUsesCount = stats.aetherUsesCount + 1;
  stats.updatedAt = event.block.timestamp;
  stats.save();
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

export function handlePlotCompleted(event: PlotCompleted): void {
  let plotId = event.params.plotId;

  getOrCreatePlot(plotId);

  let completion = new PlotCompletion(
    event.transaction.hash.toHex() + "-" + event.logIndex.toString()
  );
  completion.plot = plotId.toString();
  completion.blockNumber = event.block.number;
  completion.timestamp = event.block.timestamp;
  completion.txHash = event.transaction.hash;
  completion.save();
}

export function handleQubiqCompleted(event: QubiqCompleted): void {
  let plotId = event.params.plotId;
  let x = event.params.x;
  let y = event.params.y;
  let usedAether = event.params.usedAether;

  getOrCreatePlot(plotId);

  let qubiqId = getQubiqId(plotId, x, y);
  let qubiq = PlotQubiq.load(qubiqId);

  if (qubiq == null) {
    qubiq = new PlotQubiq(qubiqId);
    qubiq.plot = plotId.toString();
    qubiq.x = x.toI32();
    qubiq.y = y.toI32();
    qubiq.oilDeposited = BigInt.zero();
    qubiq.lemonsDeposited = BigInt.zero();
    qubiq.ironDeposited = BigInt.zero();
    qubiq.completed = false;
    qubiq.usedAether = false;
    qubiq.createdAt = event.block.timestamp;
    qubiq.updatedAt = event.block.timestamp;
  }

  qubiq.completed = true;
  qubiq.usedAether = usedAether;
  qubiq.completedAt = event.block.timestamp;
  qubiq.updatedAt = event.block.timestamp;
  qubiq.save();

  let stats = getOrCreatePlotStats(plotId);
  stats.completedQubiqCount = stats.completedQubiqCount + 1;
  stats.updatedAt = event.block.timestamp;
  stats.save();
}

export function handleQubiqContributed(event: QubiqContributed): void {
  let plotId = event.params.plotId;
  let x = event.params.x;
  let y = event.params.y;
  let contributor = event.params.contributor;
  let oil = event.params.oil;
  let lemons = event.params.lemons;
  let iron = event.params.iron;

  getOrCreatePlot(plotId);

  let qubiqId = getQubiqId(plotId, x, y);
  let qubiq = PlotQubiq.load(qubiqId);

  if (qubiq == null) {
    qubiq = new PlotQubiq(qubiqId);
    qubiq.plot = plotId.toString();
    qubiq.x = x.toI32();
    qubiq.y = y.toI32();
    qubiq.oilDeposited = BigInt.zero();
    qubiq.lemonsDeposited = BigInt.zero();
    qubiq.ironDeposited = BigInt.zero();
    qubiq.completed = false;
    qubiq.usedAether = false;
    qubiq.createdAt = event.block.timestamp;
    qubiq.updatedAt = event.block.timestamp;
  }

  qubiq.oilDeposited = qubiq.oilDeposited.plus(oil);
  qubiq.lemonsDeposited = qubiq.lemonsDeposited.plus(lemons);
  qubiq.ironDeposited = qubiq.ironDeposited.plus(iron);
  qubiq.lastContributor = contributor;
  qubiq.updatedAt = event.block.timestamp;
  qubiq.save();

  let contribution = new QubiqContribution(
    event.transaction.hash.toHex() + "-" + event.logIndex.toString()
  );
  contribution.plot = plotId.toString();
  contribution.x = x.toI32();
  contribution.y = y.toI32();
  contribution.contributor = contributor;
  contribution.oil = oil;
  contribution.lemons = lemons;
  contribution.iron = iron;
  contribution.blockNumber = event.block.number;
  contribution.timestamp = event.block.timestamp;
  contribution.txHash = event.transaction.hash;
  contribution.save();

  let stats = getOrCreatePlotStats(plotId);
  stats.totalOil = stats.totalOil.plus(oil);
  stats.totalLemons = stats.totalLemons.plus(lemons);
  stats.totalIron = stats.totalIron.plus(iron);
  stats.updatedAt = event.block.timestamp;
  stats.save();
}