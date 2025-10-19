// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IAuction.sol";
import "./Auction.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "hardhat/console.sol";
import "./AuctionFactory.sol";

// AuctionFactory 工厂合约用于创建 auction 拍卖合约的实例
contract AuctionFactoryV2 is AuctionFactory {
    // 新增功能：test
    function test() external pure returns (string memory) {
        return "Hello, Factory World!";
    }
}
