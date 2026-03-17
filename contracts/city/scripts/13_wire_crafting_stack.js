import { network } from "hardhat";
import fs from "fs";
import path from "path";

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function loadJson(filePath) {
  if (!fs.existsSync(filePath)) throw new Error(`Datei nicht gefunden: ${filePath}`);
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function getOptionalEnv(name, fallback = "") {
  const v = process.env[name];
  return v && v.trim() !== "" ? v.trim() : fallback;
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
  console.log("13_wire_crafting_stack.js");
  console.log("Deployer:", deployer.address);
  console.log("Chain ID:", Number(net.chainId));
  console.log("========================================");

  const coreFile = path.resolve("deployments", "city-core.json");
  const d = loadJson(coreFile);

  const required = [
    "cityComponents",
    "cityBlueprints",
    "cityEnchantments",
    "cityEnchantmentItems",
    "cityMateria",
    "cityMateriaItems",
    "cityWeapons",
    "cityWeaponSockets",
    "cityCrafting",
    "cityEnchanting",
    "cityMateriaSystem"
  ];
  for (const k of required) {
    if (!d[k]) throw new Error(`${k} fehlt in deployments/city-core.json`);
  }

  const weaponsBaseUri = getOptionalEnv(
    "CITY_WEAPONS_BASE_URI",
    "https://assets.inpinity.online/city/metadata/weapons/"
  );

  const CityWeapons = await ethers.getContractAt("CityWeapons", d.cityWeapons);
  const CityWeaponSockets = await ethers.getContractAt("CityWeaponSockets", d.cityWeaponSockets);
  const CityComponents = await ethers.getContractAt("CityComponents", d.cityComponents);
  const CityBlueprints = await ethers.getContractAt("CityBlueprints", d.cityBlueprints);
  const CityCrafting = await ethers.getContractAt("CityCrafting", d.cityCrafting);
  const CityEnchantmentItems = await ethers.getContractAt("CityEnchantmentItems", d.cityEnchantmentItems);
  const CityMateriaItems = await ethers.getContractAt("CityMateriaItems", d.cityMateriaItems);

  let nextNonce = await ethers.provider.getTransactionCount(deployer.address, "pending");
  console.log("Start nonce:", nextNonce);

  // 1) Weapons: sockets + baseURI
  await sendAndWait(
    CityWeapons.setWeaponSockets(d.cityWeaponSockets, { nonce: nextNonce++ }),
    "CityWeapons.setWeaponSockets"
  );

  await sendAndWait(
    CityWeapons.setBaseURI(weaponsBaseUri, { nonce: nextNonce++ }),
    "CityWeapons.setBaseURI"
  );

  // 2) Authorize Crafting as minter
  await sendAndWait(
    CityWeapons.setAuthorizedMinter(d.cityCrafting, true, { nonce: nextNonce++ }),
    "CityWeapons.setAuthorizedMinter(cityCrafting)"
  );

  await sendAndWait(
    CityComponents.setAuthorizedMinter(d.cityCrafting, true, { nonce: nextNonce++ }),
    "CityComponents.setAuthorizedMinter(cityCrafting)"
  );

  await sendAndWait(
    CityBlueprints.setAuthorizedMinter(d.cityCrafting, true, { nonce: nextNonce++ }),
    "CityBlueprints.setAuthorizedMinter(cityCrafting)"
  );

  // 3) Crafting knows token contracts
  await sendAndWait(
    CityCrafting.setCityWeapons(d.cityWeapons, { nonce: nextNonce++ }),
    "CityCrafting.setCityWeapons"
  );

  await sendAndWait(
    CityCrafting.setCityComponents(d.cityComponents, { nonce: nextNonce++ }),
    "CityCrafting.setCityComponents"
  );

  await sendAndWait(
    CityCrafting.setCityBlueprints(d.cityBlueprints, { nonce: nextNonce++ }),
    "CityCrafting.setCityBlueprints"
  );

  // 4) Sockets: allow Enchanting + MateriaSystem
  await sendAndWait(
    CityWeaponSockets.setAuthorizedCaller(d.cityEnchanting, true, { nonce: nextNonce++ }),
    "CityWeaponSockets.setAuthorizedCaller(cityEnchanting)"
  );

  await sendAndWait(
    CityWeaponSockets.setAuthorizedCaller(d.cityMateriaSystem, true, { nonce: nextNonce++ }),
    "CityWeaponSockets.setAuthorizedCaller(cityMateriaSystem)"
  );

  // 5) Items: allow their systems to burn
  await sendAndWait(
    CityEnchantmentItems.setAuthorizedConsumer(d.cityEnchanting, true, { nonce: nextNonce++ }),
    "CityEnchantmentItems.setAuthorizedConsumer(cityEnchanting)"
  );

  await sendAndWait(
    CityMateriaItems.setAuthorizedConsumer(d.cityMateriaSystem, true, { nonce: nextNonce++ }),
    "CityMateriaItems.setAuthorizedConsumer(cityMateriaSystem)"
  );

  console.log("========================================");
  console.log("Crafting-Wiring fertig ✅");
  console.log("Weapons BaseURI:", weaponsBaseUri);
  console.log("========================================");
}

main().catch((e) => {
  console.error("Fehler in 13_wire_crafting_stack.js");
  console.error(e);
  process.exitCode = 1;
});