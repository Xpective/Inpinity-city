import { ethers } from "hardhat";
import fs from "fs";
import path from "path";

function saveJson(filePath, data) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
}

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);

  const outDir = path.resolve("deployments");
  const outFile = path.join(outDir, "city-crafting-stack.json");

  const metadataBase = "https://inpinity.online/city/metadata/";
  const componentsUri = `${metadataBase}components/`;
  const blueprintsUri = `${metadataBase}blueprints/`;
  const materiaItemsUri = `${metadataBase}materia-items/`;
  const enchantmentItemsUri = `${metadataBase}enchantment-items/`;

  // 1) CityWeapons
  const CityWeapons = await ethers.getContractFactory("CityWeapons");
  const cityWeapons = await CityWeapons.deploy(deployer.address);
  await cityWeapons.waitForDeployment();
  console.log("CityWeapons:", await cityWeapons.getAddress());

  // 2) CityComponents
  const CityComponents = await ethers.getContractFactory("CityComponents");
  const cityComponents = await CityComponents.deploy(
    deployer.address,
    componentsUri
  );
  await cityComponents.waitForDeployment();
  console.log("CityComponents:", await cityComponents.getAddress());

  // 3) CityBlueprints
  const CityBlueprints = await ethers.getContractFactory("CityBlueprints");
  const cityBlueprints = await CityBlueprints.deploy(
    deployer.address,
    blueprintsUri
  );
  await cityBlueprints.waitForDeployment();
  console.log("CityBlueprints:", await cityBlueprints.getAddress());

  // 4) CityEnchantments
  const CityEnchantments = await ethers.getContractFactory("CityEnchantments");
  const cityEnchantments = await CityEnchantments.deploy(deployer.address);
  await cityEnchantments.waitForDeployment();
  console.log("CityEnchantments:", await cityEnchantments.getAddress());

  // 5) CityEnchantmentItems
  const CityEnchantmentItems = await ethers.getContractFactory("CityEnchantmentItems");
  const cityEnchantmentItems = await CityEnchantmentItems.deploy(
    deployer.address,
    await cityEnchantments.getAddress(),
    enchantmentItemsUri
  );
  await cityEnchantmentItems.waitForDeployment();
  console.log("CityEnchantmentItems:", await cityEnchantmentItems.getAddress());

  // 6) CityMateria
  const CityMateria = await ethers.getContractFactory("CityMateria");
  const cityMateria = await CityMateria.deploy(deployer.address);
  await cityMateria.waitForDeployment();
  console.log("CityMateria:", await cityMateria.getAddress());

  // 7) CityMateriaItems
  const CityMateriaItems = await ethers.getContractFactory("CityMateriaItems");
  const cityMateriaItems = await CityMateriaItems.deploy(
    deployer.address,
    await cityMateria.getAddress(),
    materiaItemsUri
  );
  await cityMateriaItems.waitForDeployment();
  console.log("CityMateriaItems:", await cityMateriaItems.getAddress());

  // 8) CityWeaponSockets
  const CityWeaponSockets = await ethers.getContractFactory("CityWeaponSockets");
  const cityWeaponSockets = await CityWeaponSockets.deploy(
    deployer.address,
    await cityWeapons.getAddress(),
    await cityEnchantments.getAddress(),
    await cityMateria.getAddress()
  );
  await cityWeaponSockets.waitForDeployment();
  console.log("CityWeaponSockets:", await cityWeaponSockets.getAddress());

  // 9) CityEnchanting
  const CityEnchanting = await ethers.getContractFactory("CityEnchanting");
  const cityEnchanting = await CityEnchanting.deploy(
    deployer.address,
    await cityWeapons.getAddress(),
    await cityWeaponSockets.getAddress(),
    await cityEnchantmentItems.getAddress()
  );
  await cityEnchanting.waitForDeployment();
  console.log("CityEnchanting:", await cityEnchanting.getAddress());

  // 10) CityMateriaSystem
  const CityMateriaSystem = await ethers.getContractFactory("CityMateriaSystem");
  const cityMateriaSystem = await CityMateriaSystem.deploy(
    deployer.address,
    await cityWeapons.getAddress(),
    await cityWeaponSockets.getAddress(),
    await cityMateriaItems.getAddress()
  );
  await cityMateriaSystem.waitForDeployment();
  console.log("CityMateriaSystem:", await cityMateriaSystem.getAddress());

  // 11) CityCrafting
  const CityCrafting = await ethers.getContractFactory("CityCrafting");
  const cityCrafting = await CityCrafting.deploy(
    deployer.address,
    process.env.CITY_CONFIG_ADDRESS
  );
  await cityCrafting.waitForDeployment();
  console.log("CityCrafting:", await cityCrafting.getAddress());

  const deployment = {
    network: (await ethers.provider.getNetwork()).name,
    chainId: Number((await ethers.provider.getNetwork()).chainId),
    deployer: deployer.address,
    cityWeapons: await cityWeapons.getAddress(),
    cityComponents: await cityComponents.getAddress(),
    cityBlueprints: await cityBlueprints.getAddress(),
    cityEnchantments: await cityEnchantments.getAddress(),
    cityEnchantmentItems: await cityEnchantmentItems.getAddress(),
    cityEnchanting: await cityEnchanting.getAddress(),
    cityMateria: await cityMateria.getAddress(),
    cityMateriaItems: await cityMateriaItems.getAddress(),
    cityMateriaSystem: await cityMateriaSystem.getAddress(),
    cityWeaponSockets: await cityWeaponSockets.getAddress(),
    cityCrafting: await cityCrafting.getAddress(),
    cityConfig: process.env.CITY_CONFIG_ADDRESS,
    metadata: {
      componentsUri,
      blueprintsUri,
      materiaItemsUri,
      enchantmentItemsUri
    },
    deployedAt: new Date().toISOString()
  };

  saveJson(outFile, deployment);
  console.log(`Saved deployment file: ${outFile}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});