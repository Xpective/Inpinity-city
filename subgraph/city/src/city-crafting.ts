import { BigInt } from "@graphprotocol/graph-ts";
import {
  RecipeSet,
  Crafted,
  WeaponCrafted,
  AuthorizedCallerSet,
  CityBlueprintsSet,
  CityComponentsSet,
  CityWeaponsSet,
  CraftingPausedSet,
  OwnershipTransferred,
  RecipeDiscovered
} from "../generated/CityCrafting/CityCrafting";
import {
  RecipeDefinition,
  CraftEvent,
  AuthorizedCaller,
  CityBlueprints,
  CityComponents,
  CityWeaponsAddress,
  CraftingPaused,
  CraftingOwnershipTransferredEvent,
  RecipeDiscoveredEvent
} from "../generated/schema";

// ----------------------------------------------------------------------
// Bestehende Handler (unverändert)
// ----------------------------------------------------------------------

export function handleRecipeSet(event: RecipeSet): void {
  let recipe = new RecipeDefinition(event.params.recipeId.toString());
  recipe.recipeId = event.params.recipeId;
  recipe.outputKind = event.params.outputKind;
  recipe.outputId = event.params.outputId;
  recipe.outputAmount = event.params.outputAmount;
  recipe.enabled = event.params.enabled;
  recipe.updatedAtBlock = event.block.number;
  recipe.updatedAtTimestamp = event.block.timestamp;
  recipe.save();
}

export function handleCrafted(event: Crafted): void {
  let id = event.transaction.hash.toHexString() + "-" + event.logIndex.toString();
  let craft = new CraftEvent(id);
  craft.user = event.params.user;
  craft.recipeId = event.params.recipeId;
  craft.outputKind = event.params.outputKind;
  craft.outputId = event.params.outputId;
  craft.outputAmount = event.params.outputAmount;
  craft.txHash = event.transaction.hash;
  craft.blockNumber = event.block.number;
  craft.timestamp = event.block.timestamp;
  craft.save();
}

export function handleWeaponCrafted(event: WeaponCrafted): void {
  let id = event.transaction.hash.toHexString() + "-" + event.logIndex.toString();
  let craft = new CraftEvent(id);
  craft.user = event.params.user;
  craft.recipeId = event.params.recipeId;
  craft.outputKind = 4; // Annahme: 4 = Weapon (laut ABI ist RecipeOutputKind ein enum, Wert muss ggf. angepasst werden)
  craft.outputId = event.params.weaponDefinitionId;
  craft.outputAmount = BigInt.fromI32(1);
  craft.tokenId = event.params.tokenId;
  craft.weaponDefinitionId = event.params.weaponDefinitionId;
  craft.craftNonce = event.params.craftNonce;
  craft.txHash = event.transaction.hash;
  craft.blockNumber = event.block.number;
  craft.timestamp = event.block.timestamp;
  craft.save();
}

// ----------------------------------------------------------------------
// Neue Handler für die bisher fehlenden Events
// ----------------------------------------------------------------------

export function handleAuthorizedCallerSet(event: AuthorizedCallerSet): void {
  let callerId = event.params.caller.toHexString();
  let entity = AuthorizedCaller.load(callerId);
  if (entity == null) {
    entity = new AuthorizedCaller(callerId);
  }
  entity.allowed = event.params.allowed;
  entity.updatedAtBlock = event.block.number;
  entity.updatedAtTimestamp = event.block.timestamp;
  entity.save();
}

export function handleCityBlueprintsSet(event: CityBlueprintsSet): void {
  let entity = CityBlueprints.load("current");
  if (entity == null) {
    entity = new CityBlueprints("current");
  }
  entity.address = event.params.blueprints;
  entity.updatedAtBlock = event.block.number;
  entity.updatedAtTimestamp = event.block.timestamp;
  entity.save();
}

export function handleCityComponentsSet(event: CityComponentsSet): void {
  let entity = CityComponents.load("current");
  if (entity == null) {
    entity = new CityComponents("current");
  }
  entity.address = event.params.components;
  entity.updatedAtBlock = event.block.number;
  entity.updatedAtTimestamp = event.block.timestamp;
  entity.save();
}

export function handleCityWeaponsSet(event: CityWeaponsSet): void {
  let entity = CityWeaponsAddress.load("current");
  if (entity == null) {
    entity = new CityWeaponsAddress("current");
  }
  entity.address = event.params.weapons;
  entity.updatedAtBlock = event.block.number;
  entity.updatedAtTimestamp = event.block.timestamp;
  entity.save();
}

export function handleCraftingPausedSet(event: CraftingPausedSet): void {
  let entity = CraftingPaused.load("current");
  if (entity == null) {
    entity = new CraftingPaused("current");
  }
  entity.paused = event.params.paused;
  entity.updatedAtBlock = event.block.number;
  entity.updatedAtTimestamp = event.block.timestamp;
  entity.save();
}

export function handleOwnershipTransferred(event: OwnershipTransferred): void {
  let id = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
  let entity = new CraftingOwnershipTransferredEvent(id);
  entity.previousOwner = event.params.previousOwner;
  entity.newOwner = event.params.newOwner;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}

export function handleRecipeDiscovered(event: RecipeDiscovered): void {
  let id = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
  let entity = new RecipeDiscoveredEvent(id);
  entity.user = event.params.user;
  entity.recipeId = event.params.recipeId;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.txHash = event.transaction.hash;
  entity.save();
}