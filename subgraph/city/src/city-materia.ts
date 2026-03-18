import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import {
  AuthorizedCallerSet,
  MateriaBonusesSet,
  MateriaDefinitionSet,
  OwnershipTransferred,
  CityMateria as CityMateriaContract
} from "../generated/CityMateria/CityMateria";
import {
  MateriaDefinition,
  MateriaBonus,
  MateriaAuthorizedCaller,
  CityMateriaOwnershipTransferredEvent
} from "../generated/schema";

// --------------------------------------------------
// Helpers
// --------------------------------------------------

function makeEventId(hash: Bytes, logIndex: BigInt): string {
  return hash.toHexString() + "-" + logIndex.toString();
}

function makeBonusId(materiaId: BigInt, level: BigInt): string {
  return materiaId.toString() + "-" + level.toString();
}

function categoryToLabel(raw: string): string {
  if (raw == "0") return "none";
  if (raw == "1") return "offense";
  if (raw == "2") return "defense";
  if (raw == "3") return "utility";
  if (raw == "4") return "hybrid";

  return "category_" + raw;
}

function elementToLabel(raw: string): string {
  if (raw == "0") return "none";
  if (raw == "1") return "fire";
  if (raw == "2") return "water";
  if (raw == "3") return "ice";
  if (raw == "4") return "lightning";
  if (raw == "5") return "earth";
  if (raw == "6") return "crystal";
  if (raw == "7") return "shadow";
  if (raw == "8") return "light";
  if (raw == "9") return "aether";
  if (raw == "10") return "plasma";
  if (raw == "11") return "energy";

  return "element_" + raw;
}

function getOrCreateMateriaDefinition(materiaId: BigInt): MateriaDefinition {
  let id = materiaId.toString();
  let entity = MateriaDefinition.load(id);

  if (entity == null) {
    entity = new MateriaDefinition(id);
    entity.materiaId = materiaId;
    entity.name = "";
    entity.categoryRaw = "0";
    entity.categoryLabel = "none";
    entity.elementRaw = "0";
    entity.elementLabel = "none";
    entity.rarityTier = BigInt.zero();
    entity.maxLevel = BigInt.zero();
    entity.enabled = false;
    entity.updatedAtBlock = BigInt.zero();
    entity.updatedAtTimestamp = BigInt.zero();
  }

  return entity as MateriaDefinition;
}

function getOrCreateMateriaBonus(materiaId: BigInt, level: BigInt): MateriaBonus {
  let id = makeBonusId(materiaId, level);
  let entity = MateriaBonus.load(id);

  if (entity == null) {
    entity = new MateriaBonus(id);
    entity.materia = materiaId.toString();
    entity.materiaId = materiaId;
    entity.level = level;

    entity.minDamageBonus = BigInt.zero();
    entity.maxDamageBonus = BigInt.zero();
    entity.attackSpeedBonus = BigInt.zero();
    entity.critChanceBpsBonus = BigInt.zero();
    entity.critMultiplierBpsBonus = BigInt.zero();
    entity.accuracyBpsBonus = BigInt.zero();
    entity.rangeBonus = BigInt.zero();
    entity.maxDurabilityBonus = BigInt.zero();
    entity.armorPenBpsBonus = BigInt.zero();
    entity.blockChanceBpsBonus = BigInt.zero();
    entity.lifeStealBpsBonus = BigInt.zero();
    entity.energyCostBonus = BigInt.zero();
    entity.heatGenerationBonus = BigInt.zero();
    entity.stabilityBonus = BigInt.zero();
    entity.cooldownMsBonus = BigInt.zero();
    entity.projectileSpeedBonus = BigInt.zero();
    entity.aoeRadiusBonus = BigInt.zero();
    entity.enchantmentSlotsBonus = BigInt.zero();
    entity.materiaSlotsBonus = BigInt.zero();

    entity.updatedAtBlock = BigInt.zero();
    entity.updatedAtTimestamp = BigInt.zero();
  }

  return entity as MateriaBonus;
}

function getOrCreateAuthorizedCaller(account: string): MateriaAuthorizedCaller {
  let entity = MateriaAuthorizedCaller.load(account);

  if (entity == null) {
    entity = new MateriaAuthorizedCaller(account);
    entity.allowed = false;
    entity.updatedAtBlock = BigInt.zero();
    entity.updatedAtTimestamp = BigInt.zero();
  }

  return entity as MateriaAuthorizedCaller;
}

function syncMateriaDefinition(
  contract: CityMateriaContract,
  materiaId: BigInt,
  blockNumber: BigInt,
  blockTimestamp: BigInt
): void {
  let call = contract.try_getMateriaDefinition(materiaId);
  if (call.reverted) {
    return;
  }

  let value = call.value;
  let entity = getOrCreateMateriaDefinition(materiaId);

  entity.materiaId = value.id;
  entity.name = value.name;
  entity.categoryRaw = value.category.toString();
  entity.categoryLabel = categoryToLabel(value.category.toString());
  entity.elementRaw = value.element.toString();
  entity.elementLabel = elementToLabel(value.element.toString());
  entity.rarityTier = value.rarityTier;
  entity.maxLevel = value.maxLevel;
  entity.enabled = value.enabled;
  entity.updatedAtBlock = blockNumber;
  entity.updatedAtTimestamp = blockTimestamp;
  entity.save();
}

function syncMateriaBonus(
  contract: CityMateriaContract,
  materiaId: BigInt,
  level: BigInt,
  blockNumber: BigInt,
  blockTimestamp: BigInt
): void {
  let call = contract.try_getMateriaBonuses(materiaId, level);
  if (call.reverted) {
    return;
  }

  let b = call.value;
  let entity = getOrCreateMateriaBonus(materiaId, level);

  entity.materia = materiaId.toString();
  entity.materiaId = materiaId;
  entity.level = level;

  entity.minDamageBonus = b.minDamageBonus;
  entity.maxDamageBonus = b.maxDamageBonus;
  entity.attackSpeedBonus = b.attackSpeedBonus;
  entity.critChanceBpsBonus = b.critChanceBpsBonus;
  entity.critMultiplierBpsBonus = b.critMultiplierBpsBonus;
  entity.accuracyBpsBonus = b.accuracyBpsBonus;
  entity.rangeBonus = b.rangeBonus;
  entity.maxDurabilityBonus = b.maxDurabilityBonus;
  entity.armorPenBpsBonus = b.armorPenBpsBonus;
  entity.blockChanceBpsBonus = b.blockChanceBpsBonus;
  entity.lifeStealBpsBonus = b.lifeStealBpsBonus;
  entity.energyCostBonus = b.energyCostBonus;
  entity.heatGenerationBonus = b.heatGenerationBonus;
  entity.stabilityBonus = b.stabilityBonus;
  entity.cooldownMsBonus = b.cooldownMsBonus;
  entity.projectileSpeedBonus = b.projectileSpeedBonus;
  entity.aoeRadiusBonus = b.aoeRadiusBonus;
  entity.enchantmentSlotsBonus = b.enchantmentSlotsBonus;
  entity.materiaSlotsBonus = b.materiaSlotsBonus;

  entity.updatedAtBlock = blockNumber;
  entity.updatedAtTimestamp = blockTimestamp;
  entity.save();
}

// --------------------------------------------------
// Event handlers
// --------------------------------------------------

export function handleAuthorizedCallerSet(event: AuthorizedCallerSet): void {
  let entity = getOrCreateAuthorizedCaller(event.params.caller.toHexString());
  entity.allowed = event.params.allowed;
  entity.updatedAtBlock = event.block.number;
  entity.updatedAtTimestamp = event.block.timestamp;
  entity.save();
}

export function handleMateriaDefinitionSet(event: MateriaDefinitionSet): void {
  let contract = CityMateriaContract.bind(event.address);

  syncMateriaDefinition(
    contract,
    event.params.materiaId,
    event.block.number,
    event.block.timestamp
  );
}

export function handleMateriaBonusesSet(event: MateriaBonusesSet): void {
  let contract = CityMateriaContract.bind(event.address);

  syncMateriaBonus(
    contract,
    event.params.materiaId,
    event.params.level,
    event.block.number,
    event.block.timestamp
  );
}

export function handleOwnershipTransferred(event: OwnershipTransferred): void {
  let entity = new CityMateriaOwnershipTransferredEvent(
    makeEventId(event.transaction.hash, event.logIndex)
  );
  entity.previousOwner = event.params.previousOwner;
  entity.newOwner = event.params.newOwner;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}