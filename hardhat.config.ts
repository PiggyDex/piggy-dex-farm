import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";
dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  networks: {
    conflux: {
      url: process.env.RPC_URL || "https://evmtestnet.confluxrpc.com",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
  },
  sourcify: {
    enabled: false,
  },
  etherscan: {
    apiKey: {
      conflux: process.env.API_KEY || "everything_is_ok",
    },
    customChains: [
      {
        network: "conflux",
        chainId: process.env.CHAIN_ID !== undefined ? parseInt(process.env.CHAIN_ID) : 71,
        urls: {
          apiURL: process.env.API_URL || "https://evmapi-testnet.confluxscan.io/api/",
          browserURL: process.env.BROWSER_URL || "https://evmtestnet.confluxscan.io/",
        },
      },
    ],
  },
};

export default config;