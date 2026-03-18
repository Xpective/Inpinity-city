import { BigInt } from "@graphprotocol/graph-ts";
import {
  AuthorizedCallerSet,
  EnchantmentBonusesSet,
  EnchantmentDefinitionSet,
  OwnershipTransferred
} from "../generated/CityEnchantments/CityEnchantments";
import {
  EnchantmentDefinition,
  EnchantmentAuthorizedCaller,
  EnchantmentBonusSet,
  CityEnchantmentsOwnershipTransferredEvent
} from "../generated/schema";

// --------------------------------------------------
// Helpers
// --------------------------------------------------

function getOrCreateEnchantmentDefinition(enchantmentId: BigInt): EnchantmentDefinition {
  let id = enchantmentId.toString();
  let entity = EnchantmentDefinition.load(id);

  if (entity == null) {
    entity = new EnchantmentDefinition(id);
    entity.enchantmentId = enchantmentId;
    entity.name = "";
    entity.category = BigInt.zero();
    entity.rarityTier = BigInt.zero();
    entity.maxLevel = BigInt.zero();
    entity.enabled = false;
    entity.updatedAtBlock = BigInt.zero();
    entity.updatedAtTimestamp = BigInt.zero();
  }

  return entity as EnchantmentDefinition;
}

function getOrCreateEnchantmentAuthorizedCaller(account: string): EnchantmentAuthorizedCaller {
  let entity = EnchantmentAuthorizedCaller.load(account);

  if (entity == null) {
    entity = new EnchantmentAuthorizedCaller(account);
    entity.allowed = false;
    entity.updatedAtBlock = BigInt.zero();
    entity.updatedAtTimestamp = BigInt.zero();
  }

  return entity as EnchantmentAuthorizedCaller;
}

function getBonusSetId(enchantmentId: BigInt, level: BigInt): string {
  return enchantmentId.toString() + "-" + level.toString();
}

function getOrCreateEnchantmentBonusSet(
  enchantmentId: BigInt,
  level: BigInt
): EnchantmentBonusSet {
  let id = getBonusSetId(enchantmentId, level);
  let entity = EnchantmentBonusSet.load(id);

  if (entity == null) {
    entity = new EnchantmentBonusSet(id);
    entity.enchantment = enchantmentId.toString();
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

  return entity as EnchantmentBonusSet;
}

// --------------------------------------------------
// Event handlers
// --------------------------------------------------

export function handleAuthorizedCallerSet(event: AuthorizedCallerSet): void {
  let id = event.params.caller.toHexString();
  let entity = getOrCreateEnchantmentAuthorizedCaller(id);

  entity.allowed = event.params.allowed;
  entity.updatedAtBlock = event.block.number;
  entity.updatedAtTimestamp = event.block.timestamp;
  entity.save();
}

export function handleEnchantmentDefinitionSet(event: EnchantmentDefinitionSet): void {
  let entity = getOrCreateEnchantmentDefinition(event.params.enchantmentId);

  entity.enchantmentId = event.params.enchantmentId;
  entity.name = event.params.name;
  entity.category = BigInt.fromI32(event.params.category);
  entity.rarityTier = event.params.rarityTier;
  entity.maxLevel = event.params.maxLevel;
  entity.enabled = event.params.enabled;
  entity.updatedAtBlock = event.block.number;
  entity.updatedAtTimestamp = event.block.timestamp;
  entity.save();
}

export function handleEnchantmentBonusesSet(event: EnchantmentBonusesSet): void {
  let entity = getOrCreateEnchantmentBonusSet(
    event.params.enchantmentId,
    event.params.level
  );

  // Event liefert nur enchantmentId + level.
  // Die echten Bonuswerte werden onchain gesetzt, aber nicht im Event emitted.
  // Deshalb legen wir hier den Datensatz sicher an und markieren ihn als aktualisiert.
  entity.updatedAtBlock = event.block.number;
  entity.updatedAtTimestamp = event.block.timestamp;
  entity.save();
}

export function handleOwnershipTransferred(event: OwnershipTransferred): void {
  let entity = new CityEnchantmentsOwnershipTransferredEvent(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );

  entity.previousOwner = event.params.previousOwner;
  entity.newOwner = event.params.newOwner;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}