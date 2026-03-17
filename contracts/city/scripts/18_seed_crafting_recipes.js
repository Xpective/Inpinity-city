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
  console.log("18_seed_crafting_recipes.js");
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

  // RecipeOutputKind aus CityCrafting:
  // 0 None
  // 1 Resource
  // 2 Component
  // 3 Blueprint
  // 4 WeaponPrototype
  // 5 Enchantment

  const recipes = [
    // --------------------------------------------------
    // COMPONENT RECIPES
    // recipeId 1..9
    // outputKind = 2 (Component)
    // outputId entspricht componentId
    // Kosten bereits x5
    // --------------------------------------------------
    {
      recipeId: 1,
      label: "Iron Blade Recipe",
      outputKind: 2,
      outputId: 1,
      outputAmount: 1,
      resourceCosts: costs({ oil: 50, iron: 40 }),
      requiredFaction: 0,
      requiredDistrictKind: 0,
      requiredBuildingId: 0,
      requiredTechTier: 1,
      rarityTier: 0,
      frameTier: 0,
      requiresDiscovery: false,
      enabled: true
    },
    {
      recipeId: 2,
      label: "Reinforced Hilt Recipe",
      outputKind: 2,
      outputId: 2,
      outputAmount: 1,
      resourceCosts: costs({ oil: 30, iron: 25 }),
      requiredFaction: 0,
      requiredDistrictKind: 0,
      requiredBuildingId: 0,
      requiredTechTier: 1,
      rarityTier: 0,
      frameTier: 0,
      requiresDiscovery: false,
      enabled: true
    },
    {
      recipeId: 3,
      label: "Crystal Core Recipe",
      outputKind: 2,
      outputId: 3,
      outputAmount: 1,
      resourceCosts: costs({ oil: 40, crystal: 20 }),
      requiredFaction: 0,
      requiredDistrictKind: 0,
      requiredBuildingId: 0,
      requiredTechTier: 2,
      rarityTier: 0,
      frameTier: 0,
      requiresDiscovery: false,
      enabled: true
    },
    {
      recipeId: 4,
      label: "Bow Limb Recipe",
      outputKind: 2,
      outputId: 4,
      outputAmount: 1,
      resourceCosts: costs({ oil: 35, iron: 20 }),
      requiredFaction: 0,
      requiredDistrictKind: 0,
      requiredBuildingId: 0,
      requiredTechTier: 1,
      rarityTier: 0,
      frameTier: 0,
      requiresDiscovery: false,
      enabled: true
    },
    {
      recipeId: 5,
      label: "Bow String Recipe",
      outputKind: 2,
      outputId: 5,
      outputAmount: 1,
      resourceCosts: costs({ lemons: 20, iron: 5 }),
      requiredFaction: 0,
      requiredDistrictKind: 0,
      requiredBuildingId: 0,
      requiredTechTier: 1,
      rarityTier: 0,
      frameTier: 0,
      requiresDiscovery: false,
      enabled: true
    },
    {
      recipeId: 6,
      label: "Plasma Chamber Recipe",
      outputKind: 2,
      outputId: 6,
      outputAmount: 1,
      resourceCosts: costs({ oil: 60, iron: 50, crystal: 15 }),
      requiredFaction: 0,
      requiredDistrictKind: 0,
      requiredBuildingId: 0,
      requiredTechTier: 4,
      rarityTier: 0,
      frameTier: 0,
      requiresDiscovery: false,
      enabled: true
    },
    {
      recipeId: 7,
      label: "Energy Coil Recipe",
      outputKind: 2,
      outputId: 7,
      outputAmount: 1,
      resourceCosts: costs({ oil: 50, copper: 30, crystal: 10 }),
      requiredFaction: 0,
      requiredDistrictKind: 0,
      requiredBuildingId: 0,
      requiredTechTier: 4,
      rarityTier: 0,
      frameTier: 0,
      requiresDiscovery: false,
      enabled: true
    },
    {
      recipeId: 8,
      label: "Stabilizer Recipe",
      outputKind: 2,
      outputId: 8,
      outputAmount: 1,
      resourceCosts: costs({ oil: 40, iron: 30, gold: 5 }),
      requiredFaction: 0,
      requiredDistrictKind: 0,
      requiredBuildingId: 0,
      requiredTechTier: 3,
      rarityTier: 0,
      frameTier: 0,
      requiresDiscovery: false,
      enabled: true
    },
    {
      recipeId: 9,
      label: "Resonance Grip Recipe",
      outputKind: 2,
      outputId: 9,
      outputAmount: 1,
      resourceCosts: costs({ oil: 35, crystal: 10, mysterium: 5 }),
      requiredFaction: 0,
      requiredDistrictKind: 0,
      requiredBuildingId: 0,
      requiredTechTier: 3,
      rarityTier: 0,
      frameTier: 0,
      requiresDiscovery: false,
      enabled: true
    },

    // --------------------------------------------------
    // WEAPON PROTOTYPE RECIPES
    // recipeId 101..103
    // outputKind = 4 (WeaponPrototype)
    // outputId entspricht weaponDefinitionId
    // rarityTier + frameTier relevant
    // Kosten bereits x5
    // --------------------------------------------------
    {
      recipeId: 101,
      label: "Iron Sword Weapon Recipe",
      outputKind: 4,
      outputId: 1, // Iron Sword weaponDefinitionId
      outputAmount: 1,
      resourceCosts: costs({ oil: 100, iron: 75, gold: 10 }),
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
      recipeId: 102,
      label: "Crystal Bow Weapon Recipe",
      outputKind: 4,
      outputId: 2, // Crystal Bow weaponDefinitionId
      outputAmount: 1,
      resourceCosts: costs({ oil: 125, iron: 40, crystal: 35, gold: 15 }),
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
      recipeId: 103,
      label: "Plasma Rifle Weapon Recipe",
      outputKind: 4,
      outputId: 3, // Plasma Rifle weaponDefinitionId
      outputAmount: 1,
      resourceCosts: costs({ oil: 200, iron: 100, copper: 50, crystal: 25, aether: 5 }),
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
  console.log("Crafting recipes gesetzt.");
  console.log("Component recipes: 1-9");
  console.log("Weapon recipes: 101-103");
  console.log("========================================");
}

main().catch((error) => {
  console.error("Fehler in 18_seed_crafting_recipes.js");
  console.error(error);
  process.exitCode = 1;
});
