import { BigInt, Bytes } from "@graphprotocol/graph-ts";
// Address-Import entfernt (nicht benötigt)

import {
  CityWeapons as CityWeaponsContract,
  WeaponDefinitionSet,
  WeaponMinted,
  WeaponMetadataRevisionSet,
  WeaponUpgradeLevelSet,
  WeaponDurabilitySet,
  WeaponBonusesSet,
  AuthorizedMinterSet,
  BaseURISet,
  WeaponSocketsSet,
  WeaponsPausedSet,
  OwnershipTransferred,
  Transfer,
  Approval,
  ApprovalForAll
} from "../generated/CityWeapons/CityWeapons";
import {
  Player,
  WeaponDefinition,
  WeaponInstance,
  WeaponBonuses,
  AuthorizedMinter,
  BaseURI,
  WeaponSockets,
  WeaponsPaused,
  OwnershipTransferredEvent,
  TransferEvent,
  ApprovalEvent,
  ApprovalForAllEvent
} from "../generated/schema";

// ----------------------------------------------------------------------
// Hilfsfunktionen
// ----------------------------------------------------------------------

function getOrCreatePlayer(id: string): Player {
  let player = Player.load(id);
  if (player == null) {
    player = new Player(id);
    player.personalPlotCount = 0;
    player.save();
  }
  return player as Player;
}

function getOrCreateWeaponDefinition(id: string): WeaponDefinition {
  let entity = WeaponDefinition.load(id);
  if (entity == null) {
    entity = new WeaponDefinition(id);

    entity.weaponDefinitionId = BigInt.fromString(id);
    entity.name = "";
    entity.classId = 0;
    entity.damageTypeId = 0;
    entity.techTier = BigInt.zero();

    entity.requiredLevel = BigInt.zero();
    entity.requiredTechTier = BigInt.zero();
    entity.minDamage = BigInt.zero();
    entity.maxDamage = BigInt.zero();
    entity.attackSpeed = BigInt.zero();
    entity.critChanceBps = BigInt.zero();
    entity.critMultiplierBps = BigInt.zero();
    entity.accuracyBps = BigInt.zero();
    entity.range = BigInt.zero();
    entity.maxDurability = BigInt.zero();
    entity.armorPenBps = BigInt.zero();
    entity.blockChanceBps = BigInt.zero();
    entity.lifeStealBps = BigInt.zero();
    entity.energyCost = BigInt.zero();
    entity.heatGeneration = BigInt.zero();
    entity.stability = BigInt.zero();
    entity.cooldownMs = BigInt.zero();
    entity.projectileSpeed = BigInt.zero();
    entity.aoeRadius = BigInt.zero();
    entity.enchantmentSlots = BigInt.zero();
    entity.materiaSlots = BigInt.zero();
    entity.visualVariant = BigInt.zero();
    entity.maxUpgradeLevel = BigInt.zero();
    entity.familySetId = BigInt.zero();

    entity.enabled = false;
    entity.createdAtBlock = BigInt.zero();
    entity.createdAtTimestamp = BigInt.zero();
  }
  return entity as WeaponDefinition;
}

function getOrCreateWeaponInstance(id: string, ownerId: string, weaponDefinitionId: string): WeaponInstance {
  let instance = WeaponInstance.load(id);
  if (instance == null) {
    instance = new WeaponInstance(id);
    instance.tokenId = BigInt.fromString(id);
    instance.owner = ownerId;
    instance.weaponDefinition = weaponDefinitionId;

    instance.rarityTier = BigInt.zero();
    instance.frameTier = BigInt.zero();
    instance.durability = BigInt.zero();
    instance.upgradeLevel = BigInt.zero();
    instance.metadataRevision = BigInt.zero();

    instance.originPlotId = BigInt.zero();
    instance.originFaction = BigInt.zero();
    instance.originDistrictKind = BigInt.zero();
    instance.craftedAt = BigInt.zero();
    instance.visualVariant = BigInt.zero();
    instance.resonanceType = 0;
    instance.craftSeed = Bytes.empty();      // statt new Bytes(32)
    instance.provenanceHash = Bytes.empty(); // statt new Bytes(32)
    instance.genesisEra = false;
    instance.usedAether = false;

    instance.txHash = Bytes.empty();         // statt new Bytes(32)
    instance.blockNumber = BigInt.zero();
  }
  return instance as WeaponInstance;
}

function syncWeaponDefinition(contract: CityWeaponsContract, weaponDefinitionId: BigInt, blockNumber: BigInt, blockTimestamp: BigInt): void {
  let call = contract.try_weaponDefinitionOf(weaponDefinitionId);
  if (call.reverted) return;

  let def = call.value;
  let entity = getOrCreateWeaponDefinition(weaponDefinitionId.toString());

  entity.weaponDefinitionId = def.value0;
  entity.name = def.value1;
  entity.classId = def.value2;
  entity.damageTypeId = def.value3;
  entity.techTier = def.value4;

  entity.requiredLevel = def.value5;
  entity.requiredTechTier = def.value6;
  entity.minDamage = def.value7;
  entity.maxDamage = def.value8;
  entity.attackSpeed = def.value9;
  entity.critChanceBps = def.value10;
  entity.critMultiplierBps = def.value11;
  entity.accuracyBps = def.value12;
  entity.range = def.value13;
  entity.maxDurability = def.value14;
  entity.armorPenBps = def.value15;
  entity.blockChanceBps = def.value16;
  entity.lifeStealBps = def.value17;
  entity.energyCost = def.value18;
  entity.heatGeneration = def.value19;
  entity.stability = def.value20;
  entity.cooldownMs = def.value21;
  entity.projectileSpeed = def.value22;
  entity.aoeRadius = def.value23;
  entity.enchantmentSlots = def.value24;
  entity.materiaSlots = def.value25;
  entity.visualVariant = def.value26;
  entity.maxUpgradeLevel = def.value27;
  entity.familySetId = def.value28;

  entity.enabled = def.value29;

  if (entity.createdAtBlock.equals(BigInt.zero())) {
    entity.createdAtBlock = blockNumber;
  }
  if (entity.createdAtTimestamp.equals(BigInt.zero())) {
    entity.createdAtTimestamp = blockTimestamp;
  }

  entity.save();
}

function syncWeaponInstance(
  contract: CityWeaponsContract,
  tokenId: BigInt,
  ownerId: string,
  fallbackWeaponDefinitionId: string,
  txHash: Bytes,
  blockNumber: BigInt
): void {
  let call = contract.try_weaponInstanceOf(tokenId);
  if (call.reverted) return;

  let inst = call.value;
  let instance = getOrCreateWeaponInstance(tokenId.toString(), ownerId, fallbackWeaponDefinitionId);

  instance.tokenId = inst.value0;
  instance.weaponDefinition = inst.value1.toString();
  instance.rarityTier = inst.value2;
  instance.frameTier = inst.value3;
  instance.durability = inst.value4;
  instance.upgradeLevel = inst.value5;
  instance.metadataRevision = inst.value6;
  instance.originPlotId = inst.value7;
  instance.originFaction = inst.value8;
  instance.originDistrictKind = inst.value9;
  instance.craftedAt = inst.value10;
  instance.visualVariant = inst.value11;
  instance.resonanceType = inst.value12;
  instance.craftSeed = inst.value13;
  instance.provenanceHash = inst.value14;
  instance.genesisEra = inst.value15;
  instance.usedAether = inst.value16;

  instance.owner = ownerId;
  instance.txHash = txHash;
  instance.blockNumber = blockNumber;
  instance.save();

  // Zusätzlich die zugehörige WeaponDefinition synchronisieren
  syncWeaponDefinition(contract, inst.value1, blockNumber, BigInt.zero());
}

// ----------------------------------------------------------------------
// Event-Handler
// ----------------------------------------------------------------------

export function handleWeaponDefinitionSet(event: WeaponDefinitionSet): void {
  let contract = CityWeaponsContract.bind(event.address);
  syncWeaponDefinition(
    contract,
    event.params.weaponDefinitionId,
    event.block.number,
    event.block.timestamp
  );
}

export function handleWeaponMinted(event: WeaponMinted): void {
  let contract = CityWeaponsContract.bind(event.address);
  let ownerId = event.params.to.toHexString();

  getOrCreatePlayer(ownerId);

  syncWeaponDefinition(
    contract,
    event.params.weaponDefinitionId,
    event.block.number,
    event.block.timestamp
  );

  syncWeaponInstance(
    contract,
    event.params.tokenId,
    ownerId,
    event.params.weaponDefinitionId.toString(),
    event.transaction.hash,
    event.block.number
  );
}

// Diese drei Handler rufen jetzt syncWeaponInstance auf (vollständige Resynchronisation)
export function handleWeaponMetadataRevisionSet(event: WeaponMetadataRevisionSet): void {
  let instance = WeaponInstance.load(event.params.tokenId.toString());
  if (instance == null) return;

  let contract = CityWeaponsContract.bind(event.address);
  syncWeaponInstance(
    contract,
    event.params.tokenId,
    instance.owner,
    instance.weaponDefinition,
    event.transaction.hash,
    event.block.number
  );
}

export function handleWeaponUpgradeLevelSet(event: WeaponUpgradeLevelSet): void {
  let instance = WeaponInstance.load(event.params.tokenId.toString());
  if (instance == null) return;

  let contract = CityWeaponsContract.bind(event.address);
  syncWeaponInstance(
    contract,
    event.params.tokenId,
    instance.owner,
    instance.weaponDefinition,
    event.transaction.hash,
    event.block.number
  );
}

export function handleWeaponDurabilitySet(event: WeaponDurabilitySet): void {
  let instance = WeaponInstance.load(event.params.tokenId.toString());
  if (instance == null) return;

  let contract = CityWeaponsContract.bind(event.address);
  syncWeaponInstance(
    contract,
    event.params.tokenId,
    instance.owner,
    instance.weaponDefinition,
    event.transaction.hash,
    event.block.number
  );
}

export function handleWeaponBonusesSet(event: WeaponBonusesSet): void {
  let tokenId = event.params.tokenId;
  let contract = CityWeaponsContract.bind(event.address);
  let call = contract.try_weaponBonusesOf(tokenId);
  if (call.reverted) return;

  let bonuses = call.value;
  let id = tokenId.toString();
  let bonusEntity = new WeaponBonuses(id);
  bonusEntity.weapon = id; // Referenz zur WeaponInstance (ID = tokenId)

  bonusEntity.minDamageBonus = bonuses.value0;
  bonusEntity.maxDamageBonus = bonuses.value1;
  bonusEntity.attackSpeedBonus = bonuses.value2;
  bonusEntity.critChanceBpsBonus = bonuses.value3;
  bonusEntity.critMultiplierBpsBonus = bonuses.value4;
  bonusEntity.accuracyBpsBonus = bonuses.value5;
  bonusEntity.rangeBonus = bonuses.value6;
  bonusEntity.maxDurabilityBonus = bonuses.value7;
  bonusEntity.armorPenBpsBonus = bonuses.value8;
  bonusEntity.blockChanceBpsBonus = bonuses.value9;
  bonusEntity.lifeStealBpsBonus = bonuses.value10;
  bonusEntity.energyCostBonus = bonuses.value11;
  bonusEntity.heatGenerationBonus = bonuses.value12;
  bonusEntity.stabilityBonus = bonuses.value13;
  bonusEntity.cooldownMsBonus = bonuses.value14;
  bonusEntity.projectileSpeedBonus = bonuses.value15;
  bonusEntity.aoeRadiusBonus = bonuses.value16;
  bonusEntity.enchantmentSlotsBonus = bonuses.value17;
  bonusEntity.materiaSlotsBonus = bonuses.value18;

  bonusEntity.updatedAtBlock = event.block.number;
  bonusEntity.updatedAtTimestamp = event.block.timestamp;

  bonusEntity.save();
}

export function handleAuthorizedMinterSet(event: AuthorizedMinterSet): void {
  let minterId = event.params.minter.toHexString();
  let entity = AuthorizedMinter.load(minterId);
  if (entity == null) {
    entity = new AuthorizedMinter(minterId);
  }
  entity.allowed = event.params.allowed;
  entity.updatedAtBlock = event.block.number;
  entity.updatedAtTimestamp = event.block.timestamp;
  entity.save();
}

export function handleBaseURISet(event: BaseURISet): void {
  let entity = BaseURI.load("current");
  if (entity == null) {
    entity = new BaseURI("current");
  }
  entity.uri = event.params.newBaseURI;
  entity.updatedAtBlock = event.block.number;
  entity.updatedAtTimestamp = event.block.timestamp;
  entity.save();
}

export function handleWeaponSocketsSet(event: WeaponSocketsSet): void {
  let entity = WeaponSockets.load("current");
  if (entity == null) {
    entity = new WeaponSockets("current");
  }
  // Feld umbenannt zu socketsAddress
  entity.socketsAddress = event.params.weaponSockets;
  entity.updatedAtBlock = event.block.number;
  entity.updatedAtTimestamp = event.block.timestamp;
  entity.save();
}

export function handleWeaponsPausedSet(event: WeaponsPausedSet): void {
  let entity = WeaponsPaused.load("current");
  if (entity == null) {
    entity = new WeaponsPaused("current");
  }
  entity.paused = event.params.paused;
  entity.updatedAtBlock = event.block.number;
  entity.updatedAtTimestamp = event.block.timestamp;
  entity.save();
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

export function handleTransfer(event: Transfer): void {
  // Ereignis speichern
  let id = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
  let entity = new TransferEvent(id);
  entity.from = event.params.from;
  entity.to = event.params.to;
  entity.tokenId = event.params.tokenId;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();

  // Besitzer der WeaponInstance aktualisieren und ggf. Player anlegen
  let instance = WeaponInstance.load(event.params.tokenId.toString());
  if (instance != null) {
    let toId = event.params.to.toHexString();
    getOrCreatePlayer(toId);          // sicherstellen, dass der Empfänger existiert
    instance.owner = toId;
    instance.txHash = event.transaction.hash;
    instance.blockNumber = event.block.number;
    instance.save();
  }
}

export function handleApproval(event: Approval): void {
  let id = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
  let entity = new ApprovalEvent(id);
  entity.owner = event.params.owner;
  entity.approved = event.params.approved;
  entity.tokenId = event.params.tokenId;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}

export function handleApprovalForAll(event: ApprovalForAll): void {
  let id = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
  let entity = new ApprovalForAllEvent(id);
  entity.owner = event.params.owner;
  entity.operator = event.params.operator;
  entity.approved = event.params.approved;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}