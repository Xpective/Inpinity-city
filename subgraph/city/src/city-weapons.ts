import { BigInt } from "@graphprotocol/graph-ts";
import {
  WeaponDefinitionSet,
  WeaponMinted,
  WeaponMetadataRevisionSet,
  WeaponUpgradeLevelSet,
  WeaponDurabilitySet
} from "../generated/CityWeapons/CityWeapons";
import { Player, WeaponDefinition, WeaponInstance } from "../generated/schema";

function getOrCreatePlayer(id: string): Player {
  let player = Player.load(id);
  if (player == null) {
    player = new Player(id);
    player.personalPlotCount = 0;
    player.save();
  }
  return player as Player;
}

export function handleWeaponDefinitionSet(event: WeaponDefinitionSet): void {
  let entity = new WeaponDefinition(event.params.weaponDefinitionId.toString());
  entity.weaponDefinitionId = event.params.weaponDefinitionId;
  entity.name = event.params.name;
  entity.classId = event.params.classId;
  entity.damageTypeId = event.params.damageType;
  entity.techTier = event.params.techTier;
  entity.enabled = event.params.enabled;
  entity.createdAtBlock = event.block.number;
  entity.createdAtTimestamp = event.block.timestamp;
  entity.save();
}

export function handleWeaponMinted(event: WeaponMinted): void {
  let ownerId = event.params.to.toHexString();
  getOrCreatePlayer(ownerId);

  let instance = new WeaponInstance(event.params.tokenId.toString());
  instance.tokenId = event.params.tokenId;
  instance.owner = ownerId;
  instance.weaponDefinition = event.params.weaponDefinitionId.toString();
  instance.metadataRevision = BigInt.fromI32(1);
  instance.upgradeLevel = BigInt.fromI32(0);
  instance.durability = BigInt.fromI32(0);
  instance.craftSeed = event.params.craftSeed;
  instance.provenanceHash = event.params.provenanceHash;
  instance.txHash = event.transaction.hash;
  instance.blockNumber = event.block.number;
  instance.save();
}

export function handleWeaponMetadataRevisionSet(event: WeaponMetadataRevisionSet): void {
  let instance = WeaponInstance.load(event.params.tokenId.toString());
  if (instance == null) return;

  instance.metadataRevision = event.params.metadataRevision;
  instance.save();
}

export function handleWeaponUpgradeLevelSet(event: WeaponUpgradeLevelSet): void {
  let instance = WeaponInstance.load(event.params.tokenId.toString());
  if (instance == null) return;

  instance.upgradeLevel = event.params.upgradeLevel;
  instance.save();
}

export function handleWeaponDurabilitySet(event: WeaponDurabilitySet): void {
  let instance = WeaponInstance.load(event.params.tokenId.toString());
  if (instance == null) return;

  instance.durability = event.params.durability;
  instance.save();
}