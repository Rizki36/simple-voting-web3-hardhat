import type { HardhatUserConfig } from "hardhat/config";
import '@typechain/hardhat'
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-toolbox-viem";
import "@nomicfoundation/hardhat-chai-matchers";
import "@nomicfoundation/hardhat-verify";

require("dotenv").config();

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  typechain: {
    outDir: "typechain-types",
    target: "ethers-v6",
  },
  networks: {
    sepolia: {
      url: `https://sepolia.infura.io/v3/${process.env.INFURA_API_KEY!}`,
      accounts: [process.env.SEPOLIA_PRIVATE_KEY!],
    }
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: process.env.ETHERSCAN_API_KEY!
  },
  sourcify: {
    // Disabled by default
    // Doesn't need an API key
    enabled: true
  }
};

export default config;
