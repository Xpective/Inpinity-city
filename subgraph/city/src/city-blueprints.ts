import { Address, BigInt } from "@graphprotocol/graph-ts";
import {
  ApprovalForAll,
  AuthorizedConsumerSet,
  AuthorizedMinterSet,
  BaseMetadataURISet,
  BlueprintBurned,
  BlueprintDefinitionSet,
  BlueprintMinted,
  OwnershipTransferred,
  TransferBatch,
  TransferSingle,
  URI
} from "../generated/CityBlueprints/CityBlueprints";
import {
  Player,
  BlueprintDefinition,
  BlueprintAuthorizedConsumer,
  BlueprintAuthorizedMinter,
  BlueprintBaseMetadataURI,
  BlueprintBalance,
  BlueprintMintEvent,
  BlueprintBurnEvent,
  BlueprintTransferSingleEvent,
  BlueprintTransferBatchEvent,
  BlueprintApprovalForAllEvent,
  BlueprintURIEvent,
  CityBlueprintsOwnershipTransferredEvent
} from "../generated/schema";

// --------------------------------------------------
// Helpers
// --------------------------------------------------

function getOrCreatePlayer(id: string): Player {
  let entity = Player.load(id);

  if (entity == null) {
    entity = new Player(id);
    entity.personalPlotCount = 0;
  }

  return entity as Player;
}

function getOrCreateBlueprintDefinition(blueprintId: BigInt): BlueprintDefinition {
  let id = blueprintId.toString();
  let entity = BlueprintDefinition.load(id);

  if (entity == null) {
    entity = new BlueprintDefinition(id);
    entity.blueprintId = blueprintId;
    entity.name = "";
    entity.rarityTier = BigInt.zero();
    entity.techTier = BigInt.zero();
    entity.factionLock = BigInt.zero();
    entity.districtLock = BigInt.zero();
    entity.enabled = false;
    entity.updatedAtBlock = BigInt.zero();
    entity.updatedAtTimestamp = BigInt.zero();
  }

  return entity as BlueprintDefinition;
}

function getOrCreateBlueprintAuthorizedConsumer(account: string): BlueprintAuthorizedConsumer {
  let entity = BlueprintAuthorizedConsumer.load(account);

  if (entity == null) {
    entity = new BlueprintAuthorizedConsumer(account);
    entity.allowed = false;
    entity.updatedAtBlock = BigInt.zero();
    entity.updatedAtTimestamp = BigInt.zero();
  }

  return entity as BlueprintAuthorizedConsumer;
}

function getOrCreateBlueprintAuthorizedMinter(account: string): BlueprintAuthorizedMinter {
  let entity = BlueprintAuthorizedMinter.load(account);

  if (entity == null) {
    entity = new BlueprintAuthorizedMinter(account);
    entity.allowed = false;
    entity.updatedAtBlock = BigInt.zero();
    entity.updatedAtTimestamp = BigInt.zero();
  }

  return entity as BlueprintAuthorizedMinter;
}

function getOrCreateBlueprintBaseMetadataURI(): BlueprintBaseMetadataURI {
  let entity = BlueprintBaseMetadataURI.load("current");

  if (entity == null) {
    entity = new BlueprintBaseMetadataURI("current");
    entity.uri = "";
    entity.updatedAtBlock = BigInt.zero();
    entity.updatedAtTimestamp = BigInt.zero();
  }

  return entity as BlueprintBaseMetadataURI;
}

function getBalanceId(account: string, blueprintId: BigInt): string {
  return account + "-" + blueprintId.toString();
}

function getOrCreateBlueprintBalance(account: string, blueprintId: BigInt): BlueprintBalance {
  let id = getBalanceId(account, blueprintId);
  let entity = BlueprintBalance.load(id);

  if (entity == null) {
    entity = new BlueprintBalance(id);
    entity.account = account;
    entity.blueprint = blueprintId.toString();
    entity.amount = BigInt.zero();
    entity.updatedAtBlock = BigInt.zero();
    entity.updatedAtTimestamp = BigInt.zero();
  }

  getOrCreatePlayer(account).save();
  getOrCreateBlueprintDefinition(blueprintId).save();

  return entity as BlueprintBalance;
}

function addBalance(
  account: string,
  blueprintId: BigInt,
  delta: BigInt,
  blockNumber: BigInt,
  blockTimestamp: BigInt
): void {
  let entity = getOrCreateBlueprintBalance(account, blueprintId);
  entity.amount = entity.amount.plus(delta);
  entity.updatedAtBlock = blockNumber;
  entity.updatedAtTimestamp = blockTimestamp;
  entity.save();
}

function subBalance(
  account: string,
  blueprintId: BigInt,
  delta: BigInt,
  blockNumber: BigInt,
  blockTimestamp: BigInt
): void {
  let entity = getOrCreateBlueprintBalance(account, blueprintId);

  if (entity.amount.ge(delta)) {
    entity.amount = entity.amount.minus(delta);
  } else {
    entity.amount = BigInt.zero();
  }

  entity.updatedAtBlock = blockNumber;
  entity.updatedAtTimestamp = blockTimestamp;
  entity.save();
}

function isZeroAddress(addr: Address): boolean {
  return addr.toHexString() == "0x0000000000000000000000000000000000000000";
}

// --------------------------------------------------
// Event handlers
// --------------------------------------------------

export function handleBlueprintDefinitionSet(event: BlueprintDefinitionSet): void {
  let entity = getOrCreateBlueprintDefinition(event.params.blueprintId);

  entity.blueprintId = event.params.blueprintId;
  entity.name = event.params.name;
  entity.rarityTier = event.params.rarityTier;
  entity.techTier = event.params.techTier;
  entity.factionLock = event.params.factionLock;
  entity.districtLock = event.params.districtLock;
  entity.enabled = event.params.enabled;
  entity.updatedAtBlock = event.block.number;
  entity.updatedAtTimestamp = event.block.timestamp;
  entity.save();
}

export function handleAuthorizedConsumerSet(event: AuthorizedConsumerSet): void {
  let id = event.params.consumer.toHexString();
  let entity = getOrCreateBlueprintAuthorizedConsumer(id);

  entity.allowed = event.params.allowed;
  entity.updatedAtBlock = event.block.number;
  entity.updatedAtTimestamp = event.block.timestamp;
  entity.save();
}

export function handleAuthorizedMinterSet(event: AuthorizedMinterSet): void {
  let id = event.params.minter.toHexString();
  let entity = getOrCreateBlueprintAuthorizedMinter(id);

  entity.allowed = event.params.allowed;
  entity.updatedAtBlock = event.block.number;
  entity.updatedAtTimestamp = event.block.timestamp;
  entity.save();
}

export function handleBaseMetadataURISet(event: BaseMetadataURISet): void {
  let entity = getOrCreateBlueprintBaseMetadataURI();

  entity.uri = event.params.newBaseMetadataURI;
  entity.updatedAtBlock = event.block.number;
  entity.updatedAtTimestamp = event.block.timestamp;
  entity.save();
}

export function handleBlueprintMinted(event: BlueprintMinted): void {
  let toId = event.params.to.toHexString();

  addBalance(
    toId,
    event.params.blueprintId,
    event.params.amount,
    event.block.number,
    event.block.timestamp
  );

  let entity = new BlueprintMintEvent(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  entity.to = event.params.to;
  entity.blueprint = event.params.blueprintId.toString();
  entity.amount = event.params.amount;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}

export function handleBlueprintBurned(event: BlueprintBurned): void {
  let fromId = event.params.from.toHexString();

  subBalance(
    fromId,
    event.params.blueprintId,
    event.params.amount,
    event.block.number,
    event.block.timestamp
  );

  let entity = new BlueprintBurnEvent(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  entity.from = event.params.from;
  entity.blueprint = event.params.blueprintId.toString();
  entity.amount = event.params.amount;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}

export function handleTransferSingle(event: TransferSingle): void {
  let fromAddr = event.params.from;
  let toAddr = event.params.to;
  let id = event.params.id;
  let value = event.params.value;

  if (!isZeroAddress(fromAddr)) {
    subBalance(
      fromAddr.toHexString(),
      id,
      value,
      event.block.number,
      event.block.timestamp
    );
  }

  if (!isZeroAddress(toAddr)) {
    addBalance(
      toAddr.toHexString(),
      id,
      value,
      event.block.number,
      event.block.timestamp
    );
  }

  let entity = new BlueprintTransferSingleEvent(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  entity.operator = event.params.operator;
  entity.from = event.params.from;
  entity.to = event.params.to;
  entity.blueprintId = id;
  entity.value = value;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}

export function handleTransferBatch(event: TransferBatch): void {
  let fromAddr = event.params.from;
  let toAddr = event.params.to;
  let ids = event.params.ids;
  let values = event.params.values;

  let i = 0;
  while (i < ids.length) {
    let blueprintId = ids[i];
    let amount = values[i];

    if (!isZeroAddress(fromAddr)) {
      subBalance(
        fromAddr.toHexString(),
        blueprintId,
        amount,
        event.block.number,
        event.block.timestamp
      );
    }

    if (!isZeroAddress(toAddr)) {
      addBalance(
        toAddr.toHexString(),
        blueprintId,
        amount,
        event.block.number,
        event.block.timestamp
      );
    }

    i = i + 1;
  }

  let entity = new BlueprintTransferBatchEvent(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
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

export function handleApprovalForAll(event: ApprovalForAll): void {
  getOrCreatePlayer(event.params.account.toHexString()).save();
  getOrCreatePlayer(event.params.operator.toHexString()).save();

  let entity = new BlueprintApprovalForAllEvent(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  entity.account = event.params.account;
  entity.operator = event.params.operator;
  entity.approved = event.params.approved;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}

export function handleURI(event: URI): void {
  let def = getOrCreateBlueprintDefinition(event.params.id);
  def.updatedAtBlock = event.block.number;
  def.updatedAtTimestamp = event.block.timestamp;
  def.save();

  let entity = new BlueprintURIEvent(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  entity.value = event.params.value;
  entity.blueprintId = event.params.id;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}

export function handleOwnershipTransferred(event: OwnershipTransferred): void {
  let entity = new CityBlueprintsOwnershipTransferredEvent(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  entity.previousOwner = event.params.previousOwner;
  entity.newOwner = event.params.newOwner;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}