import * as dotenv from "dotenv";

import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
// import "@nomicfoundation/hardhat-foundry";

require("hardhat-contract-sizer"); // "npx hardhat size-contracts" or "yarn run hardhat size-contracts"

dotenv.config();

import "./tasks/swap-amounts";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.21",
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
};

export default config;
