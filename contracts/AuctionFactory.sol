// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./nftAuction.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
    AuctionFactory合约用于创建NftAuction拍卖合约的实例
*/
contract AuctionFactory is UUPSUpgradeable, Ownable {
    // 拍卖合约地址数组
    address[] public auctionInstances;

    // 初始化函数，设置合约所有者
    function initialize() public initializer {
        __UUPSUpgradeable_init();
    }

    // 创建新的拍卖合约实例
    function createAuction(
        address nftContract,
        uint256 tokenId,
        uint256 startingPrice,
        uint256 duration
    ) external {
        NftAuction newAuction = new NftAuction();
        auctionInstances.push(address(newAuction));
        newAuction.createAuction(nftContract, tokenId, startingPrice, duration);
    }

    // 升级合约
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
