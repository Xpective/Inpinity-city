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

async function sendAndWait(txPromise, label, delay = 1500) {
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
  console.log("12_wire_core.js");
  console.log("Deployer:", deployer.address);
  console.log("Chain ID:", Number(net.chainId));
  console.log("========================================");

  const coreFile = path.resolve("deployments", "city-core.json");
  const deployed = JSON.parse(fs.readFileSync(coreFile, "utf8"));

  const requiredKeys = [
    "cityConfig",
    "cityRegistry",
    "cityLand",
    "cityDistricts",
    "cityStatus",
    "cityHistory",
    "cityValidation"
  ];

  for (const key of requiredKeys) {
    if (!deployed[key]) {
      throw new Error(`${key} fehlt in deployments/city-core.json`);
    }
  }

  const cityRegistry = await ethers.getContractAt("CityRegistry", deployed.cityRegistry);
  const cityLand = await ethers.getContractAt("CityLand", deployed.cityLand);
  const cityDistricts = await ethers.getContractAt("CityDistricts", deployed.cityDistricts);
  const cityStatus = await ethers.getContractAt("CityStatus", deployed.cityStatus);
  const cityHistory = await ethers.getContractAt("CityHistory", deployed.cityHistory);

  let nextNonce = await ethers.provider.getTransactionCount(deployer.address, "pending");
  console.log("Start nonce:", nextNonce);

  // 1) Registry -> History
  await sendAndWait(
    cityRegistry.setCityHistory(deployed.cityHistory, { nonce: nextNonce++ }),
    "CityRegistry.setCityHistory"
  );

  // 2) History erlaubt Registry
  await sendAndWait(
    cityHistory.setAuthorizedCaller(deployed.cityRegistry, true, { nonce: nextNonce++ }),
    "CityHistory.setAuthorizedCaller(cityRegistry)"
  );

  // 3) Status erlaubt Land
  await sendAndWait(
    cityStatus.setAuthorizedCaller(deployed.cityLand, true, { nonce: nextNonce++ }),
    "CityStatus.setAuthorizedCaller(cityLand)"
  );

  // 4) Districts erlaubt Registry
  await sendAndWait(
    cityDistricts.setAuthorizedCaller(deployed.cityRegistry, true, { nonce: nextNonce++ }),
    "CityDistricts.setAuthorizedCaller(cityRegistry)"
  );

  // 5) Land -> Hooks(Status, History)
  await sendAndWait(
    cityLand.setHooks(deployed.cityStatus, deployed.cityHistory, { nonce: nextNonce++ }),
    "CityLand.setHooks(status, history)"
  );

  console.log("========================================");
  console.log("Core-Wiring fertig.");
  console.log("========================================");
}

main().catch((error) => {
  console.error("Fehler in 12_wire_core.js");
  console.error(error);
  process.exitCode = 1;
});