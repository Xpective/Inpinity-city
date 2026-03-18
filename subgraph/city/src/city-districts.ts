import { BigInt } from "@graphprotocol/graph-ts";
import {
  CityDistricts as CityDistrictsContract,
  OwnershipTransferred,
  AssignDistrictCall,
  AssignDistrictAutoCall,
  SetAuthorizedCallerCall
} from "../generated/CityDistricts/CityDistricts";
import {
  Plot,
  PlotDistrict,
  DistrictAuthorizedCaller,
  CityDistrictsOwnershipTransferredEvent
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

function getOrCreatePlotDistrict(plotId: BigInt): PlotDistrict {
  let id = plotId.toString();
  let entity = PlotDistrict.load(id);

  if (entity == null) {
    entity = new PlotDistrict(id);
    entity.plot = id;
    entity.kindRaw = "0";
    entity.kindLabel = "none";
    entity.factionRaw = "0";
    entity.factionLabel = "none";
    entity.bonusBps = "0";
    entity.exists = false;
    entity.isBorderline = false;
    entity.updatedAtBlock = BigInt.zero();
    entity.updatedAtTimestamp = BigInt.zero();
  }

  return entity as PlotDistrict;
}

function getOrCreateAuthorizedCaller(id: string): DistrictAuthorizedCaller {
  let entity = DistrictAuthorizedCaller.load(id);

  if (entity == null) {
    entity = new DistrictAuthorizedCaller(id);
    entity.allowed = false;
    entity.updatedAtBlock = BigInt.zero();
    entity.updatedAtTimestamp = BigInt.zero();
  }

  return entity as DistrictAuthorizedCaller;
}

function districtKindToLabel(raw: string): string {
  if (raw == "0") return "none";
  return "kind_" + raw;
}

function factionToLabel(raw: string): string {
  if (raw == "0") return "none";
  if (raw == "1") return "pi";
  if (raw == "2") return "phi";
  if (raw == "3") return "community";
  return "faction_" + raw;
}

function syncDistrict(
  contract: CityDistrictsContract,
  plotId: BigInt,
  blockNumber: BigInt,
  blockTimestamp: BigInt
): void {
  let plot = getOrCreatePlot(plotId);
  let entity = getOrCreatePlotDistrict(plotId);

  let districtCall = contract.try_getDistrict(plotId);
  if (!districtCall.reverted) {
    let d = districtCall.value;

    entity.plot = plot.id;
    entity.kindRaw = d.kind.toString();
    entity.kindLabel = districtKindToLabel(d.kind.toString());
    entity.factionRaw = d.faction.toString();
    entity.factionLabel = factionToLabel(d.faction.toString());
    entity.bonusBps = d.bonusBps.toString();
    entity.exists = d.exists;
  }

  let borderlineCall = contract.try_isBorderline(plotId);
  if (!borderlineCall.reverted) {
    entity.isBorderline = borderlineCall.value;
  }

  entity.updatedAtBlock = blockNumber;
  entity.updatedAtTimestamp = blockTimestamp;
  entity.save();

  if (plot.faction == "unknown" && entity.factionLabel != "none") {
    plot.faction = entity.factionLabel;
    plot.save();
  }
}

// --------------------------------------------------
// Call Handlers
// --------------------------------------------------

export function handleAssignDistrict(call: AssignDistrictCall): void {
  let contract = CityDistrictsContract.bind(call.to);
  let plotId = call.inputs.plotId;

  getOrCreatePlot(plotId);
  syncDistrict(contract, plotId, call.block.number, call.block.timestamp);
}

export function handleAssignDistrictAuto(call: AssignDistrictAutoCall): void {
  let contract = CityDistrictsContract.bind(call.to);
  let plotId = call.inputs.plotId;

  getOrCreatePlot(plotId);
  syncDistrict(contract, plotId, call.block.number, call.block.timestamp);
}

export function handleSetAuthorizedCaller(call: SetAuthorizedCallerCall): void {
  let id = call.inputs.caller.toHexString();
  let entity = getOrCreateAuthorizedCaller(id);

  entity.allowed = call.inputs.allowed;
  entity.updatedAtBlock = call.block.number;
  entity.updatedAtTimestamp = call.block.timestamp;
  entity.save();
}

// --------------------------------------------------
// Event Handlers
// --------------------------------------------------

export function handleOwnershipTransferred(event: OwnershipTransferred): void {
  let entity = new CityDistrictsOwnershipTransferredEvent(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );

  entity.previousOwner = event.params.previousOwner;
  entity.newOwner = event.params.newOwner;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}