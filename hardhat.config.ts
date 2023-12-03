import * as dotenv from "dotenv";

import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
// import "@nomicfoundation/hardhat-foundry";

require("hardhat-contract-sizer"); // "npx hardhat size-contracts" or "yarn run hardhat size-contracts"

dotenv.config();

import "./tasks/swap-amounts";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      remappings: [
        "ds-test/=lib/forge-std/lib/ds-test/src/",
        "eth-gas-reporter/=eth-gas-reporter/",
        "forge-std/=lib/forge-std/src/",
        "hardhat/=hardhat/",
      ]
    },
  },
  networks: {
    arbitrumGoerli: {
      url: `https://arb-goerli.g.alchemy.com/v2/${process.env.ALCHEMY_ARBITRUM_GOERLI_API_KEY}`,
      accounts: {
        mnemonic:
            process.env.ARBITRUM_GOERLI_MNEMONIC ||
            "female like problem scare over lizard client bonus pioneer submit myth collect",
        path: "m/44'/60'/0'/0",
      },
      chainId: 421613,
    },
    arbitrum: {
      url: `https://arb-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_ARBITRUM_API_KEY}`,
      accounts: {
        mnemonic:
            process.env.ARBITRUM_MNEMONIC ||
            "female like problem scare over lizard client bonus pioneer submit myth collect",
        path: "m/44'/60'/0'/0",
      },
      chainId: 42161,
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};

export default config;
