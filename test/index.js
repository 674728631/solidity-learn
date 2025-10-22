const { ethers, deployments } = require("hardhat");
const { expect } = require("chai");

describe('Test', function () {


    it("test v1", async function () {
        const [signer, buyer, user2, user3] = await ethers.getSigners();

        console.log("signer, buyer: ", signer.address, buyer.address, user2.address, user3.address);

        // 部署ERC721 合约 NFT
        const NFT = await ethers.getContractFactory("NFT");
        const erc721Mock = await NFT.deploy(); // 添加构造函数参数
        await erc721Mock.waitForDeployment();

        const erc721Address = await erc721Mock.getAddress();
        console.log("erc721Address: ", erc721Address);
        console.log("erc721Address owner: ", await erc721Mock.owner());

        // mint 10个NFTcleatr
        for (let i = 1; i <= 10; i++) {
            await erc721Mock.connect(signer).safeMint(signer.getAddress(), i + "");
        }
        const tokenId = 1;

        // 部署拍卖合约
        await deployments.fixture(["deployAuction"]);
        const auctionProxy = await deployments.get("AuctionProxy");
        // 给代理合约授权  
        console.log("erc721Mock 授权给 auctionProxy ", auctionProxy.address)
        await erc721Mock.connect(signer).setApprovalForAll(auctionProxy.address, true);

        // 部署工厂合约
        await deployments.fixture(["deployAuctionFactory"]);
        const auctionFactoryProxy = await deployments.get("AuctionFactoryProxy"); 
        const auctionFactory = await ethers.getContractAt("AuctionFactory", auctionFactoryProxy.address);
        // 给工厂授权  
        console.log("erc721Mock 给 auctionFactoryProxy 授权", auctionFactoryProxy.address)
        await erc721Mock.connect(signer).setApprovalForAll(auctionFactoryProxy.address, true);

        // 创建拍卖
        await auctionFactory.connect(signer).createAuction(auctionProxy.address); // 0号

        // 获取拍卖合约地址
        const auctionAddress = await auctionFactory.auctionIdToAddress(0);
        console.log("工程中的拍卖合约地址：", auctionAddress);

        // 给拍卖合约授权
        console.log("erc721Mock 给工厂生成的auctionAddress 授权", auctionAddress)
        await erc721Mock.connect(signer).setApprovalForAll(auctionAddress, true);

      
        // 在0号拍卖合约中创建NFT拍卖，起拍价0.1 ETH，持续时间10秒
        await auctionFactory.connect(signer).createAuctionNFT(0, erc721Address, tokenId, ethers.parseEther("0.1"), 10);

        // 购买者出价
        const nftAuction = await ethers.getContractAt("Auction", auctionAddress);
        await nftAuction.connect(buyer).placeBid(ethers.ZeroAddress, 0, ethers.parseEther("0.2"));

        // 等待拍卖结束
        await new Promise(resolve => setTimeout(resolve, 12 * 1000));

        await nftAuction.connect(signer).endAuction(0);

        // 验证结果
        const auctionResult = await nftAuction.auctions(0);
        console.log("拍卖结果：", auctionResult);
        expect(auctionResult.highestBidder).to.equal(await buyer.getAddress());
        expect(auctionResult.highestBid).to.equal(ethers.parseEther("0.2"));

        // 验证NFT归属
        // const newOwner = await erc721Mock.ownerOf(tokenId);
        // console.log("NFT新归属：", newOwner);
        // expect(newOwner).to.equal(await buyer.getAddress());
    });
});     