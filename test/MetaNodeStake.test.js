const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@openzeppelin/test-helpers");

describe("MetaNodeStake", function () {
  let MetaNodeStake, metaNodeStake, metaNodeToken, stakingToken;
  let owner, user1, user2, admin;

  before(async () => {
    [owner, user1, user2, admin] = await ethers.getSigners();
    console.log("owner: ", owner.address);
    console.log("user1: ", user1.address);
    console.log("user2: ", user2.address);
    console.log("admin: ", admin.address);

    // 部署 MetaNode 代币
    const MetaNodeToken = await ethers.getContractFactory("MetaNodeToken");
    metaNodeToken = await MetaNodeToken.deploy();
    await metaNodeToken.waitForDeployment();


     // 部署ERC20
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    stakingToken = await MockERC20.deploy(); // 添加构造函数参数
    await stakingToken.waitForDeployment();


    // 部署 MetaNodeStake 合约
    MetaNodeStake = await ethers.getContractFactory("MetaNodeStake");
    metaNodeStake = await MetaNodeStake.deploy();
    await metaNodeStake.waitForDeployment();
    console.log("metaNodeStakeAddress: ", await metaNodeStake.getAddress());

    const metaNodeTokenAddress = await metaNodeToken.getAddress();
    await metaNodeStake.initialize(
      metaNodeTokenAddress,
      1, // startBlock
      200, // endBlock
      ethers.parseEther("1") // MetaNodePerBlock
    );

    // 授予管理员角色
    await metaNodeStake.grantRole(await metaNodeStake.ADMIN_ROLE(), admin.address);

    // 添加质押池0 -- eth
    await metaNodeStake.connect(admin).addPool(
      ethers.ZeroAddress,
      100, // poolWeight
      1000, // _minDepositAmount
      10, // _unstakeLockedBlocks
      true // _withUpdate
    );

    // 添加质押池1
    const stakingTokenAddress = await stakingToken.getAddress();
    console.log("stakingTokenAddress: ", stakingTokenAddress);
    await metaNodeStake.connect(admin).addPool(
      stakingTokenAddress,
      100, // poolWeight
      1000, // _minDepositAmount
      10, // _unstakeLockedBlocks
      true // _withUpdate
    );
  });

  // describe("initialize", function () {
  //   it("应正确初始化合约参数", async () => {
  //     expect(await metaNodeStake.startBlock()).to.equal(1000);
  //     expect(await metaNodeStake.endBlock()).to.equal(2000);
  //     expect(await metaNodeStake.MetaNodePerBlock()).to.equal(ethers.parseEther("1"));
  //   });

  //   it("应拒绝无效的初始化参数", async () => {
  //     const invalidStake = await MetaNodeStake.deploy();
  //     await invalidStake.waitForDeployment();

  //     const metaNodeTokenAddress = await metaNodeToken.getAddress();
  //     await expect(
  //       invalidStake.initialize(
  //         metaNodeTokenAddress,
  //         2000, // startBlock > endBlock
  //         1000,
  //         ethers.parseEther("1")
  //       )
  //     ).to.be.revertedWith("invalid parameters");
  //   });
  // });

  describe("deposit", function () {
    it("应允许用户质押代币并更新奖励", async () => {
      const stakingTokenAddress = await stakingToken.getAddress();
      console.log("stakingTokenAddress2: ", stakingTokenAddress);
      // 给用户1转账10000个代币
      await stakingToken.transfer(user1.address, 10000);
      // 用户1授权MetaNodeStake合约使用代币
      await stakingToken.connect(user1).approve(await metaNodeStake.getAddress(), 10000);

      await expect(metaNodeStake.connect(user1).deposit(1, 2000))
        .to.emit(metaNodeStake, "Deposit")
        .withArgs(user1.address, 1, 2000);

      const userInfo = await metaNodeStake.user(1, user1.address);
      console.log("userInfo: ", userInfo);
      expect(userInfo.stAmount).to.equal(2000);
    });

    it("应拒绝无效的池 ID", async () => {
      await expect(
        metaNodeStake.connect(user1).deposit(999, 10)
      ).to.be.revertedWith("invalid pid");
    });

    it("应拒绝质押量小于最小要求", async () => {
      await expect(
        metaNodeStake.connect(user1).deposit(1, 100)
      ).to.be.revertedWith("deposit amount is too small");
    });
  });

  describe("unstake", function () {
    it("应允许用户取消质押并创建提取请求", async () => {
      await metaNodeStake.connect(user1).unstake(1, 50);
      const length = await metaNodeStake.withdrawRequests(1, user1.address);
      expect(length).to.equal(1);
      const stAmount = await metaNodeStake.stakingBalance(1, user1.address);
      expect(stAmount).to.equal(1950);
    });

    it("应拒绝超额取消质押", async () => {
      await expect(
        metaNodeStake.connect(user1).unstake(1, 10000)
      ).to.be.revertedWith("Not enough staking token balance");
    });
  });

  describe("withdraw", function () {
    it("应允许用户提取已解锁的代币", async () => {
      await time.advanceBlockTo(20); // 解锁区块

      await expect(metaNodeStake.connect(user1).withdraw(1))
        .to.emit(metaNodeStake, "Withdraw")
        .withArgs(user1.address, 1, 20, 11);

      const userInfo = await metaNodeStake.user(1, user1.address);
      expect(userInfo.requests.length).to.equal(0);
    });

    it("应拒绝提取未解锁的代币", async () => {
      await metaNodeStake.connect(user1).unstake(1, 100);
      await expect(
        metaNodeStake.connect(user1).withdraw(1)
      ).to.be.revertedWith("No available amount to withdraw");
    });
  });

  // describe("claim", function () {
  //   it("应允许用户领取奖励", async () => {
  //     await time.advanceBlockTo(12); // 生成奖励

  //     const pending = await metaNodeStake.pendingMetaNode(1, user1.address);
  //     await expect(metaNodeStake.connect(user1).claim(1))
  //       .to.emit(metaNodeStake, "Claim")
  //       .withArgs(user1.address, 1, pending);

  //     console.log("userInfo.pendingMetaNode: ",userInfo.pendingMetaNode)
  //     const userInfo = await metaNodeStake.user(1, user1.address);
  //     expect(userInfo.pendingMetaNode).to.equal(0);
  //   });

  //   it("应拒绝领取暂停状态下的奖励", async () => {
  //     await metaNodeStake.connect(admin).pauseClaim();
  //     await expect(
  //       metaNodeStake.connect(user1).claim(1)
  //     ).to.be.revertedWith("claim is paused");
  //   });
  // });

  // describe("admin functions", function () {
  //   it("仅管理员可暂停提取功能", async () => {
  //     await expect(
  //       metaNodeStake.connect(user1).pauseWithdraw()
  //     ).to.be.reverted;

  //     await metaNodeStake.connect(admin).pauseWithdraw();
  //     expect(await metaNodeStake.withdrawPaused()).to.equal(true);
  //   });

  //   it("应允许管理员更新池参数", async () => {
  //     await metaNodeStake.connect(admin).updatePool(
  //       0,
  //       10, // 新的最小质押量
  //       200 // 新的锁定区块数
  //     );
  //     const poolInfo = await metaNodeStake.pool(0);
  //     expect(poolInfo.minDepositAmount).to.equal(10);
  //   });
  // });
});
