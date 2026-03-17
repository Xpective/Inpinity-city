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
  console.log("17b_resume_materia_items.js");
  console.log("Deployer:", deployer.address);
  console.log("Chain ID:", Number(net.chainId));
  console.log("========================================");

  const coreFile = path.resolve("deployments", "city-core.json");
  const d = loadJson(coreFile);

  const cityMateria = await ethers.getContractAt("CityMateria", d.cityMateria);
  const cityMateriaItems = await ethers.getContractAt("CityMateriaItems", d.cityMateriaItems);

  let nextNonce = await ethers.provider.getTransactionCount(deployer.address, "pending");
  console.log("Start nonce:", nextNonce);

  const mat = {
    id: 3,
    name: "Stability Materia",
    category: 3, // Utility
    element: 11, // Energy
    rarityTier: 2,
    maxLevel: 3,
    enabled: true,
    bonuses: {
      1: { ...emptyBonus(), stabilityBonus: 4, cooldownMsBonus: -20 },
      2: { ...emptyBonus(), stabilityBonus: 7, cooldownMsBonus: -40 },
      3: { ...emptyBonus(), stabilityBonus: 10, cooldownMsBonus: -60 }
    }
  };

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
  console.log("Resume für Materia + MateriaItems abgeschlossen.");
  console.log("========================================");
}

main().catch((error) => {
  console.error("Fehler in 17b_resume_materia_items.js");
  console.error(error);
  process.exitCode = 1;
});