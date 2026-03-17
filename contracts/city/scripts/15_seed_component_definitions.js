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
  console.log("15_seed_component_definitions.js");
  console.log("Deployer:", deployer.address);
  console.log("Chain ID:", Number(net.chainId));
  console.log("========================================");

  const coreFile = path.resolve("deployments", "city-core.json");
  const d = loadJson(coreFile);

  if (!d.cityComponents) {
    throw new Error("cityComponents fehlt in deployments/city-core.json");
  }

  const cityComponents = await ethers.getContractAt("CityComponents", d.cityComponents);

  let nextNonce = await ethers.provider.getTransactionCount(deployer.address, "pending");
  console.log("Start nonce:", nextNonce);

  // category Vorschlag:
  // 1 = Blade
  // 2 = Hilt
  // 3 = Core
  // 4 = BowPart
  // 5 = Chamber
  // 6 = Coil
  // 7 = Stabilizer
  // 8 = Grip

  const defs = [
    {
      id: 1,
      name: "Iron Blade",
      category: 1,
      rarityTier: 1,
      techTier: 1,
      enabled: true
    },
    {
      id: 2,
      name: "Reinforced Hilt",
      category: 2,
      rarityTier: 1,
      techTier: 1,
      enabled: true
    },
    {
      id: 3,
      name: "Crystal Core",
      category: 3,
      rarityTier: 2,
      techTier: 2,
      enabled: true
    },
    {
      id: 4,
      name: "Bow Limb",
      category: 4,
      rarityTier: 1,
      techTier: 1,
      enabled: true
    },
    {
      id: 5,
      name: "Bow String",
      category: 4,
      rarityTier: 1,
      techTier: 1,
      enabled: true
    },
    {
      id: 6,
      name: "Plasma Chamber",
      category: 5,
      rarityTier: 3,
      techTier: 4,
      enabled: true
    },
    {
      id: 7,
      name: "Energy Coil",
      category: 6,
      rarityTier: 3,
      techTier: 4,
      enabled: true
    },
    {
      id: 8,
      name: "Stabilizer",
      category: 7,
      rarityTier: 2,
      techTier: 3,
      enabled: true
    },
    {
      id: 9,
      name: "Resonance Grip",
      category: 8,
      rarityTier: 2,
      techTier: 3,
      enabled: true
    }
  ];

  for (const def of defs) {
    console.log("----------------------------------------");
    console.log(`Setze ComponentDefinition ${def.id}: ${def.name}`);

    await sendAndWait(
      cityComponents.setComponentDefinition(
        def.id,
        def.name,
        def.category,
        def.rarityTier,
        def.techTier,
        def.enabled,
        { nonce: nextNonce++ }
      ),
      `CityComponents.setComponentDefinition(${def.id}, ${def.name})`
    );
  }

  console.log("========================================");
  console.log("Component definitions gesetzt.");
  console.log("1 Iron Blade");
  console.log("2 Reinforced Hilt");
  console.log("3 Crystal Core");
  console.log("4 Bow Limb");
  console.log("5 Bow String");
  console.log("6 Plasma Chamber");
  console.log("7 Energy Coil");
  console.log("8 Stabilizer");
  console.log("9 Resonance Grip");
  console.log("========================================");
}

main().catch((error) => {
  console.error("Fehler in 15_seed_component_definitions.js");
  console.error(error);
  process.exitCode = 1;
});
