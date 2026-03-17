import { network } from "hardhat";
import fs from "fs";
import path from "path";

function loadJson(filePath) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`Datei nicht gefunden: ${filePath}`);
  }
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

const ERC1155_APPROVAL_ABI = [
  "function setApprovalForAll(address operator, bool approved) external",
  "function isApprovedForAll(address account, address operator) external view returns (bool)",
  "function balanceOf(address account, uint256 id) external view returns (uint256)"
];

const CITY_COMPONENTS_ABI = [
  "function balanceOf(address account, uint256 id) external view returns (uint256)"
];

const CITY_CRAFTING_ABI = [
  "function craft(uint256 recipeId) external",
  "function getRecipeCosts(uint256 recipeId) external view returns (uint256[10] memory)"
];

async function main() {
  const { ethers } = await network.connect();
  const [deployer] = await ethers.getSigners();
  const net = await ethers.provider.getNetwork();

  console.log("========================================");
  console.log("19_test_component_craft.js");
  console.log("Deployer:", deployer.address);
  console.log("Chain ID:", Number(net.chainId));
  console.log("========================================");

  const coreFile = path.resolve("deployments", "city-core.json");
  const d = loadJson(coreFile);

  const cityCraftingAddress = d.cityCrafting || process.env.CITY_CRAFTING_ADDRESS;
  const cityComponentsAddress = d.cityComponents || process.env.CITY_COMPONENTS_ADDRESS;
  const resourceTokenAddress =
    (d.addresses && d.addresses.resourceToken) || process.env.RESOURCE_TOKEN_ADDRESS;
  const treasuryAddress =
    (d.addresses && d.addresses.treasury) || process.env.TREASURY_ADDRESS;

  if (!cityCraftingAddress) throw new Error("cityCrafting Adresse fehlt");
  if (!cityComponentsAddress) throw new Error("cityComponents Adresse fehlt");
  if (!resourceTokenAddress) throw new Error("RESOURCE_TOKEN_ADDRESS fehlt");
  if (!treasuryAddress) throw new Error("TREASURY_ADDRESS fehlt");

  const recipeId = 1;      // Iron Blade Recipe
  const componentId = 1;   // Iron Blade Component

  const resourceToken = new ethers.Contract(
    resourceTokenAddress,
    ERC1155_APPROVAL_ABI,
    deployer
  );

  const cityComponents = new ethers.Contract(
    cityComponentsAddress,
    CITY_COMPONENTS_ABI,
    deployer
  );

  const cityCrafting = new ethers.Contract(
    cityCraftingAddress,
    CITY_CRAFTING_ABI,
    deployer
  );

  console.log("CityCrafting:", cityCraftingAddress);
  console.log("CityComponents:", cityComponentsAddress);
  console.log("ResourceToken:", resourceTokenAddress);
  console.log("Treasury:", treasuryAddress);
  console.log("Recipe ID:", recipeId);
  console.log("Component ID:", componentId);

  const recipeCosts = await cityCrafting.getRecipeCosts(recipeId);
  console.log("Recipe Costs [OIL, LEMONS, IRON, GOLD, PLATINUM, COPPER, CRYSTAL, OBSIDIAN, MYSTERIUM, AETHER]:");
  console.log(recipeCosts.map((x) => x.toString()));

  const isApproved = await resourceToken.isApprovedForAll(deployer.address, cityCraftingAddress);
  console.log("Approval vorhanden:", isApproved);

  if (!isApproved) {
    console.log("Setze ApprovalForAll für CityCrafting...");
    const tx = await resourceToken.setApprovalForAll(cityCraftingAddress, true);
    console.log("setApprovalForAll tx:", tx.hash);
    await tx.wait();
    await sleep(1500);
  }

  const beforeUserOil = await resourceToken.balanceOf(deployer.address, 0);
  const beforeUserIron = await resourceToken.balanceOf(deployer.address, 2);
  const beforeTreasuryOil = await resourceToken.balanceOf(treasuryAddress, 0);
  const beforeTreasuryIron = await resourceToken.balanceOf(treasuryAddress, 2);
  const beforeComponent = await cityComponents.balanceOf(deployer.address, componentId);

  console.log("----- BEFORE -----");
  console.log("User OIL:", beforeUserOil.toString());
  console.log("User IRON:", beforeUserIron.toString());
  console.log("Treasury OIL:", beforeTreasuryOil.toString());
  console.log("Treasury IRON:", beforeTreasuryIron.toString());
  console.log("User Component #1:", beforeComponent.toString());

  console.log("Starte craft(recipeId=1)...");
  const craftTx = await cityCrafting.craft(recipeId);
  console.log("craft tx:", craftTx.hash);
  const receipt = await craftTx.wait();
  await sleep(1500);

  console.log("Craft bestätigt in Block:", receipt.blockNumber);

  const afterUserOil = await resourceToken.balanceOf(deployer.address, 0);
  const afterUserIron = await resourceToken.balanceOf(deployer.address, 2);
  const afterTreasuryOil = await resourceToken.balanceOf(treasuryAddress, 0);
  const afterTreasuryIron = await resourceToken.balanceOf(treasuryAddress, 2);
  const afterComponent = await cityComponents.balanceOf(deployer.address, componentId);

  console.log("----- AFTER -----");
  console.log("User OIL:", afterUserOil.toString());
  console.log("User IRON:", afterUserIron.toString());
  console.log("Treasury OIL:", afterTreasuryOil.toString());
  console.log("Treasury IRON:", afterTreasuryIron.toString());
  console.log("User Component #1:", afterComponent.toString());

  console.log("----- DELTA -----");
  console.log("User OIL delta:", (afterUserOil - beforeUserOil).toString());
  console.log("User IRON delta:", (afterUserIron - beforeUserIron).toString());
  console.log("Treasury OIL delta:", (afterTreasuryOil - beforeTreasuryOil).toString());
  console.log("Treasury IRON delta:", (afterTreasuryIron - beforeTreasuryIron).toString());
  console.log("Component delta:", (afterComponent - beforeComponent).toString());

  console.log("========================================");
  console.log("Component-Craft-Test abgeschlossen.");
  console.log("========================================");
}

main().catch((error) => {
  console.error("Fehler in 19_test_component_craft.js");
  console.error(error);
  process.exitCode = 1;
});