import { ethers } from "hardhat";
import dotenv from "dotenv";

dotenv.config();

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Wiring core contracts with:", deployer.address);

  const CITY_REGISTRY_ADDRESS = process.env.CITY_REGISTRY_ADDRESS;
  const CITY_HISTORY_ADDRESS = process.env.CITY_HISTORY_ADDRESS;
  const CITY_STATUS_ADDRESS = process.env.CITY_STATUS_ADDRESS;
  const CITY_LAND_ADDRESS = process.env.CITY_LAND_ADDRESS;
  const CITY_DISTRICTS_ADDRESS = process.env.CITY_DISTRICTS_ADDRESS;

  if (
    !CITY_REGISTRY_ADDRESS ||
    !CITY_HISTORY_ADDRESS ||
    !CITY_STATUS_ADDRESS ||
    !CITY_LAND_ADDRESS ||
    !CITY_DISTRICTS_ADDRESS
  ) {
    throw new Error("Missing one or more CITY_*_ADDRESS values in .env");
  }

  const registry = await ethers.getContractAt("CityRegistry", CITY_REGISTRY_ADDRESS);
  const history = await ethers.getContractAt("CityHistory", CITY_HISTORY_ADDRESS);
  const status = await ethers.getContractAt("CityStatus", CITY_STATUS_ADDRESS);
  const land = await ethers.getContractAt("CityLand", CITY_LAND_ADDRESS);
  const districts = await ethers.getContractAt("CityDistricts", CITY_DISTRICTS_ADDRESS);

  console.log("1) Setting hooks in CityRegistry...");
  await (await registry.setCityHistory(CITY_HISTORY_ADDRESS)).wait();
  await (await registry.setCityDistricts(CITY_DISTRICTS_ADDRESS)).wait();

  console.log("2) Setting hooks in CityLand...");
  await (await land.setHooks(CITY_STATUS_ADDRESS, CITY_HISTORY_ADDRESS)).wait();

  console.log("3) Authorizing Registry + Land in CityHistory...");
  await (await history.setAuthorizedCaller(CITY_REGISTRY_ADDRESS, true)).wait();
  await (await history.setAuthorizedCaller(CITY_LAND_ADDRESS, true)).wait();

  console.log("4) Authorizing Land in CityStatus...");
  await (await status.setAuthorizedCaller(CITY_LAND_ADDRESS, true)).wait();

  console.log("5) Authorizing Registry in CityDistricts...");
  await (await districts.setAuthorizedCaller(CITY_REGISTRY_ADDRESS, true)).wait();

  console.log("Core wiring completed.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});