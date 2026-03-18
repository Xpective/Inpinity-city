import { Address, BigInt } from "@graphprotocol/graph-ts";
import {
  ApprovalForAll,
  AuthorizedConsumerSet,
  AuthorizedMinterSet,
  BaseMetadataURISet,
  ComponentBurned,
  ComponentDefinitionSet,
  ComponentMinted,
  OwnershipTransferred,
  TransferBatch,
  TransferSingle,
  URI
} from "../generated/CityComponents/CityComponents";
import {
  Player,
  ComponentDefinition,
  ComponentAuthorizedConsumer,
  ComponentAuthorizedMinter,
  ComponentBaseMetadataURI,
  ComponentBalance,
  ComponentMintEvent,
  ComponentBurnEvent,
  ComponentTransferSingleEvent,
  ComponentTransferBatchEvent,
  ComponentApprovalForAllEvent,
  ComponentURIEvent,
  CityComponentsOwnershipTransferredEvent
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

function getOrCreateComponentDefinition(componentId: BigInt): ComponentDefinition {
  let id = componentId.toString();
  let entity = ComponentDefinition.load(id);

  if (entity == null) {
    entity = new ComponentDefinition(id);
    entity.componentId = componentId;
    entity.name = "";
    entity.category = BigInt.zero();
    entity.rarityTier = BigInt.zero();
    entity.techTier = BigInt.zero();
    entity.enabled = false;
    entity.updatedAtBlock = BigInt.zero();
    entity.updatedAtTimestamp = BigInt.zero();
  }

  return entity as ComponentDefinition;
}

function getOrCreateComponentAuthorizedConsumer(account: string): ComponentAuthorizedConsumer {
  let entity = ComponentAuthorizedConsumer.load(account);

  if (entity == null) {
    entity = new ComponentAuthorizedConsumer(account);
    entity.allowed = false;
    entity.updatedAtBlock = BigInt.zero();
    entity.updatedAtTimestamp = BigInt.zero();
  }

  return entity as ComponentAuthorizedConsumer;
}

function getOrCreateComponentAuthorizedMinter(account: string): ComponentAuthorizedMinter {
  let entity = ComponentAuthorizedMinter.load(account);

  if (entity == null) {
    entity = new ComponentAuthorizedMinter(account);
    entity.allowed = false;
    entity.updatedAtBlock = BigInt.zero();
    entity.updatedAtTimestamp = BigInt.zero();
  }

  return entity as ComponentAuthorizedMinter;
}

function getOrCreateComponentBaseMetadataURI(): ComponentBaseMetadataURI {
  let entity = ComponentBaseMetadataURI.load("current");

  if (entity == null) {
    entity = new ComponentBaseMetadataURI("current");
    entity.uri = "";
    entity.updatedAtBlock = BigInt.zero();
    entity.updatedAtTimestamp = BigInt.zero();
  }

  return entity as ComponentBaseMetadataURI;
}

function getBalanceId(account: string, componentId: BigInt): string {
  return account + "-" + componentId.toString();
}

function getOrCreateComponentBalance(account: string, componentId: BigInt): ComponentBalance {
  let id = getBalanceId(account, componentId);
  let entity = ComponentBalance.load(id);

  if (entity == null) {
    entity = new ComponentBalance(id);
    entity.account = account;
    entity.component = componentId.toString();
    entity.amount = BigInt.zero();
    entity.updatedAtBlock = BigInt.zero();
    entity.updatedAtTimestamp = BigInt.zero();
  }

  getOrCreatePlayer(account).save();
  getOrCreateComponentDefinition(componentId).save();

  return entity as ComponentBalance;
}

function setBalance(
  account: string,
  componentId: BigInt,
  newAmount: BigInt,
  blockNumber: BigInt,
  blockTimestamp: BigInt
): void {
  let entity = getOrCreateComponentBalance(account, componentId);
  entity.amount = newAmount;
  entity.updatedAtBlock = blockNumber;
  entity.updatedAtTimestamp = blockTimestamp;
  entity.save();
}

function addBalance(
  account: string,
  componentId: BigInt,
  delta: BigInt,
  blockNumber: BigInt,
  blockTimestamp: BigInt
): void {
  let entity = getOrCreateComponentBalance(account, componentId);
  entity.amount = entity.amount.plus(delta);
  entity.updatedAtBlock = blockNumber;
  entity.updatedAtTimestamp = blockTimestamp;
  entity.save();
}

function subBalance(
  account: string,
  componentId: BigInt,
  delta: BigInt,
  blockNumber: BigInt,
  blockTimestamp: BigInt
): void {
  let entity = getOrCreateComponentBalance(account, componentId);

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

export function handleComponentDefinitionSet(event: ComponentDefinitionSet): void {
  let entity = getOrCreateComponentDefinition(event.params.componentId);

  entity.componentId = event.params.componentId;
  entity.name = event.params.name;
  entity.category = event.params.category;
  entity.rarityTier = event.params.rarityTier;
  entity.techTier = event.params.techTier;
  entity.enabled = event.params.enabled;
  entity.updatedAtBlock = event.block.number;
  entity.updatedAtTimestamp = event.block.timestamp;
  entity.save();
}

export function handleAuthorizedConsumerSet(event: AuthorizedConsumerSet): void {
  let id = event.params.consumer.toHexString();
  let entity = getOrCreateComponentAuthorizedConsumer(id);

  entity.allowed = event.params.allowed;
  entity.updatedAtBlock = event.block.number;
  entity.updatedAtTimestamp = event.block.timestamp;
  entity.save();
}

export function handleAuthorizedMinterSet(event: AuthorizedMinterSet): void {
  let id = event.params.minter.toHexString();
  let entity = getOrCreateComponentAuthorizedMinter(id);

  entity.allowed = event.params.allowed;
  entity.updatedAtBlock = event.block.number;
  entity.updatedAtTimestamp = event.block.timestamp;
  entity.save();
}

export function handleBaseMetadataURISet(event: BaseMetadataURISet): void {
  let entity = getOrCreateComponentBaseMetadataURI();

  entity.uri = event.params.newBaseMetadataURI;
  entity.updatedAtBlock = event.block.number;
  entity.updatedAtTimestamp = event.block.timestamp;
  entity.save();
}

export function handleComponentMinted(event: ComponentMinted): void {
  let toId = event.params.to.toHexString();

  addBalance(
    toId,
    event.params.componentId,
    event.params.amount,
    event.block.number,
    event.block.timestamp
  );

  let entity = new ComponentMintEvent(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  entity.to = event.params.to;
  entity.component = event.params.componentId.toString();
  entity.amount = event.params.amount;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}

export function handleComponentBurned(event: ComponentBurned): void {
  let fromId = event.params.from.toHexString();

  subBalance(
    fromId,
    event.params.componentId,
    event.params.amount,
    event.block.number,
    event.block.timestamp
  );

  let entity = new ComponentBurnEvent(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  entity.from = event.params.from;
  entity.component = event.params.componentId.toString();
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

  let entity = new ComponentTransferSingleEvent(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  entity.operator = event.params.operator;
  entity.from = event.params.from;
  entity.to = event.params.to;
  entity.componentId = id;
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
    let componentId = ids[i];
    let amount = values[i];

    if (!isZeroAddress(fromAddr)) {
      subBalance(
        fromAddr.toHexString(),
        componentId,
        amount,
        event.block.number,
        event.block.timestamp
      );
    }

    if (!isZeroAddress(toAddr)) {
      addBalance(
        toAddr.toHexString(),
        componentId,
        amount,
        event.block.number,
        event.block.timestamp
      );
    }

    i = i + 1;
  }

  let entity = new ComponentTransferBatchEvent(
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

  let entity = new ComponentApprovalForAllEvent(
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
  let def = getOrCreateComponentDefinition(event.params.id);
  def.updatedAtBlock = event.block.number;
  def.updatedAtTimestamp = event.block.timestamp;
  def.save();

  let entity = new ComponentURIEvent(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  entity.value = event.params.value;
  entity.componentId = event.params.id;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}

export function handleOwnershipTransferred(event: OwnershipTransferred): void {
  let entity = new CityComponentsOwnershipTransferredEvent(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  entity.previousOwner = event.params.previousOwner;
  entity.newOwner = event.params.newOwner;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}