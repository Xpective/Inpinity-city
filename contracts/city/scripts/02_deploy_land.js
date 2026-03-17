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

function saveJson(filePath, data) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
}

async function main() {
  const { ethers } = await network.connect();
  const [deployer] = await ethers.getSigners();
  const net = await ethers.provider.getNetwork();

  console.log("========================================");
  console.log("02_deploy_land.js");
  console.log("Deployer:", deployer.address);
  console.log("Chain ID:", Number(net.chainId));
  console.log("========================================");

  const coreFile = path.resolve("deployments", "city-core.json");
  const existing = loadJson(coreFile);

  if (!existing.cityConfig) {
    throw new Error("cityConfig fehlt in deployments/city-core.json");
  }

  if (!existing.cityRegistry) {
    throw new Error("cityRegistry fehlt in deployments/city-core.json");
  }

  const cityConfigAddress = existing.cityConfig;
  const cityRegistryAddress = existing.cityRegistry;

  console.log("Nutze CityConfig:", cityConfigAddress);
  console.log("Nutze CityRegistry:", cityRegistryAddress);

  let nextNonce = await ethers.provider.getTransactionCount(deployer.address, "pending");
  console.log("Start nonce:", nextNonce);

  const CityLand = await ethers.getContractFactory("CityLand");
  const cityLand = await CityLand.deploy(
    deployer.address,
    cityConfigAddress,
    cityRegistryAddress,
    { nonce: nextNonce++ }
  );
  await cityLand.waitForDeployment();

  const cityLandAddress = await cityLand.getAddress();
  console.log("CityLand deployed:", cityLandAddress);

  await sleep(2500);

  const merged = {
    ...existing,
    chainId: Number(net.chainId),
    deployer: deployer.address,
    cityLand: cityLandAddress,
    updatedAt: new Date().toISOString()
  };

  saveJson(coreFile, merged);

  console.log("========================================");
  console.log("CityLand fertig.");
  console.log("JSON aktualisiert:", coreFile);
  console.log("========================================");
}

main().catch((error) => {
  console.error("Fehler in 02_deploy_land.js");
  console.error(error);
  process.exitCode = 1;
});