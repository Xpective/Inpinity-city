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
  console.log("03_deploy_districts.js");
  console.log("Deployer:", deployer.address);
  console.log("Chain ID:", Number(net.chainId));
  console.log("========================================");

  const coreFile = path.resolve("deployments", "city-core.json");
  const existing = loadJson(coreFile);

  if (!existing.cityRegistry) {
    throw new Error("cityRegistry fehlt in deployments/city-core.json");
  }

  const cityRegistryAddress = existing.cityRegistry;
  console.log("Nutze CityRegistry:", cityRegistryAddress);

  let nextNonce = await ethers.provider.getTransactionCount(deployer.address, "pending");
  console.log("Start nonce:", nextNonce);

  const CityDistricts = await ethers.getContractFactory("CityDistricts");
  const cityDistricts = await CityDistricts.deploy(
    deployer.address,
    cityRegistryAddress,
    { nonce: nextNonce++ }
  );
  await cityDistricts.waitForDeployment();

  const cityDistrictsAddress = await cityDistricts.getAddress();
  console.log("CityDistricts deployed:", cityDistrictsAddress);

  await sleep(2500);

  const merged = {
    ...existing,
    chainId: Number(net.chainId),
    deployer: deployer.address,
    cityDistricts: cityDistrictsAddress,
    updatedAt: new Date().toISOString()
  };

  saveJson(coreFile, merged);

  console.log("========================================");
  console.log("CityDistricts fertig.");
  console.log("JSON aktualisiert:", coreFile);
  console.log("========================================");
}

main().catch((error) => {
  console.error("Fehler in 03_deploy_districts.js");
  console.error(error);
  process.exitCode = 1;
});