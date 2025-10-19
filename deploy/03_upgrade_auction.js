const { ethers, upgrades } = require("hardhat");
const fs = require("fs");
const path = require("path");
const { json } = require("stream/consumers");

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { save } = deployments;
    const { deployer } = await getNamedAccounts();

    // 读取之前部署的代理合约地址
    const storePath = path.resolve(__dirname, "./.cache", "proxyAuction.json");
    const storeData = fs.readFileSync(storePath, "utf-8");
    const { proxyAddress, implAddress, abi } = JSON.parse(storeData);
    console.log("读取到的代理合约地址:", proxyAddress);
    console.log("读取到的实现合约地址:", implAddress);

    // 开始升级
    console.log("开始升级合约...");
    const AuctionV2 = await ethers.getContractFactory("AuctionV2");

    const auctionV2Proxy = await upgrades.upgradeProxy(proxyAddress, AuctionV2, {
        initializer: "initialize",
        args: [deployer]
    });

    console.log("合约升级完成");
    const proxyAddressV2 = auctionV2Proxy.target
    console.log("代理合约地址:", auctionV2Proxy.target);
    const newImplAddress = await upgrades.erc1967.getImplementationAddress(
        proxyAddressV2
    );
    console.log("新的实现合约地址:", newImplAddress);

    // 保存json文件
    const deploymentsDir = path.join(
        __dirname,
        "./.cache",
        "proxyAuctionV2.json"
    );
    fs.writeFileSync(
        deploymentsDir,
        JSON.stringify({
            proxyAddressV2,
            implAddress,
            abi: AuctionV2.interface.format("json"),
        })
    );
    await save("AuctionProxyV2", {
        address: proxyAddressV2,
        abi: AuctionV2.interface.format("json"),
        args: [],
        log: true,
    });
};

module.exports.tags = ["upgradeAuction"];