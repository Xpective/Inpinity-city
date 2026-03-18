import { BigInt } from "@graphprotocol/graph-ts";
import { RecipeSet, Crafted, WeaponCrafted } from "../generated/CityCrafting/CityCrafting";
import { RecipeDefinition, CraftEvent } from "../generated/schema";

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
  craft.outputKind = 4;
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