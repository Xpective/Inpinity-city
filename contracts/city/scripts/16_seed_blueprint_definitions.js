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
  console.log("16_seed_blueprint_definitions.js");
  console.log("Deployer:", deployer.address);
  console.log("Chain ID:", Number(net.chainId));
  console.log("========================================");

  const coreFile = path.resolve("deployments", "city-core.json");
  const d = loadJson(coreFile);

  if (!d.cityBlueprints) {
    throw new Error("cityBlueprints fehlt in deployments/city-core.json");
  }

  const cityBlueprints = await ethers.getContractAt("CityBlueprints", d.cityBlueprints);

  let nextNonce = await ethers.provider.getTransactionCount(deployer.address, "pending");
  console.log("Start nonce:", nextNonce);

  const defs = [
    {
      id: 1,
      name: "Iron Sword Blueprint",
      rarityTier: 1,
      techTier: 1,
      factionLock: 0,
      districtLock: 0,
      enabled: true
    },
    {
      id: 2,
      name: "Crystal Bow Blueprint",
      rarityTier: 2,
      techTier: 2,
      factionLock: 0,
      districtLock: 0,
      enabled: true
    },
    {
      id: 3,
      name: "Plasma Rifle Blueprint",
      rarityTier: 3,
      techTier: 4,
      factionLock: 0,
      districtLock: 0,
      enabled: true
    }
  ];

  for (const def of defs) {
    console.log("----------------------------------------");
    console.log(`Setze BlueprintDefinition ${def.id}: ${def.name}`);

    await sendAndWait(
      cityBlueprints.setBlueprintDefinition(
        def.id,
        def.name,
        def.rarityTier,
        def.techTier,
        def.factionLock,
        def.districtLock,
        def.enabled,
        { nonce: nextNonce++ }
      ),
      `CityBlueprints.setBlueprintDefinition(${def.id}, ${def.name})`
    );
  }

  console.log("========================================");
  console.log("Blueprint definitions gesetzt.");
  console.log("1 Iron Sword Blueprint");
  console.log("2 Crystal Bow Blueprint");
  console.log("3 Plasma Rifle Blueprint");
  console.log("========================================");
}

main().catch((error) => {
  console.error("Fehler in 16_seed_blueprint_definitions.js");
  console.error(error);
  process.exitCode = 1;
});