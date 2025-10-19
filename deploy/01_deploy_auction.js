const { deployments, ethers, upgrades } = require("hardhat");
const fs = require("fs");
const path = require("path");
const { json } = require("stream/consumers");

module.exports = async ({ getNamedAccounts, deployments }) => {

  const { save } = deployments;

  const { deployer } = await getNamedAccounts();

  const Auction = await ethers.getContractFactory("Auction");

  // 通过代理合约部署
  const auctionProxy = await upgrades.deployProxy(Auction, [deployer], {
    initializer: "initialize",
  });

  // 等待部署完成
  await auctionProxy.waitForDeployment();

  const proxyAddress = await auctionProxy.target;
  console.log("Auction代理合约地址:", proxyAddress);
  const implAddress = await upgrades.erc1967.getImplementationAddress(
    proxyAddress
  );
  console.log("Auction实现合约地址:", implAddress);

  // 保存json文件
  const deploymentsDir = path.join(
    __dirname,
    "./.cache",
    "proxyAuction.json"
  );

  fs.writeFileSync(
    deploymentsDir,
    JSON.stringify({
      proxyAddress,
      implAddress,
      abi: Auction.interface.format("json"),
    })
  );

  await save("AuctionProxy", {
    address: proxyAddress,
    abi: Auction.interface.format("json"),
    args: [],
    log: true,
  });
};

module.exports.tags = ["deployAuction"];
