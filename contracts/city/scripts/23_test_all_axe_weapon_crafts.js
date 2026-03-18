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

async function ensureApproval(resourceToken, owner, operator) {
  const approved = await resourceToken.isApprovedForAll(owner, operator);
  console.log("Approval vorhanden:", approved);
  if (!approved) {
    const tx = await resourceToken.setApprovalForAll(operator, true);
    console.log("setApprovalForAll tx:", tx.hash);
    await tx.wait();
    await sleep(1500);
  }
}

async function readResourceBalances(resourceToken, user, treasury) {
  const ids = [0, 2, 3, 5, 6, 9]; // OIL, IRON, GOLD, COPPER, CRYSTAL, AETHER
  const names = ["OIL", "IRON", "GOLD", "COPPER", "CRYSTAL", "AETHER"];

  const userBalances = {};
  const treasuryBalances = {};

  for (let i = 0; i < ids.length; i++) {
    userBalances[names[i]] = await resourceToken.balanceOf(user, ids[i]);
    treasuryBalances[names[i]] = await resourceToken.balanceOf(treasury, ids[i]);
  }

  return { userBalances, treasuryBalances };
}

function printBalances(title, balances) {
  console.log(title);
  for (const [k, v] of Object.entries(balances)) {
    console.log(`${k}: ${v.toString()}`);
  }
}

function printDeltas(title, before, after) {
  console.log(title);
  for (const key of Object.keys(before)) {
    console.log(`${key} delta: ${(after[key] - before[key]).toString()}`);
  }
}

async function craftOne({
  cityCrafting,
  cityWeapons,
  resourceToken,
  deployer,
  treasuryAddress,
  recipeId,
  label,
  originPlotId,
  originFaction,
  originDistrictKind,
  resonanceType,
  visualVariant,
  genesisEra,
  usedAether
}) {
  console.log("========================================");
  console.log(`Teste ${label}`);
  console.log(`Recipe ID: ${recipeId}`);
  console.log("========================================");

  const costs = await cityCrafting.getRecipeCosts(recipeId);
  console.log("Recipe Costs [OIL, LEMONS, IRON, GOLD, PLATINUM, COPPER, CRYSTAL, OBSIDIAN, MYSTERIUM, AETHER]:");
  console.log(costs.map((x) => x.toString()));

  const before = await readResourceBalances(resourceToken, deployer.address, treasuryAddress);
  const beforeNextTokenId = await cityWeapons.nextTokenId();
  const expectedTokenId = Number(beforeNextTokenId);

  printBalances("----- BEFORE USER -----", before.userBalances);
  printBalances("----- BEFORE TREASURY -----", before.treasuryBalances);
  console.log("Next token id:", beforeNextTokenId.toString());
  console.log("Expected minted token id:", expectedTokenId);

  const tx = await cityCrafting.craftWeapon(
    recipeId,
    originPlotId,
    originFaction,
    originDistrictKind,
    resonanceType,
    visualVariant,
    genesisEra,
    usedAether
  );
  console.log("craftWeapon tx:", tx.hash);
  const receipt = await tx.wait();
  await sleep(1500);

  console.log("Craft bestätigt in Block:", receipt.blockNumber);

  const after = await readResourceBalances(resourceToken, deployer.address, treasuryAddress);
  const afterNextTokenId = await cityWeapons.nextTokenId();
  const owner = await cityWeapons.ownerOf(expectedTokenId);
  const [def, inst, bonuses] = await cityWeapons.getWeaponStats(expectedTokenId);

  printBalances("----- AFTER USER -----", after.userBalances);
  printBalances("----- AFTER TREASURY -----", after.treasuryBalances);
  console.log("Next token id:", afterNextTokenId.toString());

  printDeltas("----- USER DELTAS -----", before.userBalances, after.userBalances);
  printDeltas("----- TREASURY DELTAS -----", before.treasuryBalances, after.treasuryBalances);

  console.log("----- MINT RESULT -----");
  console.log("Minted token id:", expectedTokenId);
  console.log("Owner:", owner);

  console.log("----- WEAPON DEF -----");
  console.log("Definition ID:", def.id.toString());
  console.log("Name:", def.name);
  console.log("Class:", def.class.toString());
  console.log("DamageType:", def.damageType.toString());
  console.log("TechTier:", def.techTier.toString());
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
}

async function main() {
  const { ethers } = await network.connect();
  const [deployer] = await ethers.getSigners();
  const net = await ethers.provider.getNetwork();

  console.log("========================================");
  console.log("23_test_all_axes_craft.js");
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

  const resourceToken = new ethers.Contract(resourceTokenAddress, ERC1155_ABI, deployer);
  const cityCrafting = new ethers.Contract(cityCraftingAddress, CITY_CRAFTING_ABI, deployer);
  const cityWeapons = new ethers.Contract(cityWeaponsAddress, CITY_WEAPONS_ABI, deployer);

  console.log("CityCrafting:", cityCraftingAddress);
  console.log("CityWeapons:", cityWeaponsAddress);
  console.log("ResourceToken:", resourceTokenAddress);
  console.log("Treasury:", treasuryAddress);

  await ensureApproval(resourceToken, deployer.address, cityCraftingAddress);

  const tests = [
    {
      recipeId: 104,
      label: "Iron Axe",
      originPlotId: 2,
      originFaction: 1,
      originDistrictKind: 1,
      resonanceType: 1,
      visualVariant: 0,
      genesisEra: true,
      usedAether: false
    },
    {
      recipeId: 105,
      label: "Crystal Axe",
      originPlotId: 3,
      originFaction: 2,
      originDistrictKind: 2,
      resonanceType: 2,
      visualVariant: 0,
      genesisEra: true,
      usedAether: false
    },
    {
      recipeId: 106,
      label: "Plasma Cleaver",
      originPlotId: 4,
      originFaction: 3,
      originDistrictKind: 3,
      resonanceType: 3,
      visualVariant: 0,
      genesisEra: false,
      usedAether: true
    }
  ];

  for (const t of tests) {
    await craftOne({
      cityCrafting,
      cityWeapons,
      resourceToken,
      deployer,
      treasuryAddress,
      ...t
    });
    await sleep(2500);
  }

  console.log("========================================");
  console.log("Alle 3 Axe-Crafts abgeschlossen.");
  console.log("========================================");
}

main().catch((error) => {
  console.error("Fehler in 23_test_all_axes_craft.js");
  console.error(error);
  process.exitCode = 1;
});