const { ethers, deployments } = require("hardhat");
const { expect } = require("chai");
const { dataLength } = require("ethers");

describe('Test Upgrade', function () {


    it("test v2", async function () {
        const [signer, buyer, user2, user3] = await ethers.getSigners();

        console.log("signer, buyer: ", signer.address, buyer.address, user2.address, user3.address);

        // 部署ERC721 合约 NFT
        const NFT = await ethers.getContractFactory("NFT");
        const erc721Mock = await NFT.deploy(); // 添加构造函数参数
        await erc721Mock.waitForDeployment();

        const erc721Address = await erc721Mock.getAddress();
        console.log("erc721Address: ", erc721Address);
        console.log("erc721Address owner: ", await erc721Mock.owner());

        // mint 2个NFT
        const nft1 = 1;
        const nft2 = 2;
        await erc721Mock.connect(signer).safeMint(user2.address, nft1 + "");
        await erc721Mock.connect(signer).safeMint(user3.address, nft2 + "");
    
        // 部署拍卖合约
        await deployments.fixture(["deployAuction"]);
        const auctionProxy = await deployments.get("AuctionProxy");
        // 给代理合约授权  
        console.log("erc721Mock 授权给 auctionProxy ", auctionProxy.address)
        await erc721Mock.connect(user2).setApprovalForAll(auctionProxy.address, true);

        // 部署工厂合约
        await deployments.fixture(["deployAuctionFactory"]);
        const auctionFactoryProxy = await deployments.get("AuctionFactoryProxy");
        const auctionFactory = await ethers.getContractAt("AuctionFactory", auctionFactoryProxy.address);
        console.log("auctionFactoryProxy.address: ", auctionFactoryProxy.address);
        console.log("auctionFactory.address: ", auctionFactory.address); // undefined?
        // 给工厂授权  
        console.log("erc721Mock 给 auctionFactoryProxy 授权", auctionFactoryProxy.address)
        await erc721Mock.connect(user2).setApprovalForAll(auctionFactoryProxy.address, true);

        // 创建拍卖
        await auctionFactory.connect(signer).createAuction(); // 0号

        // 获取拍卖合约地址
        const auctionAddress = await auctionFactory.auctionIdToAddress(0);
        console.log("工厂中的拍卖合约0地址：", auctionAddress);

        // 给拍卖合约授权
        console.log("erc721Mock 给工厂生成的auctionAddress 授权", auctionAddress)
        await erc721Mock.connect(user2).setApprovalForAll(auctionAddress, true);


        // 在0号拍卖合约中创建NFT拍卖，起拍价0.1 ETH，持续时间10秒
        await auctionFactory.connect(signer).createAuctionNFT(0, erc721Address, nft1, ethers.parseEther("0.1"), 10);

        const fatory1auction = await auctionFactory.getAuctionById(0);
        console.log("升级前工厂中的拍卖合约0地址：", ethers.getAddress(fatory1auction));
        const fatory1auction1 = await auctionFactory.getAuctionById(1);
        console.log("升级前工厂中的拍卖合约1地址：", ethers.getAddress(fatory1auction1));

        // 升级工厂合约
        await deployments.fixture(["upgradeAuctionFactory"]);

        // const test2 = await auctionFactoryProxy.test(); // 代理地址为啥不能调用？

        // 获取v2工厂
        const auctionFactory2 = await ethers.getContractAt(
            "AuctionFactoryV2",
            auctionFactoryProxy.address
        );
        // 调用新增方法
        const test = await auctionFactory2.test();
        console.log("v2 方法：", test);


        // 在1号拍卖合约中创建NFT拍卖，起拍价0.1 ETH，持续时间10秒
        await auctionFactory2.connect(signer).createAuction(); // 1号
        // 获取拍卖合约地址
        const auctionAddress0 = await auctionFactory2.auctionIdToAddress(0);
        console.log("升级后工厂中的拍卖合约0地址：", auctionAddress0);
        const auctionAddress2 = await auctionFactory2.auctionIdToAddress(1);
        console.log("升级后工厂中的拍卖合约1地址：", auctionAddress2);

        // 给拍卖合约授权
        console.log("erc721Mock 给工厂生成的auctionAddress2 授权", auctionAddress2)
        await erc721Mock.connect(user3).setApprovalForAll(auctionAddress2, true);


        await auctionFactory2.connect(signer).createAuctionNFT(1, erc721Address, nft2, ethers.parseEther("0.1"), 11);

        // 购买者出价
        const nftAuction = await ethers.getContractAt("Auction", auctionAddress2);
        await nftAuction.connect(buyer).placeBid(ethers.ZeroAddress, 0, ethers.parseEther("0.2"));

        // 升级auctionv2
        await deployments.fixture(["upgradeAuction"]);
        // 获取auctionv2
         const auctionv2 = await ethers.getContractAt(
            "AuctionV2",
            auctionProxy.address
        );
        // 调用新增方法
        const test2 = await auctionv2.test();
        console.log("v2 方法：", test2);

        // await auctionv2.connect(buyer).placeBid(ethers.ZeroAddress, 1, ethers.parseEther("0.3"));

        // // 购买者出价
        // const nftAuction = await ethers.getContractAt("Auction", auctionAddress);
        // await nftAuction.connect(buyer).placeBid(ethers.ZeroAddress, 0, ethers.parseEther("0.2"));

        // // 等待拍卖结束
        // await new Promise(resolve => setTimeout(resolve, 12 * 1000));

        // await nftAuction.connect(signer).endAuction(0);

        // // 验证结果
        // const auctionResult = await nftAuction.auctions(0);
        // console.log("拍卖结果：", auctionResult);
        // expect(auctionResult.highestBidder).to.equal(await buyer.getAddress());
        // expect(auctionResult.highestBid).to.equal(ethers.parseEther("0.2"));

        // 验证NFT归属
        // const newOwner = await erc721Mock.ownerOf(tokenId);
        // console.log("NFT新归属：", newOwner);
        // expect(newOwner).to.equal(await buyer.getAddress());
    });
});     