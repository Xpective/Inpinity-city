import { ethers } from "hardhat";
import fs from "fs";
import path from "path";

function loadJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

async function main() {
  const deploymentsPath = path.resolve("deployments", "city-crafting-stack.json");
  const deployed = loadJson(deploymentsPath);

  const [deployer] = await ethers.getSigners();
  console.log("Wiring with:", deployer.address);

  const cityWeapons = await ethers.getContractAt("CityWeapons", deployed.cityWeapons);
  const cityComponents = await ethers.getContractAt("CityComponents", deployed.cityComponents);
  const cityBlueprints = await ethers.getContractAt("CityBlueprints", deployed.cityBlueprints);
  const cityEnchantments = await ethers.getContractAt("CityEnchantments", deployed.cityEnchantments);
  const cityEnchantmentItems = await ethers.getContractAt("CityEnchantmentItems", deployed.cityEnchantmentItems);
  const cityEnchanting = await ethers.getContractAt("CityEnchanting", deployed.cityEnchanting);
  const cityMateria = await ethers.getContractAt("CityMateria", deployed.cityMateria);
  const cityMateriaItems = await ethers.getContractAt("CityMateriaItems", deployed.cityMateriaItems);
  const cityMateriaSystem = await ethers.getContractAt("CityMateriaSystem", deployed.cityMateriaSystem);
  const cityWeaponSockets = await ethers.getContractAt("CityWeaponSockets", deployed.cityWeaponSockets);
  const cityCrafting = await ethers.getContractAt("CityCrafting", deployed.cityCrafting);

  // CityWeapons
  console.log("Set CityWeapons -> WeaponSockets");
  await (await cityWeapons.setWeaponSockets(deployed.cityWeaponSockets)).wait();

  console.log("Set CityWeapons -> authorized minter CityCrafting");
  await (await cityWeapons.setAuthorizedMinter(deployed.cityCrafting, true)).wait();

  // CityComponents
  console.log("Set CityComponents -> authorized minter CityCrafting");
  await (await cityComponents.setAuthorizedMinter(deployed.cityCrafting, true)).wait();

  // CityBlueprints
  console.log("Set CityBlueprints -> authorized minter CityCrafting");
  await (await cityBlueprints.setAuthorizedMinter(deployed.cityCrafting, true)).wait();

  // CityCrafting
  console.log("Set CityCrafting -> CityWeapons");
  await (await cityCrafting.setCityWeapons(deployed.cityWeapons)).wait();

  console.log("Set CityCrafting -> CityComponents");
  await (await cityCrafting.setCityComponents(deployed.cityComponents)).wait();

  console.log("Set CityCrafting -> CityBlueprints");
  await (await cityCrafting.setCityBlueprints(deployed.cityBlueprints)).wait();

  // Enchantment wiring
  console.log("Set CityEnchantmentItems -> authorized consumer CityEnchanting");
  await (await cityEnchantmentItems.setAuthorizedConsumer(deployed.cityEnchanting, true)).wait();

  console.log("Set CityWeaponSockets -> authorized caller CityEnchanting");
  await (await cityWeaponSockets.setAuthorizedCaller(deployed.cityEnchanting, true)).wait();

  // Materia wiring
  console.log("Set CityMateriaItems -> authorized consumer CityMateriaSystem");
  await (await cityMateriaItems.setAuthorizedConsumer(deployed.cityMateriaSystem, true)).wait();

  console.log("Set CityWeaponSockets -> authorized caller CityMateriaSystem");
  await (await cityWeaponSockets.setAuthorizedCaller(deployed.cityMateriaSystem, true)).wait();

  // Optional: definitions admin remains owner for now
  console.log("Crafting stack wiring complete.");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});