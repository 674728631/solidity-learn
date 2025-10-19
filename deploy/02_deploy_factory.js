const { deployments, ethers, upgrades } = require("hardhat");
const fs = require("fs");
const path = require("path");
const { json } = require("stream/consumers");

module.exports = async ({ getNamedAccounts, deployments }) => {

  const { save } = deployments;

  const { deployer } = await getNamedAccounts();

  const AuctionFactory = await ethers.getContractFactory("AuctionFactory");

  // 通过代理合约部署
  const auctionFactoryProxy = await upgrades.deployProxy(AuctionFactory, [], {
    initializer: "initialize",
    kind: "uups"
  });

  // 等待部署完成
  await auctionFactoryProxy.waitForDeployment();

  const proxyAddress = await auctionFactoryProxy.target;
  console.log("代理工厂合约地址:", proxyAddress);
  const implAddress = await upgrades.erc1967.getImplementationAddress(
    proxyAddress
  );
  console.log(
    "工厂实现合约地址:",
    await upgrades.erc1967.getImplementationAddress(proxyAddress)
  );

  // 保存json文件
  const deploymentsDir = path.join(
    __dirname,
    "./.cache",
    "proxyAuctionFactory.json"
  );

  fs.writeFileSync(
    deploymentsDir,
    JSON.stringify({
      proxyAddress,
      implAddress,
      abi: AuctionFactory.interface.format("json"),
    })
  );

  await save("AuctionFactoryProxy", {
    address: proxyAddress,
    abi: AuctionFactory.interface.format("json"),
    args: [],
    log: true,
  });
};

module.exports.tags = ["deployAuctionFactory"];
