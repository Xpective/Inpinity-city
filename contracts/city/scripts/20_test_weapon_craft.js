import { network } from "hardhat";
import fs from "fs";
import path from "path";

function loadJson(filePath) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`Datei nicht gefunden: ${filePath}`);
  }
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

const ERC1155_ABI = [
  "function balanceOf(address account, uint256 id) external view returns (uint256)",
  "function isApprovedForAll(address account, address operator) external view returns (bool)",
  "function setApprovalForAll(address operator, bool approved) external"
];

const CITY_CRAFTING_ABI = [
  "function craftWeapon(uint256 recipeId,uint256 originPlotId,uint256 originFaction,uint256 originDistrictKind,uint8 resonanceType,uint256 visualVariant,bool genesisEra,bool usedAether) external returns (uint256)",
  "function getRecipeCosts(uint256 recipeId) external view returns (uint256[10] memory)"
];

const CITY_WEAPONS_ABI = [
  "function nextTokenId() external view returns (uint256)",
  "function ownerOf(uint256 tokenId) external view returns (address)",
  "function getWeaponStats(uint256 tokenId) external view returns ((uint256 id,string name,uint8 class,uint8 damageType,uint256 techTier,uint256 requiredLevel,uint256 requiredTechTier,uint256 minDamage,uint256 maxDamage,uint256 attackSpeed,uint256 critChanceBps,uint256 critMultiplierBps,uint256 accuracyBps,uint256 range,uint256 maxDurability,uint256 armorPenBps,uint256 blockChanceBps,uint256 lifeStealBps,uint256 energyCost,uint256 heatGeneration,uint256 stability,uint256 cooldownMs,uint256 projectileSpeed,uint256 aoeRadius,uint256 enchantmentSlots,uint256 materiaSlots,uint256 visualVariant,uint256 maxUpgradeLevel,uint256 familySetId,bool enabled),(uint256 tokenId,uint256 weaponDefinitionId,uint256 rarityTier,uint256 frameTier,uint256 durability,uint256 upgradeLevel,uint256 metadataRevision,uint256 originPlotId,uint256 originFaction,uint256 originDistrictKind,uint256 craftedAt,uint256 visualVariant,uint8 resonanceType,bytes32 craftSeed,bytes32 provenanceHash,bool genesisEra,bool usedAether),(int256 minDamageBonus,int256 maxDamageBonus,int256 attackSpeedBonus,int256 critChanceBpsBonus,int256 critMultiplierBpsBonus,int256 accuracyBpsBonus,int256 rangeBonus,int256 maxDurabilityBonus,int256 armorPenBpsBonus,int256 blockChanceBpsBonus,int256 lifeStealBpsBonus,int256 energyCostBonus,int256 heatGenerationBonus,int256 stabilityBonus,int256 cooldownMsBonus,int256 projectileSpeedBonus,int256 aoeRadiusBonus,int256 enchantmentSlotsBonus,int256 materiaSlotsBonus))"
];

async function main() {
  const { ethers } = await network.connect();
  const [deployer] = await ethers.getSigners();
  const net = await ethers.provider.getNetwork();

  console.log("========================================");
  console.log("20_test_weapon_craft.js");
  console.log("Deployer:", deployer.address);
  console.log("Chain ID:", Number(net.chainId));
  console.log("========================================");

  const coreFile = path.resolve("deployments", "city-core.json");
  const d = loadJson(coreFile);

  const cityCraftingAddress = d.cityCrafting || process.env.CITY_CRAFTING_ADDRESS;
  const cityWeaponsAddress = d.cityWeapons || process.env.CITY_WEAPONS_ADDRESS;
  const resourceTokenAddress =
    (d.addresses && d.addresses.resourceToken) || process.env.RESOURCE_TOKEN_ADDRESS;
  const treasuryAddress =
    (d.addresses && d.addresses.treasury) || process.env.TREASURY_ADDRESS;

  if (!cityCraftingAddress) throw new Error("cityCrafting Adresse fehlt");
  if (!cityWeaponsAddress) throw new Error("cityWeapons Adresse fehlt");
  if (!resourceTokenAddress) throw new Error("RESOURCE_TOKEN_ADDRESS fehlt");
  if (!treasuryAddress) throw new Error("TREASURY_ADDRESS fehlt");

  const recipeId = 101;

  const originPlotId = 1;
  const originFaction = 1;
  const originDistrictKind = 1;
  const resonanceType = 1;
  const visualVariant = 0;
  const genesisEra = true;
  const usedAether = false;

  const resourceToken = new ethers.Contract(resourceTokenAddress, ERC1155_ABI, deployer);
  const cityCrafting = new ethers.Contract(cityCraftingAddress, CITY_CRAFTING_ABI, deployer);
  const cityWeapons = new ethers.Contract(cityWeaponsAddress, CITY_WEAPONS_ABI, deployer);

  console.log("CityCrafting:", cityCraftingAddress);
  console.log("CityWeapons:", cityWeaponsAddress);
  console.log("ResourceToken:", resourceTokenAddress);
  console.log("Treasury:", treasuryAddress);
  console.log("Recipe ID:", recipeId);

  const recipeCosts = await cityCrafting.getRecipeCosts(recipeId);
  console.log("Recipe Costs [OIL, LEMONS, IRON, GOLD, PLATINUM, COPPER, CRYSTAL, OBSIDIAN, MYSTERIUM, AETHER]:");
  console.log(recipeCosts.map((x) => x.toString()));

  const isApproved = await resourceToken.isApprovedForAll(deployer.address, cityCraftingAddress);
  console.log("Approval vorhanden:", isApproved);

  if (!isApproved) {
    console.log("Setze ApprovalForAll für CityCrafting...");
    const tx = await resourceToken.setApprovalForAll(cityCraftingAddress, true);
    console.log("setApprovalForAll tx:", tx.hash);
    await tx.wait();
    await sleep(1500);
  }

  const beforeUserOil = await resourceToken.balanceOf(deployer.address, 0);
  const beforeUserIron = await resourceToken.balanceOf(deployer.address, 2);
  const beforeUserGold = await resourceToken.balanceOf(deployer.address, 3);

  const beforeTreasuryOil = await resourceToken.balanceOf(treasuryAddress, 0);
  const beforeTreasuryIron = await resourceToken.balanceOf(treasuryAddress, 2);
  const beforeTreasuryGold = await resourceToken.balanceOf(treasuryAddress, 3);

  const beforeNextTokenId = await cityWeapons.nextTokenId();
  const expectedTokenId = Number(beforeNextTokenId);

  console.log("----- BEFORE -----");
  console.log("User OIL:", beforeUserOil.toString());
  console.log("User IRON:", beforeUserIron.toString());
  console.log("User GOLD:", beforeUserGold.toString());
  console.log("Treasury OIL:", beforeTreasuryOil.toString());
  console.log("Treasury IRON:", beforeTreasuryIron.toString());
  console.log("Treasury GOLD:", beforeTreasuryGold.toString());
  console.log("Next token id:", beforeNextTokenId.toString());
  console.log("Expected minted token id:", expectedTokenId);

  console.log("Starte craftWeapon(recipeId=101)...");
  const craftTx = await cityCrafting.craftWeapon(
    recipeId,
    originPlotId,
    originFaction,
    originDistrictKind,
    resonanceType,
    visualVariant,
    genesisEra,
    usedAether
  );
  console.log("craftWeapon tx:", craftTx.hash);
  const receipt = await craftTx.wait();
  await sleep(1500);

  console.log("Craft bestätigt in Block:", receipt.blockNumber);

  const afterUserOil = await resourceToken.balanceOf(deployer.address, 0);
  const afterUserIron = await resourceToken.balanceOf(deployer.address, 2);
  const afterUserGold = await resourceToken.balanceOf(deployer.address, 3);

  const afterTreasuryOil = await resourceToken.balanceOf(treasuryAddress, 0);
  const afterTreasuryIron = await resourceToken.balanceOf(treasuryAddress, 2);
  const afterTreasuryGold = await resourceToken.balanceOf(treasuryAddress, 3);

  const afterNextTokenId = await cityWeapons.nextTokenId();
  const owner = await cityWeapons.ownerOf(expectedTokenId);
  const [def, inst, bonuses] = await cityWeapons.getWeaponStats(expectedTokenId);

  console.log("----- AFTER -----");
  console.log("User OIL:", afterUserOil.toString());
  console.log("User IRON:", afterUserIron.toString());
  console.log("User GOLD:", afterUserGold.toString());
  console.log("Treasury OIL:", afterTreasuryOil.toString());
  console.log("Treasury IRON:", afterTreasuryIron.toString());
  console.log("Treasury GOLD:", afterTreasuryGold.toString());
  console.log("Next token id:", afterNextTokenId.toString());

  console.log("----- DELTA -----");
  console.log("User OIL delta:", (afterUserOil - beforeUserOil).toString());
  console.log("User IRON delta:", (afterUserIron - beforeUserIron).toString());
  console.log("User GOLD delta:", (afterUserGold - beforeUserGold).toString());
  console.log("Treasury OIL delta:", (afterTreasuryOil - beforeTreasuryOil).toString());
  console.log("Treasury IRON delta:", (afterTreasuryIron - beforeTreasuryIron).toString());
  console.log("Treasury GOLD delta:", (afterTreasuryGold - beforeTreasuryGold).toString());

  console.log("----- MINT RESULT -----");
  console.log("Minted token id:", expectedTokenId);
  console.log("Owner:", owner);

  console.log("----- WEAPON DEF -----");
  console.log("Definition ID:", def.id.toString());
  console.log("Name:", def.name);
  console.log("Class:", def.class.toString());
  console.log("DamageType:", def.damageType.toString());
  console.log("MinDamage:", def.minDamage.toString());
  console.log("MaxDamage:", def.maxDamage.toString());
  console.log("Enabled:", def.enabled);

  console.log("----- WEAPON INSTANCE -----");
  console.log("Token ID:", inst.tokenId.toString());
  console.log("WeaponDefinitionId:", inst.weaponDefinitionId.toString());
  console.log("RarityTier:", inst.rarityTier.toString());
  console.log("FrameTier:", inst.frameTier.toString());
  console.log("Durability:", inst.durability.toString());
  console.log("OriginPlotId:", inst.originPlotId.toString());
  console.log("OriginFaction:", inst.originFaction.toString());
  console.log("OriginDistrictKind:", inst.originDistrictKind.toString());
  console.log("CraftedAt:", inst.craftedAt.toString());
  console.log("VisualVariant:", inst.visualVariant.toString());
  console.log("ResonanceType:", inst.resonanceType.toString());
  console.log("CraftSeed:", inst.craftSeed);
  console.log("ProvenanceHash:", inst.provenanceHash);
  console.log("GenesisEra:", inst.genesisEra);
  console.log("UsedAether:", inst.usedAether);

  console.log("----- LOCAL BONUSES -----");
  console.log("MinDamageBonus:", bonuses.minDamageBonus.toString());
  console.log("MaxDamageBonus:", bonuses.maxDamageBonus.toString());

  console.log("========================================");
  console.log("Weapon-Craft-Test abgeschlossen.");
  console.log("========================================");
}

main().catch((error) => {
  console.error("Fehler in 20_test_weapon_craft.js");
  console.error(error);
  process.exitCode = 1;
});