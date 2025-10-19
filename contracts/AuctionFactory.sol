// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IAuction.sol";
import "./Auction.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "hardhat/console.sol";

// AuctionFactory 工厂合约用于创建 auction 拍卖合约的实例
contract AuctionFactory is UUPSUpgradeable, OwnableUpgradeable {
    // 拍卖合约地址数组
    address[] public auctionInstances;
    // 拍卖合约id到拍卖合约地址的映射
    mapping(uint256 => address) public auctionIdToAddress;
    // 下一个拍卖合约ID
    uint256 public nextAuctionId;

    // 初始化函数，设置合约所有者
    function initialize() public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init();
    }

    // 创建拍卖合约实例(创建一场拍卖)
    function createAuction() external {
        console.log("createAuction", msg.sender, address(this));
        Auction newAuction = new Auction();
        newAuction.initialize(msg.sender);
        auctionInstances.push(address(newAuction));
        auctionIdToAddress[nextAuctionId] = address(newAuction);
        nextAuctionId++;
    }

    // 在指定拍卖合约中创建拍卖品
    function createAuctionNFT(
        uint256 auctionId,
        address nftContract,
        uint256 tokenId,
        uint256 startingPrice,
        uint256 duration
    ) external {

        console.log("factory createAuctionNFT time , nft owner:", ERC721(nftContract).ownerOf(tokenId));
        // 获取拍卖合约地址
        address auction = auctionIdToAddress[auctionId];
        require(auction != address(0), "Auction does not exist");
        console.log(
            "address(this),auction",
            msg.sender,
            address(this),
            auction
        );
        console.log("Transferred NFT to auction contract");

        // 调用拍卖合约的 createAuctionNFT 方法创建拍卖品
        IAuction(auction).createAuctionNFT(
            nftContract,
            tokenId,
            startingPrice,
            duration
        );
    }

    // 升级合约
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

        fallback() external payable {

        console.log("factory fallback");

    }

    receive() external payable {
        console.log("factory receive");
    }

    // 根据拍卖合约id读取拍卖合约地址
    function getAuctionById(uint256 id) external view returns(address) {
        return auctionIdToAddress[id];
    }
}
