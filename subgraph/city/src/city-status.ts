import { BigInt } from "@graphprotocol/graph-ts";
import {
  CityStatus as CityStatusContract,
  ManualStatusCleared,
  OwnershipTransferred,
  PlotStatusUpdated
} from "../generated/CityStatus/CityStatus";
import {
  Plot,
  PlotStatusInfo,
  ManualStatusClearedEvent,
  PlotStatusUpdatedEvent,
  CityStatusOwnershipTransferredEvent
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

function getOrCreatePlotStatusInfo(plotId: BigInt): PlotStatusInfo {
  let id = plotId.toString();
  let entity = PlotStatusInfo.load(id);

  if (entity == null) {
    entity = new PlotStatusInfo(id);
    entity.plot = id;
    entity.lastActivityAt = BigInt.zero();
    entity.lastMaintenanceAt = BigInt.zero();
    entity.manualStatusOverride = "none";
    entity.derivedStatus = "none";
    entity.layerEligible = false;
    entity.updatedAtBlock = BigInt.zero();
    entity.updatedAtTimestamp = BigInt.zero();
  }

  return entity as PlotStatusInfo;
}

function plotStatusToString(value: number): string {
  if (value == 0) return "none";
  if (value == 1) return "active";
  if (value == 2) return "dormant";
  if (value == 3) return "decayed";
  if (value == 4) return "layered";
  if (value == 5) return "reserved";
  return value.toString();
}

function syncPlotStatus(
  contract: CityStatusContract,
  plotId: BigInt,
  blockNumber: BigInt,
  blockTimestamp: BigInt
): void {
  let plot = getOrCreatePlot(plotId);
  let entity = getOrCreatePlotStatusInfo(plotId);

  let lastActivityCall = contract.try_lastActivityAtOf(plotId);
  if (!lastActivityCall.reverted) {
    entity.lastActivityAt = lastActivityCall.value;
  }

  let lastMaintenanceCall = contract.try_lastMaintenanceAtOf(plotId);
  if (!lastMaintenanceCall.reverted) {
    entity.lastMaintenanceAt = lastMaintenanceCall.value;
  }

  let manualStatusCall = contract.try_manualStatusOverrideOf(plotId);
  if (!manualStatusCall.reverted) {
    entity.manualStatusOverride = plotStatusToString(manualStatusCall.value);
  }

  let derivedStatusCall = contract.try_getDerivedStatus(plotId);
  if (!derivedStatusCall.reverted) {
    entity.derivedStatus = plotStatusToString(derivedStatusCall.value);

    // Plot-Hauptstatus mitführen
    plot.status = entity.derivedStatus;
    plot.exists = true;
    plot.save();
  }

  let layerEligibleCall = contract.try_isLayerEligible(plotId);
  if (!layerEligibleCall.reverted) {
    entity.layerEligible = layerEligibleCall.value;
  }

  entity.updatedAtBlock = blockNumber;
  entity.updatedAtTimestamp = blockTimestamp;
  entity.save();
}

// --------------------------------------------------
// Event handlers
// --------------------------------------------------

export function handleManualStatusCleared(event: ManualStatusCleared): void {
  let contract = CityStatusContract.bind(event.address);
  let plotId = event.params.plotId;

  getOrCreatePlot(plotId);
  syncPlotStatus(contract, plotId, event.block.number, event.block.timestamp);

  let entity = new ManualStatusClearedEvent(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  entity.plot = plotId.toString();
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}

export function handlePlotStatusUpdated(event: PlotStatusUpdated): void {
  let contract = CityStatusContract.bind(event.address);
  let plotId = event.params.plotId;

  getOrCreatePlot(plotId);
  syncPlotStatus(contract, plotId, event.block.number, event.block.timestamp);

  let entity = new PlotStatusUpdatedEvent(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  entity.plot = plotId.toString();
  entity.oldStatus = event.params.oldStatus;
  entity.oldStatusLabel = plotStatusToString(event.params.oldStatus);
  entity.newStatus = event.params.newStatus;
  entity.newStatusLabel = plotStatusToString(event.params.newStatus);
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}

export function handleOwnershipTransferred(event: OwnershipTransferred): void {
  let entity = new CityStatusOwnershipTransferredEvent(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  entity.previousOwner = event.params.previousOwner;
  entity.newOwner = event.params.newOwner;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}