import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import {
  ApprovalForAll,
  AuthorizedConsumerSet,
  AuthorizedMinterSet,
  BaseMetadataURISet,
  EnchantmentItemBurned,
  EnchantmentItemDefinitionSet,
  EnchantmentItemMinted,
  OwnershipTransferred,
  TransferBatch,
  TransferSingle,
  URI
} from "../generated/CityEnchantmentItems/CityEnchantmentItems";
import {
  EnchantmentItemDefinition,
  EnchantmentItemAuthorizedConsumer,
  EnchantmentItemAuthorizedMinter,
  EnchantmentItemApprovalForAllEvent,
  EnchantmentItemBaseMetadataURISetEvent,
  EnchantmentItemBurnedEvent,
  EnchantmentItemMintedEvent,
  EnchantmentItemTransferSingleEvent,
  EnchantmentItemTransferBatchEvent,
  EnchantmentItemURIEvent,
  CityEnchantmentItemsOwnershipTransferredEvent
} from "../generated/schema";

// --------------------------------------------------
// Helpers
// --------------------------------------------------

function getOrCreateEnchantmentItemDefinition(itemId: BigInt): EnchantmentItemDefinition {
  let id = itemId.toString();
  let entity = EnchantmentItemDefinition.load(id);

  if (entity == null) {
    entity = new EnchantmentItemDefinition(id);
    entity.itemId = itemId;
    entity.enchantmentDefinitionId = BigInt.zero();
    entity.level = BigInt.zero();
    entity.rarityTier = BigInt.zero();
    entity.burnOnUse = false;
    entity.enabled = false;
    entity.updatedAtBlock = BigInt.zero();
    entity.updatedAtTimestamp = BigInt.zero();
  }

  return entity as EnchantmentItemDefinition;
}

function getOrCreateAuthorizedConsumer(account: string): EnchantmentItemAuthorizedConsumer {
  let entity = EnchantmentItemAuthorizedConsumer.load(account);

  if (entity == null) {
    entity = new EnchantmentItemAuthorizedConsumer(account);
    entity.allowed = false;
    entity.updatedAtBlock = BigInt.zero();
    entity.updatedAtTimestamp = BigInt.zero();
  }

  return entity as EnchantmentItemAuthorizedConsumer;
}

function getOrCreateAuthorizedMinter(account: string): EnchantmentItemAuthorizedMinter {
  let entity = EnchantmentItemAuthorizedMinter.load(account);

  if (entity == null) {
    entity = new EnchantmentItemAuthorizedMinter(account);
    entity.allowed = false;
    entity.updatedAtBlock = BigInt.zero();
    entity.updatedAtTimestamp = BigInt.zero();
  }

  return entity as EnchantmentItemAuthorizedMinter;
}

function makeEventId(hash: Bytes, logIndex: BigInt): string {
  return hash.toHexString() + "-" + logIndex.toString();
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
  let entity = new EnchantmentItemBaseMetadataURISetEvent(
    makeEventId(event.transaction.hash, event.logIndex)
  );
  entity.newBaseMetadataURI = event.params.newBaseMetadataURI;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}

export function handleEnchantmentItemDefinitionSet(event: EnchantmentItemDefinitionSet): void {
  let entity = getOrCreateEnchantmentItemDefinition(event.params.itemId);

  entity.itemId = event.params.itemId;
  entity.enchantmentDefinitionId = event.params.enchantmentDefinitionId;
  entity.level = event.params.level;
  entity.rarityTier = event.params.rarityTier;
  entity.burnOnUse = event.params.burnOnUse;
  entity.enabled = event.params.enabled;
  entity.updatedAtBlock = event.block.number;
  entity.updatedAtTimestamp = event.block.timestamp;
  entity.save();
}

export function handleEnchantmentItemMinted(event: EnchantmentItemMinted): void {
  let entity = new EnchantmentItemMintedEvent(
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

export function handleEnchantmentItemBurned(event: EnchantmentItemBurned): void {
  let entity = new EnchantmentItemBurnedEvent(
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
  let entity = new EnchantmentItemApprovalForAllEvent(
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
  let entity = new EnchantmentItemTransferSingleEvent(
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
  let entity = new EnchantmentItemTransferBatchEvent(
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
  let entity = new EnchantmentItemURIEvent(
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
  let entity = new CityEnchantmentItemsOwnershipTransferredEvent(
    makeEventId(event.transaction.hash, event.logIndex)
  );
  entity.previousOwner = event.params.previousOwner;
  entity.newOwner = event.params.newOwner;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}