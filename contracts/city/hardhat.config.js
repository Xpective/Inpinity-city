import { defineConfig } from "hardhat/config";
import hardhatToolboxMochaEthers from "@nomicfoundation/hardhat-toolbox-mocha-ethers";
import dotenv from "dotenv";

dotenv.config();

const config = {
  plugins: [hardhatToolboxMochaEthers],

  solidity: {
    profiles: {
      default: {
        version: "0.8.24",
        settings: {
          viaIR: true,
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    },
  },

  networks: {
    base: {
      type: "http",
      chainType: "l1",
      url: process.env.BASE_MAINNET_RPC || "https://mainnet.base.org",
      accounts: process.env.BASE_MAINNET_PRIVATE_KEY
        ? [process.env.BASE_MAINNET_PRIVATE_KEY]
        : [],
    },
  },

  etherscan: {
    apiKey: {
      base: process.env.BASESCAN_API_KEY || "",
    },
  },

  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
};

if (process.env.BASE_SEPOLIA_RPC_URL) {
  config.networks.baseSepolia = {
    type: "http",
    chainType: "l1",
    url: process.env.BASE_SEPOLIA_RPC_URL,
    accounts: process.env.BASE_SEPOLIA_PRIVATE_KEY
      ? [process.env.BASE_SEPOLIA_PRIVATE_KEY]
      : [],
  };

  config.etherscan.apiKey.baseSepolia = process.env.BASESCAN_API_KEY || "";
}

export default defineConfig(config);