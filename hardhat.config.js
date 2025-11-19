
const { deploy } = require("@openzeppelin/hardhat-upgrades/dist/utils");

require("@nomicfoundation/hardhat-toolbox");
require("hardhat-deploy");
require("@openzeppelin/hardhat-upgrades");
require("dotenv").config();
require("hardhat-coverage");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,  // 开启优化
        runs: 200,      // 优化迭代次数（默认200，调试时可设为1）
      },
    },
  },
  namedAccounts: {
    deployer: 0,
    user1: 1,
    user2: 2,
    user3: 3,
  },
  networks: {
    hardhat: {
      mining: {
        auto: true, // 确保自动挖矿开启
      },
    },
  },
};
