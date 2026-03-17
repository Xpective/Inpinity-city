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

async function sendAndWait(txPromise, label, delay = 2000) {
  const tx = await txPromise;
  console.log(`${label}: ${tx.hash}`);
  await tx.wait();
  await sleep(delay);
}

async function main() {
  const { ethers } = await network.connect();
  const [deployer] = await ethers.getSigners();
  const net = await ethers.provider.getNetwork();

  console.log("========================================");
  console.log("14_seed_weapon_definitions.js");
  console.log("Deployer:", deployer.address);
  console.log("Chain ID:", Number(net.chainId));
  console.log("========================================");

  const coreFile = path.resolve("deployments", "city-core.json");
  const d = loadJson(coreFile);

  if (!d.cityWeapons) {
    throw new Error("cityWeapons fehlt in deployments/city-core.json");
  }

  const cityWeapons = await ethers.getContractAt("CityWeapons", d.cityWeapons);

  let nextNonce = await ethers.provider.getTransactionCount(deployer.address, "pending");
  console.log("Start nonce:", nextNonce);

  const defs = [
    {
      id: 1,
      name: "Iron Sword",
      class: 1, // Sword
      damageType: 1, // Physical
      techTier: 1,
      requiredLevel: 1,
      requiredTechTier: 1,
      minDamage: 12,
      maxDamage: 18,
      attackSpeed: 10,
      critChanceBps: 300,
      critMultiplierBps: 15000,
      accuracyBps: 9200,
      range: 2,
      maxDurability: 120,
      armorPenBps: 100,
      blockChanceBps: 0,
      lifeStealBps: 0,
      energyCost: 0,
      heatGeneration: 0,
      stability: 90,
      cooldownMs: 900,
      projectileSpeed: 0,
      aoeRadius: 0,
      enchantmentSlots: 1,
      materiaSlots: 1,
      visualVariant: 1,
      maxUpgradeLevel: 7,
      familySetId: 1,
      enabled: true
    },
    {
      id: 2,
      name: "Crystal Bow",
      class: 4, // Bow
      damageType: 7, // Crystal
      techTier: 2,
      requiredLevel: 3,
      requiredTechTier: 2,
      minDamage: 16,
      maxDamage: 24,
      attackSpeed: 9,
      critChanceBps: 700,
      critMultiplierBps: 16500,
      accuracyBps: 9500,
      range: 14,
      maxDurability: 100,
      armorPenBps: 250,
      blockChanceBps: 0,
      lifeStealBps: 0,
      energyCost: 2,
      heatGeneration: 0,
      stability: 82,
      cooldownMs: 1100,
      projectileSpeed: 18,
      aoeRadius: 0,
      enchantmentSlots: 2,
      materiaSlots: 1,
      visualVariant: 1,
      maxUpgradeLevel: 7,
      familySetId: 2,
      enabled: true
    },
    {
      id: 3,
      name: "Plasma Rifle",
      class: 10, // PlasmaRifle
      damageType: 11, // Plasma
      techTier: 4,
      requiredLevel: 8,
      requiredTechTier: 4,
      minDamage: 28,
      maxDamage: 40,
      attackSpeed: 8,
      critChanceBps: 500,
      critMultiplierBps: 17000,
      accuracyBps: 9600,
      range: 20,
      maxDurability: 140,
      armorPenBps: 500,
      blockChanceBps: 0,
      lifeStealBps: 0,
      energyCost: 8,
      heatGeneration: 12,
      stability: 75,
      cooldownMs: 1300,
      projectileSpeed: 26,
      aoeRadius: 1,
      enchantmentSlots: 2,
      materiaSlots: 2,
      visualVariant: 1,
      maxUpgradeLevel: 9,
      familySetId: 3,
      enabled: true
    }
  ];

  for (const def of defs) {
    console.log("----------------------------------------");
    console.log(`Setze WeaponDefinition ${def.id}: ${def.name}`);

    await sendAndWait(
      cityWeapons.setWeaponDefinition(
        def.id,
        def.name,
        def.class,
        def.damageType,
        def.techTier,
        def.requiredLevel,
        def.requiredTechTier,
        def.minDamage,
        def.maxDamage,
        def.attackSpeed,
        def.critChanceBps,
        def.critMultiplierBps,
        def.accuracyBps,
        def.range,
        def.maxDurability,
        def.armorPenBps,
        def.blockChanceBps,
        def.lifeStealBps,
        def.energyCost,
        def.heatGeneration,
        def.stability,
        def.cooldownMs,
        def.projectileSpeed,
        def.aoeRadius,
        def.enchantmentSlots,
        def.materiaSlots,
        def.visualVariant,
        def.maxUpgradeLevel,
        def.familySetId,
        def.enabled,
        { nonce: nextNonce++ }
      ),
      `CityWeapons.setWeaponDefinition(${def.id}, ${def.name})`
    );
  }

  console.log("========================================");
  console.log("Weapon definitions gesetzt.");
  console.log("IDs: 1 = Iron Sword, 2 = Crystal Bow, 3 = Plasma Rifle");
  console.log("========================================");
}

main().catch((error) => {
  console.error("Fehler in 14_seed_weapon_definitions.js");
  console.error(error);
  process.exitCode = 1;
});