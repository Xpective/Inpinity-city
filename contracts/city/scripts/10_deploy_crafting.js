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

function getOptionalEnv(name, fallback = "") {
  const value = process.env[name];
  return value && value.trim() !== "" ? value.trim() : fallback;
}

async function deployWithNonce(label, factory, args, nonceRef, delay = 2500) {
  const contract = await factory.deploy(...args, { nonce: nonceRef.value++ });
  await contract.waitForDeployment();
  const address = await contract.getAddress();
  console.log(`${label} deployed: ${address}`);
  await sleep(delay);
  return { contract, address };
}

async function main() {
  const { ethers } = await network.connect();
  const [deployer] = await ethers.getSigners();
  const net = await ethers.provider.getNetwork();

  console.log("========================================");
  console.log("10_deploy_crafting.js");
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

  const componentsBaseUri = getOptionalEnv(
    "CITY_COMPONENTS_BASE_URI",
    "https://assets.inpinity.online/city/metadata/components/"
  );

  const blueprintsBaseUri = getOptionalEnv(
    "CITY_BLUEPRINTS_BASE_URI",
    "https://assets.inpinity.online/city/metadata/blueprints/"
  );

  const enchantmentItemsBaseUri = getOptionalEnv(
    "CITY_ENCHANTMENT_ITEMS_BASE_URI",
    "https://assets.inpinity.online/city/metadata/enchantment-items/"
  );

  const materiaItemsBaseUri = getOptionalEnv(
    "CITY_MATERIA_ITEMS_BASE_URI",
    "https://assets.inpinity.online/city/metadata/materia-items/"
  );

  let nextNonce = await ethers.provider.getTransactionCount(deployer.address, "pending");
  const nonceRef = { value: nextNonce };
  console.log("Start nonce:", nonceRef.value);

  const CityComponents = await ethers.getContractFactory("CityComponents");
  const CityBlueprints = await ethers.getContractFactory("CityBlueprints");
  const CityEnchantments = await ethers.getContractFactory("CityEnchantments");
  const CityEnchantmentItems = await ethers.getContractFactory("CityEnchantmentItems");
  const CityMateria = await ethers.getContractFactory("CityMateria");
  const CityMateriaItems = await ethers.getContractFactory("CityMateriaItems");
  const CityWeapons = await ethers.getContractFactory("CityWeapons");
  const CityWeaponSockets = await ethers.getContractFactory("CityWeaponSockets");
  const CityCrafting = await ethers.getContractFactory("CityCrafting");
  const CityEnchanting = await ethers.getContractFactory("CityEnchanting");
  const CityMateriaSystem = await ethers.getContractFactory("CityMateriaSystem");

  const { address: cityComponents } = await deployWithNonce(
    "CityComponents",
    CityComponents,
    [deployer.address, componentsBaseUri],
    nonceRef
  );

  const { address: cityBlueprints } = await deployWithNonce(
    "CityBlueprints",
    CityBlueprints,
    [deployer.address, blueprintsBaseUri],
    nonceRef
  );

  const { address: cityEnchantments } = await deployWithNonce(
    "CityEnchantments",
    CityEnchantments,
    [deployer.address],
    nonceRef
  );

  const { address: cityEnchantmentItems } = await deployWithNonce(
    "CityEnchantmentItems",
    CityEnchantmentItems,
    [deployer.address, cityEnchantments, enchantmentItemsBaseUri],
    nonceRef
  );

  const { address: cityMateria } = await deployWithNonce(
    "CityMateria",
    CityMateria,
    [deployer.address],
    nonceRef
  );

  const { address: cityMateriaItems } = await deployWithNonce(
    "CityMateriaItems",
    CityMateriaItems,
    [deployer.address, cityMateria, materiaItemsBaseUri],
    nonceRef
  );

  const { address: cityWeapons } = await deployWithNonce(
    "CityWeapons",
    CityWeapons,
    [deployer.address],
    nonceRef
  );

  const { address: cityWeaponSockets } = await deployWithNonce(
    "CityWeaponSockets",
    CityWeaponSockets,
    [deployer.address, cityWeapons, cityEnchantments, cityMateria],
    nonceRef
  );

  const { address: cityCrafting } = await deployWithNonce(
    "CityCrafting",
    CityCrafting,
    [deployer.address, cityConfigAddress],
    nonceRef
  );

  const { address: cityEnchanting } = await deployWithNonce(
    "CityEnchanting",
    CityEnchanting,
    [deployer.address, cityWeapons, cityWeaponSockets, cityEnchantmentItems],
    nonceRef
  );

  const { address: cityMateriaSystem } = await deployWithNonce(
    "CityMateriaSystem",
    CityMateriaSystem,
    [deployer.address, cityWeapons, cityWeaponSockets, cityMateriaItems],
    nonceRef
  );

  const merged = {
    ...existing,
    chainId: Number(net.chainId),
    deployer: deployer.address,

    cityComponents,
    cityBlueprints,
    cityEnchantments,
    cityEnchantmentItems,
    cityMateria,
    cityMateriaItems,
    cityWeapons,
    cityWeaponSockets,
    cityCrafting,
    cityEnchanting,
    cityMateriaSystem,

    craftingBaseUris: {
      components: componentsBaseUri,
      blueprints: blueprintsBaseUri,
      enchantmentItems: enchantmentItemsBaseUri,
      materiaItems: materiaItemsBaseUri
    },

    updatedAt: new Date().toISOString()
  };

  saveJson(coreFile, merged);

  console.log("========================================");
  console.log("Crafting-Stack fertig deployed.");
  console.log("JSON aktualisiert:", coreFile);
  console.log("========================================");
}

main().catch((error) => {
  console.error("Fehler in 10_deploy_crafting.js");
  console.error(error);
  process.exitCode = 1;
});