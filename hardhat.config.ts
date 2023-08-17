import * as dotenv from "dotenv";

import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

require("hardhat-contract-sizer"); // "npx hardhat size-contracts" or "yarn run hardhat size-contracts"

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.6.6",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
};

export default config;
