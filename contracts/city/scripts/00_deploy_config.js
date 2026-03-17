import { network } from "hardhat";
import fs from "fs";
import path from "path";

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function ensureEnv(name) {
  const value = process.env[name];
  if (!value || value.trim() === "") {
    throw new Error(`Fehlende ENV-Variable: ${name}`);
  }
  return value.trim();
}

function getOptionalEnv(name, fallback = "") {
  const value = process.env[name];
  return value && value.trim() !== "" ? value.trim() : fallback;
}

function saveJson(filePath, data) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
}

async function sendAndWait(txPromise, label, delay = 1200) {
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
  console.log("00_deploy_config.js");
  console.log("Deployer:", deployer.address);
  console.log("Chain ID:", Number(net.chainId));
  console.log("========================================");

  const nftAddress = ensureEnv("INPINITY_NFT_ADDRESS");
  const resourceTokenAddress = ensureEnv("RESOURCE_TOKEN_ADDRESS");
  const farmingAddress = ensureEnv("FARMING_V6_ADDRESS");
  const piratesAddress = ensureEnv("PIRATES_V6_ADDRESS");
  const mercenaryAddress = ensureEnv("MERCENARY_V4_ADDRESS");
  const partnershipAddress = ensureEnv("PARTNERSHIP_V2_ADDRESS");
  const inpiAddress = ensureEnv("INPI_ADDRESS");
  const pitroneAddress = ensureEnv("PITRONE_ADDRESS");
  const treasuryAddress = ensureEnv("TREASURY_ADDRESS");

  const maxPersonalPlots = Number(ensureEnv("CITY_MAX_PERSONAL_PLOTS"));
  const inactivityDays = Number(ensureEnv("CITY_INACTIVITY_THRESHOLD_DAYS"));
  const dormantDays = Number(ensureEnv("DORMANT_THRESHOLD_DAYS"));
  const decayedDays = Number(ensureEnv("DECAYED_THRESHOLD_DAYS"));
  const layerEligibleDays = Number(ensureEnv("LAYER_ELIGIBLE_THRESHOLD_DAYS"));

  const personalWidth = Number(ensureEnv("CITY_PERSONAL_PLOT_QUBIQ_WIDTH"));
  const personalHeight = Number(ensureEnv("CITY_PERSONAL_PLOT_QUBIQ_HEIGHT"));
  const communityWidth = Number(ensureEnv("CITY_COMMUNITY_PLOT_QUBIQ_WIDTH"));
  const communityHeight = Number(ensureEnv("CITY_COMMUNITY_PLOT_QUBIQ_HEIGHT"));

  const qubiqOilCost = Number(ensureEnv("CITY_QUBIQ_OIL_COST"));
  const qubiqLemonsCost = Number(ensureEnv("CITY_QUBIQ_LEMONS_COST"));
  const qubiqIronCost = Number(ensureEnv("CITY_QUBIQ_IRON_COST"));

  const buildingOilCost = Number(ensureEnv("CITY_BUILDING_OIL_COST"));
  const buildingLemonsCost = Number(ensureEnv("CITY_BUILDING_LEMONS_COST"));
  const buildingIronCost = Number(ensureEnv("CITY_BUILDING_IRON_COST"));
  const buildingGoldCost = Number(ensureEnv("CITY_BUILDING_GOLD_COST"));

  const initialFeeBps = Number(ensureEnv("CITY_CONFIG_INITIAL_FEE_BPS"));

  let nextNonce = await ethers.provider.getTransactionCount(deployer.address, "pending");
  console.log("Start nonce:", nextNonce);

  const CityConfig = await ethers.getContractFactory("CityConfig");
  const cityConfig = await CityConfig.deploy(deployer.address, {
    nonce: nextNonce++
  });
  await cityConfig.waitForDeployment();

  const cityConfigAddress = await cityConfig.getAddress();
  console.log("CityConfig deployed:", cityConfigAddress);

  await sleep(2500);

  console.log("Setze Adress-Konfigurationen ...");

  await sendAndWait(
    cityConfig.setAddressConfig(await cityConfig.KEY_INPINITY_NFT(), nftAddress, { nonce: nextNonce++ }),
    "KEY_INPINITY_NFT"
  );

  await sendAndWait(
    cityConfig.setAddressConfig(await cityConfig.KEY_RESOURCE_TOKEN(), resourceTokenAddress, { nonce: nextNonce++ }),
    "KEY_RESOURCE_TOKEN"
  );

  await sendAndWait(
    cityConfig.setAddressConfig(await cityConfig.KEY_FARMING(), farmingAddress, { nonce: nextNonce++ }),
    "KEY_FARMING"
  );

  await sendAndWait(
    cityConfig.setAddressConfig(await cityConfig.KEY_PIRATES(), piratesAddress, { nonce: nextNonce++ }),
    "KEY_PIRATES"
  );

  await sendAndWait(
    cityConfig.setAddressConfig(await cityConfig.KEY_MERCENARY(), mercenaryAddress, { nonce: nextNonce++ }),
    "KEY_MERCENARY"
  );

  await sendAndWait(
    cityConfig.setAddressConfig(await cityConfig.KEY_PARTNERSHIP(), partnershipAddress, { nonce: nextNonce++ }),
    "KEY_PARTNERSHIP"
  );

  await sendAndWait(
    cityConfig.setAddressConfig(await cityConfig.KEY_INPI(), inpiAddress, { nonce: nextNonce++ }),
    "KEY_INPI"
  );

  await sendAndWait(
    cityConfig.setAddressConfig(await cityConfig.KEY_PITRONE(), pitroneAddress, { nonce: nextNonce++ }),
    "KEY_PITRONE"
  );

  await sendAndWait(
    cityConfig.setAddressConfig(await cityConfig.KEY_TREASURY(), treasuryAddress, { nonce: nextNonce++ }),
    "KEY_TREASURY"
  );

  console.log("Setze Uint-Konfigurationen ...");

  await sendAndWait(
    cityConfig.setUintConfig(await cityConfig.KEY_MAX_PERSONAL_PLOTS(), maxPersonalPlots, { nonce: nextNonce++ }),
    "KEY_MAX_PERSONAL_PLOTS"
  );

  await sendAndWait(
    cityConfig.setUintConfig(await cityConfig.KEY_INACTIVITY_DAYS(), inactivityDays, { nonce: nextNonce++ }),
    "KEY_INACTIVITY_DAYS"
  );

  await sendAndWait(
    cityConfig.setUintConfig(await cityConfig.KEY_DORMANT_THRESHOLD_DAYS(), dormantDays, { nonce: nextNonce++ }),
    "KEY_DORMANT_THRESHOLD_DAYS"
  );

  await sendAndWait(
    cityConfig.setUintConfig(await cityConfig.KEY_DECAYED_THRESHOLD_DAYS(), decayedDays, { nonce: nextNonce++ }),
    "KEY_DECAYED_THRESHOLD_DAYS"
  );

  await sendAndWait(
    cityConfig.setUintConfig(await cityConfig.KEY_LAYER_ELIGIBLE_THRESHOLD_DAYS(), layerEligibleDays, { nonce: nextNonce++ }),
    "KEY_LAYER_ELIGIBLE_THRESHOLD_DAYS"
  );

  await sendAndWait(
    cityConfig.setUintConfig(await cityConfig.KEY_PERSONAL_WIDTH(), personalWidth, { nonce: nextNonce++ }),
    "KEY_PERSONAL_WIDTH"
  );

  await sendAndWait(
    cityConfig.setUintConfig(await cityConfig.KEY_PERSONAL_HEIGHT(), personalHeight, { nonce: nextNonce++ }),
    "KEY_PERSONAL_HEIGHT"
  );

  await sendAndWait(
    cityConfig.setUintConfig(await cityConfig.KEY_COMMUNITY_WIDTH(), communityWidth, { nonce: nextNonce++ }),
    "KEY_COMMUNITY_WIDTH"
  );

  await sendAndWait(
    cityConfig.setUintConfig(await cityConfig.KEY_COMMUNITY_HEIGHT(), communityHeight, { nonce: nextNonce++ }),
    "KEY_COMMUNITY_HEIGHT"
  );

  await sendAndWait(
    cityConfig.setUintConfig(await cityConfig.KEY_QUBIQ_OIL_COST(), qubiqOilCost, { nonce: nextNonce++ }),
    "KEY_QUBIQ_OIL_COST"
  );

  await sendAndWait(
    cityConfig.setUintConfig(await cityConfig.KEY_QUBIQ_LEMONS_COST(), qubiqLemonsCost, { nonce: nextNonce++ }),
    "KEY_QUBIQ_LEMONS_COST"
  );

  await sendAndWait(
    cityConfig.setUintConfig(await cityConfig.KEY_QUBIQ_IRON_COST(), qubiqIronCost, { nonce: nextNonce++ }),
    "KEY_QUBIQ_IRON_COST"
  );

  await sendAndWait(
    cityConfig.setUintConfig(await cityConfig.KEY_BUILDING_OIL_COST(), buildingOilCost, { nonce: nextNonce++ }),
    "KEY_BUILDING_OIL_COST"
  );

  await sendAndWait(
    cityConfig.setUintConfig(await cityConfig.KEY_BUILDING_LEMONS_COST(), buildingLemonsCost, { nonce: nextNonce++ }),
    "KEY_BUILDING_LEMONS_COST"
  );

  await sendAndWait(
    cityConfig.setUintConfig(await cityConfig.KEY_BUILDING_IRON_COST(), buildingIronCost, { nonce: nextNonce++ }),
    "KEY_BUILDING_IRON_COST"
  );

  await sendAndWait(
    cityConfig.setUintConfig(await cityConfig.KEY_BUILDING_GOLD_COST(), buildingGoldCost, { nonce: nextNonce++ }),
    "KEY_BUILDING_GOLD_COST"
  );

  await sendAndWait(
    cityConfig.setUintConfig(await cityConfig.KEY_INITIAL_FEE_BPS(), initialFeeBps, { nonce: nextNonce++ }),
    "KEY_INITIAL_FEE_BPS"
  );

  const deploymentDir = path.resolve("deployments");
  const coreFile = path.join(deploymentDir, "city-core.json");

  const existing = fs.existsSync(coreFile)
    ? JSON.parse(fs.readFileSync(coreFile, "utf8"))
    : {};

  const merged = {
    ...existing,
    network: getOptionalEnv("HARDHAT_NETWORK", "base"),
    chainId: Number(net.chainId),
    deployer: deployer.address,
    cityConfig: cityConfigAddress,
    addresses: {
      inpinityNft: nftAddress,
      resourceToken: resourceTokenAddress,
      farming: farmingAddress,
      pirates: piratesAddress,
      mercenary: mercenaryAddress,
      partnership: partnershipAddress,
      inpi: inpiAddress,
      pitrone: pitroneAddress,
      treasury: treasuryAddress
    },
    uintConfig: {
      maxPersonalPlots,
      inactivityDays,
      dormantDays,
      decayedDays,
      layerEligibleDays,
      personalWidth,
      personalHeight,
      communityWidth,
      communityHeight,
      qubiqOilCost,
      qubiqLemonsCost,
      qubiqIronCost,
      buildingOilCost,
      buildingLemonsCost,
      buildingIronCost,
      buildingGoldCost,
      initialFeeBps
    },
    updatedAt: new Date().toISOString()
  };

  saveJson(coreFile, merged);

  console.log("========================================");
  console.log("CityConfig fertig.");
  console.log("JSON gespeichert:", coreFile);
  console.log("========================================");
}

main().catch((error) => {
  console.error("Fehler in 00_deploy_config.js");
  console.error(error);
  process.exitCode = 1;
});