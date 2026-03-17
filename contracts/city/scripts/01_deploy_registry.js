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
  console.log("01_deploy_registry.js");
  console.log("Deployer:", deployer.address);
  console.log("Chain ID:", Number(net.chainId));
  console.log("========================================");

  const coreFile = path.resolve("deployments", "city-core.json");
  const existing = loadJson(coreFile);

  if (!existing.cityConfig) {
    throw new Error("cityConfig fehlt in deployments/city-core.json");
  }

  const cityConfigAddress = existing.cityConfig;
  console.log("Nutze CityConfig:", cityConfigAddress);

  let nextNonce = await ethers.provider.getTransactionCount(deployer.address, "pending");
  console.log("Start nonce:", nextNonce);

  const CityRegistry = await ethers.getContractFactory("CityRegistry");
  const cityRegistry = await CityRegistry.deploy(
    deployer.address,
    cityConfigAddress,
    { nonce: nextNonce++ }
  );
  await cityRegistry.waitForDeployment();

  const cityRegistryAddress = await cityRegistry.getAddress();
  console.log("CityRegistry deployed:", cityRegistryAddress);

  await sleep(2500);

  const merged = {
    ...existing,
    chainId: Number(net.chainId),
    deployer: deployer.address,
    cityRegistry: cityRegistryAddress,
    updatedAt: new Date().toISOString()
  };

  saveJson(coreFile, merged);

  console.log("========================================");
  console.log("CityRegistry fertig.");
  console.log("JSON aktualisiert:", coreFile);
  console.log("========================================");
}

main().catch((error) => {
  console.error("Fehler in 01_deploy_registry.js");
  console.error(error);
  process.exitCode = 1;
});