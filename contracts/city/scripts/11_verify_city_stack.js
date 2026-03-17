import { network } from "hardhat";
import fs from "fs";
import path from "path";

function loadJson(filePath) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`Datei nicht gefunden: ${filePath}`);
  }
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function line(title, value) {
  console.log(`${title}:`, value);
}

async function safeCall(label, fn) {
  try {
    const value = await fn();
    console.log(`✅ ${label}:`, value);
    return value;
  } catch (err) {
    console.log(`❌ ${label}:`, err?.message || err);
    return null;
  }
}

async function main() {
  const { ethers } = await network.connect();
  const [deployer] = await ethers.getSigners();
  const net = await ethers.provider.getNetwork();

  console.log("========================================");
  console.log("11_verify_city_stack.js");
  line("Deployer", deployer.address);
  line("Chain ID", Number(net.chainId));
  console.log("========================================");

  const coreFile = path.resolve("deployments", "city-core.json");
  const d = loadJson(coreFile);

  const required = [
    "cityConfig",
    "cityRegistry",
    "cityHistory",
    "cityStatus",
    "cityLand",
    "cityDistricts",
    "cityValidation",
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

  for (const key of required) {
    if (!d[key]) throw new Error(`${key} fehlt in deployments/city-core.json`);
  }

  const CityConfig = await ethers.getContractAt("CityConfig", d.cityConfig);
  const CityRegistry = await ethers.getContractAt("CityRegistry", d.cityRegistry);
  const CityHistory = await ethers.getContractAt("CityHistory", d.cityHistory);
  const CityStatus = await ethers.getContractAt("CityStatus", d.cityStatus);
  const CityLand = await ethers.getContractAt("CityLand", d.cityLand);
  const CityDistricts = await ethers.getContractAt("CityDistricts", d.cityDistricts);

  const CityComponents = await ethers.getContractAt("CityComponents", d.cityComponents);
  const CityBlueprints = await ethers.getContractAt("CityBlueprints", d.cityBlueprints);
  const CityEnchantments = await ethers.getContractAt("CityEnchantments", d.cityEnchantments);
  const CityEnchantmentItems = await ethers.getContractAt("CityEnchantmentItems", d.cityEnchantmentItems);
  const CityMateria = await ethers.getContractAt("CityMateria", d.cityMateria);
  const CityMateriaItems = await ethers.getContractAt("CityMateriaItems", d.cityMateriaItems);
  const CityWeapons = await ethers.getContractAt("CityWeapons", d.cityWeapons);
  const CityWeaponSockets = await ethers.getContractAt("CityWeaponSockets", d.cityWeaponSockets);
  const CityCrafting = await ethers.getContractAt("CityCrafting", d.cityCrafting);

  console.log("----- ADDRESSES -----");
  for (const key of required) {
    line(key, d[key]);
  }

  console.log("----- CORE CHECKS -----");
  await safeCall("CityRegistry.cityHistory()", () => CityRegistry.cityHistory());
  await safeCall("CityHistory.authorizedCallers(cityRegistry)", () => CityHistory.authorizedCallers(d.cityRegistry));
  await safeCall("CityStatus.authorizedCallers(cityLand)", () => CityStatus.authorizedCallers(d.cityLand));
  await safeCall("CityDistricts.authorizedCallers(cityRegistry)", () => CityDistricts.authorizedCallers(d.cityRegistry));
  await safeCall("CityLand.cityStatus()", () => CityLand.cityStatus());
  await safeCall("CityLand.cityHistory()", () => CityLand.cityHistory());

  console.log("----- CONFIG CHECKS -----");
  await safeCall("Config RESOURCE_TOKEN", async () =>
    CityConfig.getAddressConfig(await CityConfig.KEY_RESOURCE_TOKEN())
  );
  await safeCall("Config TREASURY", async () =>
    CityConfig.getAddressConfig(await CityConfig.KEY_TREASURY())
  );
  await safeCall("Config INPI", async () =>
    CityConfig.getAddressConfig(await CityConfig.KEY_INPI())
  );
  await safeCall("Config PITRONE", async () =>
    CityConfig.getAddressConfig(await CityConfig.KEY_PITRONE())
  );
  await safeCall("Config MAX_PERSONAL_PLOTS", async () =>
    (await CityConfig.getUintConfig(await CityConfig.KEY_MAX_PERSONAL_PLOTS())).toString()
  );
  await safeCall("Config INACTIVITY_DAYS", async () =>
    (await CityConfig.getUintConfig(await CityConfig.KEY_INACTIVITY_DAYS())).toString()
  );

  console.log("----- CRAFTING / URI CHECKS -----");
  await safeCall("CityComponents.baseMetadataURI()", () => CityComponents.baseMetadataURI());
  await safeCall("CityBlueprints.baseMetadataURI()", () => CityBlueprints.baseMetadataURI());
  await safeCall("CityEnchantmentItems.baseMetadataURI()", () => CityEnchantmentItems.baseMetadataURI());
  await safeCall("CityMateriaItems.baseMetadataURI()", () => CityMateriaItems.baseMetadataURI());
  await safeCall("CityWeapons.baseTokenURI()", () => CityWeapons.baseTokenURI());

  console.log("----- AUTHORIZATION CHECKS -----");
  await safeCall("CityWeapons.authorizedMinters(cityCrafting)", () =>
    CityWeapons.authorizedMinters(d.cityCrafting)
  );
  await safeCall("CityComponents.authorizedMinters(cityCrafting)", () =>
    CityComponents.authorizedMinters(d.cityCrafting)
  );
  await safeCall("CityBlueprints.authorizedMinters(cityCrafting)", () =>
    CityBlueprints.authorizedMinters(d.cityCrafting)
  );
  await safeCall("CityWeaponSockets.authorizedCallers(cityEnchanting)", () =>
    CityWeaponSockets.authorizedCallers(d.cityEnchanting)
  );
  await safeCall("CityWeaponSockets.authorizedCallers(cityMateriaSystem)", () =>
    CityWeaponSockets.authorizedCallers(d.cityMateriaSystem)
  );
  await safeCall("CityEnchantmentItems.authorizedConsumers(cityEnchanting)", () =>
    CityEnchantmentItems.authorizedConsumers(d.cityEnchanting)
  );
  await safeCall("CityMateriaItems.authorizedConsumers(cityMateriaSystem)", () =>
    CityMateriaItems.authorizedConsumers(d.cityMateriaSystem)
  );

  console.log("----- CONTRACT LINK CHECKS -----");
  await safeCall("CityWeapons.cityWeaponSockets()", () => CityWeapons.cityWeaponSockets());
  await safeCall("CityCrafting.cityWeapons()", () => CityCrafting.cityWeapons());
  await safeCall("CityCrafting.cityComponents()", () => CityCrafting.cityComponents());
  await safeCall("CityCrafting.cityBlueprints()", () => CityCrafting.cityBlueprints());

  console.log("----- OWNER CHECKS -----");
  await safeCall("CityComponents.owner()", () => CityComponents.owner());
  await safeCall("CityBlueprints.owner()", () => CityBlueprints.owner());
  await safeCall("CityEnchantments.owner()", () => CityEnchantments.owner());
  await safeCall("CityEnchantmentItems.owner()", () => CityEnchantmentItems.owner());
  await safeCall("CityMateria.owner()", () => CityMateria.owner());
  await safeCall("CityMateriaItems.owner()", () => CityMateriaItems.owner());
  await safeCall("CityWeapons.owner()", () => CityWeapons.owner());
  await safeCall("CityWeaponSockets.owner()", () => CityWeaponSockets.owner());
  await safeCall("CityCrafting.owner()", () => CityCrafting.owner());

  console.log("----- PAUSE FLAGS -----");
  await safeCall("CityWeapons.weaponsPaused()", () => CityWeapons.weaponsPaused());
  await safeCall("CityCrafting.craftingPaused()", () => CityCrafting.craftingPaused());

  console.log("========================================");
  console.log("Verify abgeschlossen.");
  console.log("========================================");
}

main().catch((error) => {
  console.error("Fehler in 11_verify_city_stack.js");
  console.error(error);
  process.exitCode = 1;
});