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

async function main() {
  const { ethers } = await network.connect();
  const [deployer] = await ethers.getSigners();
  const net = await ethers.provider.getNetwork();

  console.log("========================================");
  console.log("21_seed_axe_weapon_definitions.js");
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

  // CityWeapons enums:
  // WeaponClass.Axe = 2
  // DamageType.Physical = 1
  // DamageType.Crystal = 7
  // DamageType.Plasma = 11

  const weapons = [
    {
      id: 4,
      name: "Iron Axe",
      weaponClass: 2,
      damageType: 1,
      techTier: 1,
      requiredLevel: 1,
      requiredTechTier: 1,
      minDamage: 15,
      maxDamage: 24,
      attackSpeed: 8,
      critChanceBps: 250,
      critMultiplierBps: 15500,
      accuracyBps: 8800,
      range: 2,
      maxDurability: 145,
      armorPenBps: 180,
      blockChanceBps: 0,
      lifeStealBps: 0,
      energyCost: 0,
      heatGeneration: 0,
      stability: 88,
      cooldownMs: 1050,
      projectileSpeed: 0,
      aoeRadius: 0,
      enchantmentSlots: 1,
      materiaSlots: 1,
      visualVariant: 1,
      maxUpgradeLevel: 7,
      familySetId: 4,
      enabled: true
    },
    {
      id: 5,
      name: "Crystal Axe",
      weaponClass: 2,
      damageType: 7,
      techTier: 2,
      requiredLevel: 3,
      requiredTechTier: 2,
      minDamage: 20,
      maxDamage: 31,
      attackSpeed: 8,
      critChanceBps: 500,
      critMultiplierBps: 16800,
      accuracyBps: 9000,
      range: 2,
      maxDurability: 150,
      armorPenBps: 300,
      blockChanceBps: 0,
      lifeStealBps: 0,
      energyCost: 2,
      heatGeneration: 0,
      stability: 84,
      cooldownMs: 1100,
      projectileSpeed: 0,
      aoeRadius: 0,
      enchantmentSlots: 2,
      materiaSlots: 1,
      visualVariant: 1,
      maxUpgradeLevel: 8,
      familySetId: 5,
      enabled: true
    },
    {
      id: 6,
      name: "Plasma Cleaver",
      weaponClass: 2,
      damageType: 11,
      techTier: 4,
      requiredLevel: 8,
      requiredTechTier: 4,
      minDamage: 30,
      maxDamage: 45,
      attackSpeed: 7,
      critChanceBps: 420,
      critMultiplierBps: 17500,
      accuracyBps: 9100,
      range: 2,
      maxDurability: 165,
      armorPenBps: 550,
      blockChanceBps: 0,
      lifeStealBps: 0,
      energyCost: 7,
      heatGeneration: 10,
      stability: 76,
      cooldownMs: 1250,
      projectileSpeed: 0,
      aoeRadius: 1,
      enchantmentSlots: 2,
      materiaSlots: 2,
      visualVariant: 1,
      maxUpgradeLevel: 9,
      familySetId: 6,
      enabled: true
    }
  ];

  for (const w of weapons) {
    console.log("----------------------------------------");
    console.log(`Setze WeaponDefinition ${w.id}: ${w.name}`);

    await sendAndWait(
      cityWeapons.setWeaponDefinition(
        w.id,
        w.name,
        w.weaponClass,
        w.damageType,
        w.techTier,
        w.requiredLevel,
        w.requiredTechTier,
        w.minDamage,
        w.maxDamage,
        w.attackSpeed,
        w.critChanceBps,
        w.critMultiplierBps,
        w.accuracyBps,
        w.range,
        w.maxDurability,
        w.armorPenBps,
        w.blockChanceBps,
        w.lifeStealBps,
        w.energyCost,
        w.heatGeneration,
        w.stability,
        w.cooldownMs,
        w.projectileSpeed,
        w.aoeRadius,
        w.enchantmentSlots,
        w.materiaSlots,
        w.visualVariant,
        w.maxUpgradeLevel,
        w.familySetId,
        w.enabled,
        { nonce: nextNonce++ }
      ),
      `CityWeapons.setWeaponDefinition(${w.id}, ${w.name})`
    );
  }

  console.log("========================================");
  console.log("Axe weapon definitions gesetzt.");
  console.log("4 = Iron Axe");
  console.log("5 = Crystal Axe");
  console.log("6 = Plasma Cleaver");
  console.log("========================================");
}

main().catch((error) => {
  console.error("Fehler in 21_seed_axe_weapon_definitions.js");
  console.error(error);
  process.exitCode = 1;
});