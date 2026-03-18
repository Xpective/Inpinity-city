import { BigInt } from "@graphprotocol/graph-ts";
import {
  CityHistory as CityHistoryContract,
  AetherUseRecorded,
  LayerAdded,
  OwnershipTransferRecorded,
  OwnershipTransferred,
  PlotHistoryInitialized
} from "../generated/CityHistory/CityHistory";
import {
  Plot,
  PlotProvenance,
  PlotHistoryInitializedEvent,
  AetherUseRecordedEvent,
  LayerAddedEvent,
  OwnershipTransferRecordedEvent,
  CityHistoryOwnershipTransferredEvent
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

function getOrCreatePlotProvenance(plotId: BigInt): PlotProvenance {
  let id = plotId.toString();
  let entity = PlotProvenance.load(id);
  if (entity == null) {
    entity = new PlotProvenance(id);
    entity.plot = id;
    entity.layerCount = BigInt.zero();
    entity.ownershipTransfers = BigInt.zero();
    entity.aetherUses = BigInt.zero();
    entity.historicScore = BigInt.zero();
    entity.genesisEra = false;
    entity.updatedAtBlock = BigInt.zero();
    entity.updatedAtTimestamp = BigInt.zero();
  }
  return entity as PlotProvenance;
}

function factionToString(value: number): string {
    if (value == 0) return "none";
    if (value == 1) return "pi";
    if (value == 2) return "phi";
    if (value == 3) return "community";
    return value.toString();
  }

function syncProvenance(
  contract: CityHistoryContract,
  plotId: BigInt,
  blockNumber: BigInt,
  blockTimestamp: BigInt
): void {
  let plot = getOrCreatePlot(plotId);
  let entity = getOrCreatePlotProvenance(plotId);

  let call = contract.try_provenanceOf(plotId);
  if (call.reverted) {
    entity.updatedAtBlock = blockNumber;
    entity.updatedAtTimestamp = blockTimestamp;
    entity.save();
    return;
  }

  let p = call.value;

  entity.plot = plot.id;
  entity.firstBuilder = p.value0;
  entity.createdAt = p.value1;
  entity.layerCount = p.value2;
  entity.ownershipTransfers = p.value3;
  entity.aetherUses = p.value4;
  entity.historicScore = p.value5;
  entity.originFaction = factionToString(p.value6);
  entity.genesisEra = p.value7;
  entity.updatedAtBlock = blockNumber;
  entity.updatedAtTimestamp = blockTimestamp;
  entity.save();

  if (plot.faction == "unknown") {
    plot.faction = factionToString(p.value6);
  }
  if (plot.createdAt.equals(BigInt.zero())) {
    plot.createdAt = p.value1;
  }
  plot.exists = true;
  plot.save();
}

// --------------------------------------------------
// Event handlers
// --------------------------------------------------

export function handlePlotHistoryInitialized(event: PlotHistoryInitialized): void {
  let contract = CityHistoryContract.bind(event.address);
  let plotId = event.params.plotId;

  getOrCreatePlot(plotId);
  syncProvenance(contract, plotId, event.block.number, event.block.timestamp);

  let entity = new PlotHistoryInitializedEvent(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  entity.plot = plotId.toString();
  entity.firstBuilder = event.params.firstBuilder;
  entity.faction = event.params.faction;
  entity.factionLabel = factionToString(event.params.faction);
  entity.genesisEra = event.params.genesisEra;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}

export function handleAetherUseRecorded(event: AetherUseRecorded): void {
  let contract = CityHistoryContract.bind(event.address);
  let plotId = event.params.plotId;

  getOrCreatePlot(plotId);
  syncProvenance(contract, plotId, event.block.number, event.block.timestamp);

  let entity = new AetherUseRecordedEvent(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  entity.plot = plotId.toString();
  entity.totalAetherUses = event.params.totalAetherUses;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}

export function handleLayerAdded(event: LayerAdded): void {
  let contract = CityHistoryContract.bind(event.address);
  let plotId = event.params.plotId;

  getOrCreatePlot(plotId);
  syncProvenance(contract, plotId, event.block.number, event.block.timestamp);

  let entity = new LayerAddedEvent(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  entity.plot = plotId.toString();
  entity.newLayerCount = event.params.newLayerCount;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}

export function handleOwnershipTransferRecorded(event: OwnershipTransferRecorded): void {
  let contract = CityHistoryContract.bind(event.address);
  let plotId = event.params.plotId;

  getOrCreatePlot(plotId);
  syncProvenance(contract, plotId, event.block.number, event.block.timestamp);

  let entity = new OwnershipTransferRecordedEvent(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  entity.plot = plotId.toString();
  entity.transferCount = event.params.transferCount;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}

export function handleOwnershipTransferred(event: OwnershipTransferred): void {
  let entity = new CityHistoryOwnershipTransferredEvent(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  entity.previousOwner = event.params.previousOwner;
  entity.newOwner = event.params.newOwner;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}