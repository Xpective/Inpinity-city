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

function emptyBonus() {
  return {
    minDamageBonus: 0,
    maxDamageBonus: 0,
    attackSpeedBonus: 0,
    critChanceBpsBonus: 0,
    critMultiplierBpsBonus: 0,
    accuracyBpsBonus: 0,
    rangeBonus: 0,
    maxDurabilityBonus: 0,
    armorPenBpsBonus: 0,
    blockChanceBpsBonus: 0,
    lifeStealBpsBonus: 0,
    energyCostBonus: 0,
    heatGenerationBonus: 0,
    stabilityBonus: 0,
    cooldownMsBonus: 0,
    projectileSpeedBonus: 0,
    aoeRadiusBonus: 0,
    enchantmentSlotsBonus: 0,
    materiaSlotsBonus: 0
  };
}

async function main() {
  const { ethers } = await network.connect();
  const [deployer] = await ethers.getSigners();
  const net = await ethers.provider.getNetwork();

  console.log("========================================");
  console.log("17_seed_enchantments_and_materia.js");
  console.log("Deployer:", deployer.address);
  console.log("Chain ID:", Number(net.chainId));
  console.log("========================================");

  const coreFile = path.resolve("deployments", "city-core.json");
  const d = loadJson(coreFile);

  if (!d.cityEnchantments) throw new Error("cityEnchantments fehlt");
  if (!d.cityMateria) throw new Error("cityMateria fehlt");
  if (!d.cityEnchantmentItems) throw new Error("cityEnchantmentItems fehlt");
  if (!d.cityMateriaItems) throw new Error("cityMateriaItems fehlt");

  const cityEnchantments = await ethers.getContractAt("CityEnchantments", d.cityEnchantments);
  const cityMateria = await ethers.getContractAt("CityMateria", d.cityMateria);
  const cityEnchantmentItems = await ethers.getContractAt("CityEnchantmentItems", d.cityEnchantmentItems);
  const cityMateriaItems = await ethers.getContractAt("CityMateriaItems", d.cityMateriaItems);

  let nextNonce = await ethers.provider.getTransactionCount(deployer.address, "pending");
  console.log("Start nonce:", nextNonce);

  // ----------------------------------------
  // ENCHANTMENTS
  // category:
  // 1 Damage
  // 3 Accuracy
  // 5 Durability
  // ----------------------------------------

  const enchantments = [
    {
      id: 1,
      name: "Fire Edge",
      category: 1,
      rarityTier: 2,
      maxLevel: 3,
      enabled: true,
      bonuses: {
        1: { ...emptyBonus(), minDamageBonus: 2, maxDamageBonus: 4, heatGenerationBonus: 1 },
        2: { ...emptyBonus(), minDamageBonus: 4, maxDamageBonus: 7, heatGenerationBonus: 2 },
        3: { ...emptyBonus(), minDamageBonus: 6, maxDamageBonus: 10, heatGenerationBonus: 3 }
      }
    },
    {
      id: 2,
      name: "Precision Sight",
      category: 3,
      rarityTier: 2,
      maxLevel: 3,
      enabled: true,
      bonuses: {
        1: { ...emptyBonus(), accuracyBpsBonus: 150, critChanceBpsBonus: 40, rangeBonus: 1 },
        2: { ...emptyBonus(), accuracyBpsBonus: 300, critChanceBpsBonus: 80, rangeBonus: 2 },
        3: { ...emptyBonus(), accuracyBpsBonus: 450, critChanceBpsBonus: 120, rangeBonus: 3 }
      }
    },
    {
      id: 3,
      name: "Durability Seal",
      category: 5,
      rarityTier: 1,
      maxLevel: 3,
      enabled: true,
      bonuses: {
        1: { ...emptyBonus(), maxDurabilityBonus: 20, stabilityBonus: 2 },
        2: { ...emptyBonus(), maxDurabilityBonus: 40, stabilityBonus: 4 },
        3: { ...emptyBonus(), maxDurabilityBonus: 70, stabilityBonus: 6 }
      }
    }
  ];

  for (const ench of enchantments) {
    console.log("----------------------------------------");
    console.log(`Setze Enchantment ${ench.id}: ${ench.name}`);

    await sendAndWait(
      cityEnchantments.setEnchantmentDefinition(
        ench.id,
        ench.name,
        ench.category,
        ench.rarityTier,
        ench.maxLevel,
        ench.enabled,
        { nonce: nextNonce++ }
      ),
      `CityEnchantments.setEnchantmentDefinition(${ench.id}, ${ench.name})`
    );

    for (let level = 1; level <= ench.maxLevel; level++) {
      await sendAndWait(
        cityEnchantments.setEnchantmentBonuses(
          ench.id,
          level,
          ench.bonuses[level],
          { nonce: nextNonce++ }
        ),
        `CityEnchantments.setEnchantmentBonuses(${ench.id}, L${level})`
      );
    }
  }

  // ----------------------------------------
  // ENCHANTMENT ITEMS
  // itemId 1..3 mapped to enchantmentId 1..3 at level 1
  // ----------------------------------------

  const enchantmentItems = [
    { itemId: 1, enchantmentDefinitionId: 1, level: 1, rarityTier: 2, burnOnUse: true, enabled: true },
    { itemId: 2, enchantmentDefinitionId: 2, level: 1, rarityTier: 2, burnOnUse: true, enabled: true },
    { itemId: 3, enchantmentDefinitionId: 3, level: 1, rarityTier: 1, burnOnUse: true, enabled: true }
  ];

  for (const item of enchantmentItems) {
    console.log("----------------------------------------");
    console.log(`Setze EnchantmentItem ${item.itemId}`);

    await sendAndWait(
      cityEnchantmentItems.setEnchantmentItemDefinition(
        item.itemId,
        item.enchantmentDefinitionId,
        item.level,
        item.rarityTier,
        item.burnOnUse,
        item.enabled,
        { nonce: nextNonce++ }
      ),
      `CityEnchantmentItems.setEnchantmentItemDefinition(${item.itemId})`
    );
  }

  // ----------------------------------------
  // MATERIA
  // category:
  // 1 Offensive
  // 6 Resonance
  // 3 Utility
  //
  // element:
  // 1 Fire
  // 10 Aether
  // 12 Energy
  // ----------------------------------------

  const materiaDefs = [
    {
      id: 1,
      name: "Fire Materia",
      category: 1,
      element: 1,
      rarityTier: 2,
      maxLevel: 3,
      enabled: true,
      bonuses: {
        1: { ...emptyBonus(), minDamageBonus: 1, maxDamageBonus: 3, heatGenerationBonus: 1 },
        2: { ...emptyBonus(), minDamageBonus: 3, maxDamageBonus: 5, heatGenerationBonus: 2 },
        3: { ...emptyBonus(), minDamageBonus: 5, maxDamageBonus: 8, heatGenerationBonus: 3 }
      }
    },
    {
      id: 2,
      name: "Resonance Materia",
      category: 6,
      element: 10,
      rarityTier: 3,
      maxLevel: 3,
      enabled: true,
      bonuses: {
        1: { ...emptyBonus(), critMultiplierBpsBonus: 300, stabilityBonus: 2 },
        2: { ...emptyBonus(), critMultiplierBpsBonus: 600, stabilityBonus: 4 },
        3: { ...emptyBonus(), critMultiplierBpsBonus: 900, stabilityBonus: 7 }
      }
    },
    {
      id: 3,
      name: "Stability Materia",
      category: 3,
      element: 11,
      rarityTier: 2,
      maxLevel: 3,
      enabled: true,
      bonuses: {
        1: { ...emptyBonus(), stabilityBonus: 4, cooldownMsBonus: -20 },
        2: { ...emptyBonus(), stabilityBonus: 7, cooldownMsBonus: -40 },
        3: { ...emptyBonus(), stabilityBonus: 10, cooldownMsBonus: -60 }
      }
    }
  ];

  for (const mat of materiaDefs) {
    console.log("----------------------------------------");
    console.log(`Setze Materia ${mat.id}: ${mat.name}`);

    await sendAndWait(
      cityMateria.setMateriaDefinition(
        mat.id,
        mat.name,
        mat.category,
        mat.element,
        mat.rarityTier,
        mat.maxLevel,
        mat.enabled,
        { nonce: nextNonce++ }
      ),
      `CityMateria.setMateriaDefinition(${mat.id}, ${mat.name})`
    );

    for (let level = 1; level <= mat.maxLevel; level++) {
      await sendAndWait(
        cityMateria.setMateriaBonuses(
          mat.id,
          level,
          mat.bonuses[level],
          { nonce: nextNonce++ }
        ),
        `CityMateria.setMateriaBonuses(${mat.id}, L${level})`
      );
    }
  }

  // ----------------------------------------
  // MATERIA ITEMS
  // itemId 1..3 mapped to materiaId 1..3 at level 1
  // ----------------------------------------

  const materiaItems = [
    { itemId: 1, materiaDefinitionId: 1, level: 1, rarityTier: 2, burnOnUse: true, enabled: true },
    { itemId: 2, materiaDefinitionId: 2, level: 1, rarityTier: 3, burnOnUse: true, enabled: true },
    { itemId: 3, materiaDefinitionId: 3, level: 1, rarityTier: 2, burnOnUse: true, enabled: true }
  ];

  for (const item of materiaItems) {
    console.log("----------------------------------------");
    console.log(`Setze MateriaItem ${item.itemId}`);

    await sendAndWait(
      cityMateriaItems.setMateriaItemDefinition(
        item.itemId,
        item.materiaDefinitionId,
        item.level,
        item.rarityTier,
        item.burnOnUse,
        item.enabled,
        { nonce: nextNonce++ }
      ),
      `CityMateriaItems.setMateriaItemDefinition(${item.itemId})`
    );
  }

  console.log("========================================");
  console.log("Enchantments + Materia + Items gesetzt.");
  console.log("Enchantments: Fire Edge / Precision Sight / Durability Seal");
  console.log("Materia: Fire Materia / Resonance Materia / Stability Materia");
  console.log("========================================");
}

main().catch((error) => {
  console.error("Fehler in 17_seed_enchantments_and_materia.js");
  console.error(error);
  process.exitCode = 1;
});