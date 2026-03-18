import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import {
  CityConfig as CityConfigContract,
  ConfigInitialized,
  CoreAddressSet,
  UintConfigSet,
  OwnershipTransferred
} from "../generated/CityConfig/CityConfig";
import {
  CityConfigState,
  CityConfigAddressEntry,
  CityConfigUintEntry,
  ConfigInitializedEvent,
  CoreAddressSetEvent,
  UintConfigSetEvent,
  ConfigOwnershipTransferredEvent
} from "../generated/schema";

// --------------------------------------------------
// Helpers
// --------------------------------------------------

function getState(): CityConfigState {
  let state = CityConfigState.load("current");
  if (state == null) {
    state = new CityConfigState("current");
    state.updatedAtBlock = BigInt.zero();
    state.updatedAtTimestamp = BigInt.zero();
  }
  return state as CityConfigState;
}

function bytesKeyId(key: Bytes): string {
  return key.toHexString();
}

function eventId(txHash: Bytes, logIndex: BigInt): string {
  return txHash.toHexString() + "-" + logIndex.toString();
}

function bytesEqual(a: Bytes, b: Bytes): boolean {
  return a.toHexString() == b.toHexString();
}

function getKeyLabel(contract: CityConfigContract, key: Bytes): string {
  let kInpi = contract.try_KEY_INPI();
  if (!kInpi.reverted && bytesEqual(key, kInpi.value)) return "KEY_INPI";

  let kInpinityNft = contract.try_KEY_INPINITY_NFT();
  if (!kInpinityNft.reverted && bytesEqual(key, kInpinityNft.value)) return "KEY_INPINITY_NFT";

  let kResourceToken = contract.try_KEY_RESOURCE_TOKEN();
  if (!kResourceToken.reverted && bytesEqual(key, kResourceToken.value)) return "KEY_RESOURCE_TOKEN";

  let kFarming = contract.try_KEY_FARMING();
  if (!kFarming.reverted && bytesEqual(key, kFarming.value)) return "KEY_FARMING";

  let kPirates = contract.try_KEY_PIRATES();
  if (!kPirates.reverted && bytesEqual(key, kPirates.value)) return "KEY_PIRATES";

  let kMercenary = contract.try_KEY_MERCENARY();
  if (!kMercenary.reverted && bytesEqual(key, kMercenary.value)) return "KEY_MERCENARY";

  let kPartnership = contract.try_KEY_PARTNERSHIP();
  if (!kPartnership.reverted && bytesEqual(key, kPartnership.value)) return "KEY_PARTNERSHIP";

  let kPitrone = contract.try_KEY_PITRONE();
  if (!kPitrone.reverted && bytesEqual(key, kPitrone.value)) return "KEY_PITRONE";

  let kTreasury = contract.try_KEY_TREASURY();
  if (!kTreasury.reverted && bytesEqual(key, kTreasury.value)) return "KEY_TREASURY";

  let kMaxPersonalPlots = contract.try_KEY_MAX_PERSONAL_PLOTS();
  if (!kMaxPersonalPlots.reverted && bytesEqual(key, kMaxPersonalPlots.value)) return "KEY_MAX_PERSONAL_PLOTS";

  let kInactivityDays = contract.try_KEY_INACTIVITY_DAYS();
  if (!kInactivityDays.reverted && bytesEqual(key, kInactivityDays.value)) return "KEY_INACTIVITY_DAYS";

  let kDormant = contract.try_KEY_DORMANT_THRESHOLD_DAYS();
  if (!kDormant.reverted && bytesEqual(key, kDormant.value)) return "KEY_DORMANT_THRESHOLD_DAYS";

  let kDecayed = contract.try_KEY_DECAYED_THRESHOLD_DAYS();
  if (!kDecayed.reverted && bytesEqual(key, kDecayed.value)) return "KEY_DECAYED_THRESHOLD_DAYS";

  let kLayerEligible = contract.try_KEY_LAYER_ELIGIBLE_THRESHOLD_DAYS();
  if (!kLayerEligible.reverted && bytesEqual(key, kLayerEligible.value)) return "KEY_LAYER_ELIGIBLE_THRESHOLD_DAYS";

  let kPersonalWidth = contract.try_KEY_PERSONAL_WIDTH();
  if (!kPersonalWidth.reverted && bytesEqual(key, kPersonalWidth.value)) return "KEY_PERSONAL_WIDTH";

  let kPersonalHeight = contract.try_KEY_PERSONAL_HEIGHT();
  if (!kPersonalHeight.reverted && bytesEqual(key, kPersonalHeight.value)) return "KEY_PERSONAL_HEIGHT";

  let kCommunityWidth = contract.try_KEY_COMMUNITY_WIDTH();
  if (!kCommunityWidth.reverted && bytesEqual(key, kCommunityWidth.value)) return "KEY_COMMUNITY_WIDTH";

  let kCommunityHeight = contract.try_KEY_COMMUNITY_HEIGHT();
  if (!kCommunityHeight.reverted && bytesEqual(key, kCommunityHeight.value)) return "KEY_COMMUNITY_HEIGHT";

  let kQubiqOil = contract.try_KEY_QUBIQ_OIL_COST();
  if (!kQubiqOil.reverted && bytesEqual(key, kQubiqOil.value)) return "KEY_QUBIQ_OIL_COST";

  let kQubiqLemons = contract.try_KEY_QUBIQ_LEMONS_COST();
  if (!kQubiqLemons.reverted && bytesEqual(key, kQubiqLemons.value)) return "KEY_QUBIQ_LEMONS_COST";

  let kQubiqIron = contract.try_KEY_QUBIQ_IRON_COST();
  if (!kQubiqIron.reverted && bytesEqual(key, kQubiqIron.value)) return "KEY_QUBIQ_IRON_COST";

  let kBuildingOil = contract.try_KEY_BUILDING_OIL_COST();
  if (!kBuildingOil.reverted && bytesEqual(key, kBuildingOil.value)) return "KEY_BUILDING_OIL_COST";

  let kBuildingLemons = contract.try_KEY_BUILDING_LEMONS_COST();
  if (!kBuildingLemons.reverted && bytesEqual(key, kBuildingLemons.value)) return "KEY_BUILDING_LEMONS_COST";

  let kBuildingIron = contract.try_KEY_BUILDING_IRON_COST();
  if (!kBuildingIron.reverted && bytesEqual(key, kBuildingIron.value)) return "KEY_BUILDING_IRON_COST";

  let kBuildingGold = contract.try_KEY_BUILDING_GOLD_COST();
  if (!kBuildingGold.reverted && bytesEqual(key, kBuildingGold.value)) return "KEY_BUILDING_GOLD_COST";

  let kInitialFee = contract.try_KEY_INITIAL_FEE_BPS();
  if (!kInitialFee.reverted && bytesEqual(key, kInitialFee.value)) return "KEY_INITIAL_FEE_BPS";

  return "";
}

function syncOwner(contract: CityConfigContract, blockNumber: BigInt, timestamp: BigInt): void {
  let state = getState();
  let ownerCall = contract.try_owner();
  if (!ownerCall.reverted) {
    state.owner = ownerCall.value;
  }
  state.updatedAtBlock = blockNumber;
  state.updatedAtTimestamp = timestamp;
  state.save();
}

// --------------------------------------------------
// Event handlers
// --------------------------------------------------

export function handleConfigInitialized(event: ConfigInitialized): void {
  let contract = CityConfigContract.bind(event.address);

  let state = getState();
  state.admin = event.params.admin;

  let ownerCall = contract.try_owner();
  if (!ownerCall.reverted) {
    state.owner = ownerCall.value;
  }

  state.initializedAtBlock = event.block.number;
  state.initializedAtTimestamp = event.block.timestamp;
  state.updatedAtBlock = event.block.number;
  state.updatedAtTimestamp = event.block.timestamp;
  state.save();

  let entity = new ConfigInitializedEvent(
    eventId(event.transaction.hash, event.logIndex)
  );
  entity.admin = event.params.admin;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}

export function handleCoreAddressSet(event: CoreAddressSet): void {
  let contract = CityConfigContract.bind(event.address);
  let id = bytesKeyId(event.params.key);
  let label = getKeyLabel(contract, event.params.key);

  let entry = CityConfigAddressEntry.load(id);
  if (entry == null) {
    entry = new CityConfigAddressEntry(id);
    entry.key = event.params.key;
  }
  entry.value = event.params.value;
  entry.keyLabel = label == "" ? null : label;
  entry.updatedAtBlock = event.block.number;
  entry.updatedAtTimestamp = event.block.timestamp;
  entry.save();

  let entity = new CoreAddressSetEvent(
    eventId(event.transaction.hash, event.logIndex)
  );
  entity.key = event.params.key;
  entity.value = event.params.value;
  entity.keyLabel = label == "" ? null : label;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();

  syncOwner(contract, event.block.number, event.block.timestamp);
}

export function handleUintConfigSet(event: UintConfigSet): void {
  let contract = CityConfigContract.bind(event.address);
  let id = bytesKeyId(event.params.key);
  let label = getKeyLabel(contract, event.params.key);

  let entry = CityConfigUintEntry.load(id);
  if (entry == null) {
    entry = new CityConfigUintEntry(id);
    entry.key = event.params.key;
  }
  entry.value = event.params.value;
  entry.keyLabel = label == "" ? null : label;
  entry.updatedAtBlock = event.block.number;
  entry.updatedAtTimestamp = event.block.timestamp;
  entry.save();

  let entity = new UintConfigSetEvent(
    eventId(event.transaction.hash, event.logIndex)
  );
  entity.key = event.params.key;
  entity.value = event.params.value;
  entity.keyLabel = label == "" ? null : label;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();

  syncOwner(contract, event.block.number, event.block.timestamp);
}

export function handleOwnershipTransferred(event: OwnershipTransferred): void {
  let state = getState();
  state.owner = event.params.newOwner;
  state.updatedAtBlock = event.block.number;
  state.updatedAtTimestamp = event.block.timestamp;
  state.save();

  let entity = new ConfigOwnershipTransferredEvent(
    eventId(event.transaction.hash, event.logIndex)
  );
  entity.previousOwner = event.params.previousOwner;
  entity.newOwner = event.params.newOwner;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}