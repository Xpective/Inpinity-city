import { network } from "hardhat";
import fs from "fs";
import path from "path";

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function loadJson(filePath) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`Datei nicht gefunden: ${filePath}`);
  }
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

async function sendAndWait(txPromise, label, delay = 1800) {
  const tx = await txPromise;
  console.log(`${label}: ${tx.hash}`);
  await tx.wait();
  await sleep(delay);
}

function costs({
  oil = 0,
  lemons = 0,
  iron = 0,
  gold = 0,
  platinum = 0,
  copper = 0,
  crystal = 0,
  obsidian = 0,
  mysterium = 0,
  aether = 0
}) {
  return [
    oil,       // 0 OIL
    lemons,    // 1 LEMONS
    iron,      // 2 IRON
    gold,      // 3 GOLD
    platinum,  // 4 PLATINUM
    copper,    // 5 COPPER
    crystal,   // 6 CRYSTAL
    obsidian,  // 7 OBSIDIAN
    mysterium, // 8 MYSTERIUM
    aether     // 9 AETHER
  ];
}

async function main() {
  const { ethers } = await network.connect();
  const [deployer] = await ethers.getSigners();
  const net = await ethers.provider.getNetwork();

  console.log("========================================");
  console.log("22_seed_axe_weapon_recipes.js");
  console.log("Deployer:", deployer.address);
  console.log("Chain ID:", Number(net.chainId));
  console.log("========================================");

  const coreFile = path.resolve("deployments", "city-core.json");
  const d = loadJson(coreFile);

  if (!d.cityCrafting) {
    throw new Error("cityCrafting fehlt in deployments/city-core.json");
  }

  const cityCrafting = await ethers.getContractAt("CityCrafting", d.cityCrafting);

  let nextNonce = await ethers.provider.getTransactionCount(deployer.address, "pending");
  console.log("Start nonce:", nextNonce);

  const recipes = [
    {
      recipeId: 104,
      label: "Iron Axe Weapon Recipe",
      outputKind: 4, // WeaponPrototype
      outputId: 4,   // Iron Axe
      outputAmount: 1,
      resourceCosts: costs({
        oil: 110,
        iron: 90,
        gold: 12
      }),
      requiredFaction: 0,
      requiredDistrictKind: 0,
      requiredBuildingId: 0,
      requiredTechTier: 1,
      rarityTier: 1,
      frameTier: 1,
      requiresDiscovery: false,
      enabled: true
    },
    {
      recipeId: 105,
      label: "Crystal Axe Weapon Recipe",
      outputKind: 4, // WeaponPrototype
      outputId: 5,   // Crystal Axe
      outputAmount: 1,
      resourceCosts: costs({
        oil: 140,
        iron: 60,
        crystal: 40,
        gold: 18
      }),
      requiredFaction: 0,
      requiredDistrictKind: 0,
      requiredBuildingId: 0,
      requiredTechTier: 2,
      rarityTier: 2,
      frameTier: 2,
      requiresDiscovery: false,
      enabled: true
    },
    {
      recipeId: 106,
      label: "Plasma Cleaver Weapon Recipe",
      outputKind: 4, // WeaponPrototype
      outputId: 6,   // Plasma Cleaver
      outputAmount: 1,
      resourceCosts: costs({
        oil: 220,
        iron: 120,
        copper: 60,
        crystal: 30,
        aether: 8
      }),
      requiredFaction: 0,
      requiredDistrictKind: 0,
      requiredBuildingId: 0,
      requiredTechTier: 4,
      rarityTier: 3,
      frameTier: 3,
      requiresDiscovery: false,
      enabled: true
    }
  ];

  for (const recipe of recipes) {
    console.log("----------------------------------------");
    console.log(`Setze Recipe ${recipe.recipeId}: ${recipe.label}`);

    await sendAndWait(
      cityCrafting.setRecipe(
        recipe.recipeId,
        recipe.outputKind,
        recipe.outputId,
        recipe.outputAmount,
        recipe.resourceCosts,
        recipe.requiredFaction,
        recipe.requiredDistrictKind,
        recipe.requiredBuildingId,
        recipe.requiredTechTier,
        recipe.rarityTier,
        recipe.frameTier,
        recipe.requiresDiscovery,
        recipe.enabled,
        { nonce: nextNonce++ }
      ),
      `CityCrafting.setRecipe(${recipe.recipeId}, ${recipe.label})`
    );
  }

  console.log("========================================");
  console.log("Axe weapon recipes gesetzt.");
  console.log("104 = Iron Axe Weapon Recipe");
  console.log("105 = Crystal Axe Weapon Recipe");
  console.log("106 = Plasma Cleaver Weapon Recipe");
  console.log("========================================");
}

main().catch((error) => {
  console.error("Fehler in 22_seed_axe_weapon_recipes.js");
  console.error(error);
  process.exitCode = 1;
});