import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import {
  ApprovalForAll,
  AuthorizedConsumerSet,
  AuthorizedMinterSet,
  BaseMetadataURISet,
  MateriaItemBurned,
  MateriaItemDefinitionSet,
  MateriaItemMinted,
  OwnershipTransferred,
  TransferBatch,
  TransferSingle,
  URI
} from "../generated/CityMateriaItems/CityMateriaItems";
import {
  MateriaItemDefinition,
  MateriaItemAuthorizedConsumer,
  MateriaItemAuthorizedMinter,
  MateriaItemApprovalForAllEvent,
  MateriaItemBaseMetadataURISetEvent,
  MateriaItemBurnedEvent,
  MateriaItemMintedEvent,
  MateriaItemTransferSingleEvent,
  MateriaItemTransferBatchEvent,
  MateriaItemURIEvent,
  CityMateriaItemsOwnershipTransferredEvent
} from "../generated/schema";

// --------------------------------------------------
// Helpers
// --------------------------------------------------

function makeEventId(hash: Bytes, logIndex: BigInt): string {
  return hash.toHexString() + "-" + logIndex.toString();
}

function getOrCreateMateriaItemDefinition(itemId: BigInt): MateriaItemDefinition {
  let id = itemId.toString();
  let entity = MateriaItemDefinition.load(id);

  if (entity == null) {
    entity = new MateriaItemDefinition(id);
    entity.itemId = itemId;
    entity.materiaDefinitionId = BigInt.zero();
    entity.level = BigInt.zero();
    entity.rarityTier = BigInt.zero();
    entity.burnOnUse = false;
    entity.enabled = false;
    entity.updatedAtBlock = BigInt.zero();
    entity.updatedAtTimestamp = BigInt.zero();
  }

  return entity as MateriaItemDefinition;
}

function getOrCreateAuthorizedConsumer(account: string): MateriaItemAuthorizedConsumer {
  let entity = MateriaItemAuthorizedConsumer.load(account);

  if (entity == null) {
    entity = new MateriaItemAuthorizedConsumer(account);
    entity.allowed = false;
    entity.updatedAtBlock = BigInt.zero();
    entity.updatedAtTimestamp = BigInt.zero();
  }

  return entity as MateriaItemAuthorizedConsumer;
}

function getOrCreateAuthorizedMinter(account: string): MateriaItemAuthorizedMinter {
  let entity = MateriaItemAuthorizedMinter.load(account);

  if (entity == null) {
    entity = new MateriaItemAuthorizedMinter(account);
    entity.allowed = false;
    entity.updatedAtBlock = BigInt.zero();
    entity.updatedAtTimestamp = BigInt.zero();
  }

  return entity as MateriaItemAuthorizedMinter;
}

// --------------------------------------------------
// Event handlers
// --------------------------------------------------

export function handleAuthorizedConsumerSet(event: AuthorizedConsumerSet): void {
  let entity = getOrCreateAuthorizedConsumer(event.params.consumer.toHexString());
  entity.allowed = event.params.allowed;
  entity.updatedAtBlock = event.block.number;
  entity.updatedAtTimestamp = event.block.timestamp;
  entity.save();
}

export function handleAuthorizedMinterSet(event: AuthorizedMinterSet): void {
  let entity = getOrCreateAuthorizedMinter(event.params.minter.toHexString());
  entity.allowed = event.params.allowed;
  entity.updatedAtBlock = event.block.number;
  entity.updatedAtTimestamp = event.block.timestamp;
  entity.save();
}

export function handleBaseMetadataURISet(event: BaseMetadataURISet): void {
  let entity = new MateriaItemBaseMetadataURISetEvent(
    makeEventId(event.transaction.hash, event.logIndex)
  );
  entity.newBaseMetadataURI = event.params.newBaseMetadataURI;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}

export function handleMateriaItemDefinitionSet(event: MateriaItemDefinitionSet): void {
  let entity = getOrCreateMateriaItemDefinition(event.params.itemId);

  entity.itemId = event.params.itemId;
  entity.materiaDefinitionId = event.params.materiaDefinitionId;
  entity.level = event.params.level;
  entity.rarityTier = event.params.rarityTier;
  entity.burnOnUse = event.params.burnOnUse;
  entity.enabled = event.params.enabled;
  entity.updatedAtBlock = event.block.number;
  entity.updatedAtTimestamp = event.block.timestamp;
  entity.save();
}

export function handleMateriaItemMinted(event: MateriaItemMinted): void {
  let entity = new MateriaItemMintedEvent(
    makeEventId(event.transaction.hash, event.logIndex)
  );
  entity.to = event.params.to;
  entity.itemId = event.params.itemId;
  entity.amount = event.params.amount;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}

export function handleMateriaItemBurned(event: MateriaItemBurned): void {
  let entity = new MateriaItemBurnedEvent(
    makeEventId(event.transaction.hash, event.logIndex)
  );
  entity.from = event.params.from;
  entity.itemId = event.params.itemId;
  entity.amount = event.params.amount;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}

export function handleApprovalForAll(event: ApprovalForAll): void {
  let entity = new MateriaItemApprovalForAllEvent(
    makeEventId(event.transaction.hash, event.logIndex)
  );
  entity.account = event.params.account;
  entity.operator = event.params.operator;
  entity.approved = event.params.approved;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}

export function handleTransferSingle(event: TransferSingle): void {
  let entity = new MateriaItemTransferSingleEvent(
    makeEventId(event.transaction.hash, event.logIndex)
  );
  entity.operator = event.params.operator;
  entity.from = event.params.from;
  entity.to = event.params.to;
  entity.tokenId = event.params.id;
  entity.value = event.params.value;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}

export function handleTransferBatch(event: TransferBatch): void {
  let entity = new MateriaItemTransferBatchEvent(
    makeEventId(event.transaction.hash, event.logIndex)
  );
  entity.operator = event.params.operator;
  entity.from = event.params.from;
  entity.to = event.params.to;
  entity.ids = event.params.ids;
  entity.values = event.params.values;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}

export function handleURI(event: URI): void {
  let entity = new MateriaItemURIEvent(
    makeEventId(event.transaction.hash, event.logIndex)
  );
  entity.value = event.params.value;
  entity.tokenId = event.params.id;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}

export function handleOwnershipTransferred(event: OwnershipTransferred): void {
  let entity = new CityMateriaItemsOwnershipTransferredEvent(
    makeEventId(event.transaction.hash, event.logIndex)
  );
  entity.previousOwner = event.params.previousOwner;
  entity.newOwner = event.params.newOwner;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}