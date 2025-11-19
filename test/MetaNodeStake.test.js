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
      1 // MetaNodePerBlock
    );

    // 授予管理员角色
    await metaNodeStake.grantRole(
      await metaNodeStake.ADMIN_ROLE(),
      admin.address
    );

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
      1, // poolWeight
      100, // _minDepositAmount
      5, // _unstakeLockedBlocks
      true // _withUpdate
    );
  });

  describe("initialize", function () {
    it("应正确初始化合约参数", async () => {
      expect(await metaNodeStake.startBlock()).to.equal(1);
      expect(await metaNodeStake.endBlock()).to.equal(200);
      expect(await metaNodeStake.MetaNodePerBlock()).to.equal(1);
    });

    it("应拒绝无效的初始化参数", async () => {
      const invalidStake = await MetaNodeStake.deploy();
      await invalidStake.waitForDeployment();

      const metaNodeTokenAddress = await metaNodeToken.getAddress();
      await expect(
        invalidStake.initialize(
          metaNodeTokenAddress,
          2000, // startBlock > endBlock
          1000,
          ethers.parseEther("1")
        )
      ).to.be.revertedWith("invalid parameters");
    });
  });

  describe("deposit", function () {
    it("应允许用户质押代币并更新奖励", async () => {
      const stakingTokenAddress = await stakingToken.getAddress();
      console.log("stakingTokenAddress2: ", stakingTokenAddress);
      // 给用户1转账10000个代币
      await stakingToken.transfer(user1.address, 10000);
      // 用户1授权MetaNodeStake合约使用代币
      await stakingToken
        .connect(user1)
        .approve(await metaNodeStake.getAddress(), 10000);

      await expect(metaNodeStake.connect(user1).deposit(1, 500))
        .to.emit(metaNodeStake, "Deposit")
        .withArgs(user1.address, 1, 500);

      const userInfo = await metaNodeStake.user(1, user1.address);
      expect(userInfo.stAmount).to.equal(500);
    });

    it("应拒绝无效的池 ID", async () => {
      await expect(
        metaNodeStake.connect(user1).deposit(999, 10)
      ).to.be.revertedWith("invalid pid");
    });

    it("应拒绝质押量小于最小要求", async () => {
      await expect(
        metaNodeStake.connect(user1).deposit(1, 10)
      ).to.be.revertedWith("deposit amount is too small");
    });
  });

  describe("unstake", function () {
    it("应允许用户取消质押并创建提取请求", async () => {
      await metaNodeStake.connect(user1).unstake(1, 100);
      const length = await metaNodeStake.withdrawRequests(1, user1.address);
      expect(length).to.equal(1);
      const stAmount = await metaNodeStake.stakingBalance(1, user1.address);
      expect(stAmount).to.equal(400);
    });

    it("应拒绝超额取消质押", async () => {
      await expect(
        metaNodeStake.connect(user1).unstake(1, 10000)
      ).to.be.revertedWith("Not enough staking token balance");
    });
  });

  describe("withdraw", function () {
    it("应允许用户提取已解锁的代币", async () => {
      // 挖矿，推进区块
      for (let i = 0; i < 5; i++) {
        await ethers.provider.send("evm_mine");
      }
      await expect(metaNodeStake.connect(user1).withdraw(1))
        .to.emit(metaNodeStake, "Withdraw")
        .withArgs(user1.address, 1, 100, 20);

      const userInfo = await metaNodeStake.user(1, user1.address);
      console.log("userInfo: ", userInfo);
      const length = await metaNodeStake.withdrawRequests(1, user1.address);
      expect(length).to.equal(0);
      let pendingWithdrawAmount = await metaNodeStake.withdrawAmount(
        1,
        user1.address
      );
      console.log("requestAmount: ", pendingWithdrawAmount[0]);
      console.log("pendingWithdrawAmount: ", pendingWithdrawAmount[1]);
    });

    it("应拒绝提取未解锁的代币", async () => {
      await metaNodeStake.connect(user1).unstake(1, 100);
      await expect(metaNodeStake.connect(user1).withdraw(1))
        .to.emit(metaNodeStake, "Withdraw")
        .withArgs(user1.address, 1, 0, 22); // 0没有奖励，22是解锁区块数
    });
  });

  describe("claim", function () {
    it("应允许用户领取奖励", async () => {
      // 挖矿，推进区块
      for (let i = 0; i < 5; i++) {
        await ethers.provider.send("evm_mine");
      }

      const pending = await metaNodeStake.pendingMetaNode(1, user1.address);
      console.log("pending: ", pending);
      await expect(metaNodeStake.connect(user1).claim(1))
        .to.emit(metaNodeStake, "Claim")
        .withArgs(user1.address, 1, 99009900990099008n);

      const userInfo = await metaNodeStake.user(1, user1.address);
      console.log("userInfo.pendingMetaNode: ", userInfo.pendingMetaNode);
      expect(userInfo.pendingMetaNode).to.equal(0);
    });

    it("应拒绝领取暂停状态下的奖励", async () => {
      await metaNodeStake.connect(admin).pauseClaim();
      await expect(metaNodeStake.connect(user1).claim(1)).to.be.revertedWith(
        "claim is paused"
      );
      await metaNodeStake.connect(admin).unpauseClaim();
    });
  });

  describe("admin functions", function () {
    it("仅管理员可暂停提取功能", async () => {
      await expect(metaNodeStake.connect(user1).pauseWithdraw()).to.be.reverted;

      await metaNodeStake.connect(admin).pauseWithdraw();
      expect(await metaNodeStake.withdrawPaused()).to.equal(true);
    });

    it("仅管理员可恢复提取功能", async () => {
      await metaNodeStake.connect(admin).unpauseWithdraw();
      expect(await metaNodeStake.withdrawPaused()).to.equal(false);
    });

    it("仅管理员可暂停领取功能", async () => {
      await expect(metaNodeStake.connect(user1).pauseClaim()).to.be.reverted;

      await metaNodeStake.connect(admin).pauseClaim();
      expect(await metaNodeStake.claimPaused()).to.equal(true);
    });

    it("仅管理员可恢复领取功能", async () => {
      await metaNodeStake.connect(admin).unpauseClaim();
      expect(await metaNodeStake.claimPaused()).to.equal(false);
    });

    it("仅管理员可设置 MetaNode 代币地址", async () => {
      const newMetaNodeToken = await ethers.getContractFactory("MetaNodeToken");
      const newToken = await newMetaNodeToken.deploy();
      await newToken.waitForDeployment();

      await expect(metaNodeStake.connect(user1).setMetaNode(newToken)).to.be
        .reverted;

      await metaNodeStake.connect(admin).setMetaNode(newToken);
      expect(await metaNodeStake.MetaNode()).to.equal(
        await newToken.getAddress()
      );
    });

    it("仅管理员可设置开始和结束区块", async () => {
      await expect(metaNodeStake.connect(user1).setStartBlock(100)).to.be
        .reverted;

      await metaNodeStake.connect(admin).setStartBlock(100);
      expect(await metaNodeStake.startBlock()).to.equal(100);

      await metaNodeStake.connect(admin).setEndBlock(200);
      expect(await metaNodeStake.endBlock()).to.equal(200);
    });

    it("仅管理员可设置每个区块的 MetaNode 奖励", async () => {
      await expect(
        metaNodeStake.connect(user1).setMetaNodePerBlock(ethers.parseEther("2"))
      ).to.be.reverted;

      await metaNodeStake
        .connect(admin)
        .setMetaNodePerBlock(ethers.parseEther("2"));
      expect(await metaNodeStake.MetaNodePerBlock()).to.equal(
        ethers.parseEther("2")
      );
    });

    it("仅管理员可更新池信息", async () => {
      await expect(
        metaNodeStake.connect(user1).updatePool(
          0,
          10, // minDepositAmount
          200 // unstakeLockedBlocks
        )
      ).to.be.reverted;

      await metaNodeStake.connect(admin).updatePool(0, 10, 200);
      const poolInfo = await metaNodeStake.pool(0);
      expect(poolInfo.minDepositAmount).to.equal(10);
    });

    it("仅管理员可设置池权重", async () => {
      await expect(
        metaNodeStake.connect(user1).setPoolWeight(
          0,
          200, // poolWeight
          false
        )
      ).to.be.reverted;

      await metaNodeStake.connect(admin).setPoolWeight(0, 200, true);
      const poolInfo = await metaNodeStake.pool(0);
      expect(poolInfo.poolWeight).to.equal(200);
    });
  });
});
