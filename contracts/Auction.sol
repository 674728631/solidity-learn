// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./IAuction.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Auction is UUPSUpgradeable, IAuction, IERC721Receiver, OwnableUpgradeable {
    // 拍卖结构体
    struct AuctionStruct {
        address seller; // 卖家地址
        uint256 startingPrice; // 起始价格
        uint256 highestBid; // 最高出价
        address highestBidder; // 最高出价者
        uint256 startTime; // 拍卖开始时间
        uint256 duration; // 拍卖持续时间
        bool ended; // 是否已结算
        address nftContract; // NFT合约地址
        uint256 tokenId; // NFT的Token ID
        address tokenAddress; // 竞拍使用的代币地址（address(0)表示使用ETH）
    }

    // 下一个拍卖品ID
    uint256 public nextAuctionId;
    // 拍卖品ID到拍卖的映射
    mapping(uint256 => AuctionStruct) public auctions;

    // 预言机币对地址映射
    mapping(address tokenAddress => AggregatorV3Interface)
        public tokenToPriceFeed;

    // 初始化函数
    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    // 创建拍卖
    function createAuctionNFT(
        address nftContract,
        uint256 tokenId,
        uint256 startingPrice,
        uint256 duration
    ) external override {
        // duration > 0
        require(duration > 0, "Duration must be greater than zero");
        // startingPrice > 0
        require(startingPrice > 0, "Starting price must be greater than zero");

        console.log(
            "Transferring NFT from %s to %s",
            msg.sender,
            address(this)
        );
        // 转移NFT到拍卖合约地址
        ERC721(nftContract).safeTransferFrom(
            ERC721(nftContract).ownerOf(tokenId),
            address(this),
            tokenId
        );

        // 生成拍卖
        AuctionStruct memory newAuction = AuctionStruct({
            seller: msg.sender,
            startingPrice: startingPrice,
            highestBid: 0,
            highestBidder: address(0),
            startTime: block.timestamp,
            duration: duration,
            ended: false,
            nftContract: nftContract,
            tokenId: tokenId,
            tokenAddress: address(0) // 默认使用ETH竞拍
        });
        auctions[nextAuctionId] = newAuction;
        nextAuctionId++;
    }

    // 出价
    function placeBid(
        address _tokenAddress,
        uint256 tokenId,
        uint256 amount
    ) external payable override {
        // 判断是否在拍卖时间内
        console.log("tokenId", tokenId);
        AuctionStruct storage auction = auctions[tokenId];

        console.log("placeBid auction:");
        console.log("auction.seller ", auction.seller);
        console.log("auction.startTime ", auction.startTime);
        console.log("auction.duration ", auction.duration);


        require(
            !auction.ended &&
                block.timestamp < auction.startTime + auction.duration,
            "Auction has ended"
        );

        uint256 payValue;
        // 如果使用代币竞拍，获取代币价格并转换出价金额
        if (_tokenAddress != address(0)) {
            uint256 tokenPrice = getPriceFromOracle(_tokenAddress);
            require(tokenPrice > 0, "Invalid token price from oracle");
            // 将出价金额转换为usd
            payValue = (amount * tokenPrice) / 1e8;
        } else {
            // amount = msg.value;
            // uint256 tokenPrice = getPriceFromOracle(address(0));
            // require(tokenPrice > 0, "Invalid token price from oracle");
            // // 将出价金额转换为usd
            // payValue = (amount * tokenPrice) / 1e8;
            payValue = amount;
        }

        // // 起拍价转为usd, 起拍价设置的eth
        // uint256 startingPriceInUsd = (auction.startingPrice *
        //     uint256(getPriceFromOracle(address(0)))) / 1e8;
        // // 最高出价转为usd
        // uint256 highestBidInUsd = (auction.highestBid *
        //     uint256(getPriceFromOracle(auction.tokenAddress))) / 1e8;
        uint256 startingPriceInUsd = auction.startingPrice;
        uint256 highestBidInUsd = auction.highestBid;

        // 出价必须高于当前最高出价
        require(
            payValue >= startingPriceInUsd && payValue > highestBidInUsd,
            "Bid must be higher than current highest bid and starting price"
        );

        // 如果使用代币竞拍，转移代币
        if (_tokenAddress != address(0)) {
            IERC20(_tokenAddress).transferFrom(
                msg.sender,
                address(this),
                amount
            );
        } // 否则使用ETH竞拍，已经通过msg.value支付

        // 退还之前的最高出价
        if (auction.highestBidder != address(0)) {
            if (auction.tokenAddress != address(0)) {
                // 通过ERC20合约退还代币
                IERC20(auction.tokenAddress).transfer(
                    auction.highestBidder,
                    auction.highestBid
                );
            } else {
                // 退还ETH
                // payable(auction.highestBidder).transfer(auction.highestBid);
                (bool success, ) = payable(auction.highestBidder).call{
                    value: auction.highestBid
                }("");
                require(success, "Failed to transfer ETH");
            }
        }

        // 更新最高出价和出价者
        auction.highestBid = amount;
        auction.highestBidder = msg.sender;
        auction.tokenAddress = _tokenAddress;
    }

    // 结算拍卖
    function endAuction(uint256 auctionId) external override {
        // 只能在拍卖结束后结算
        AuctionStruct storage auction = auctions[auctionId];

        console.log("end auction:");
        console.log("auction.seller", auction.seller);
        console.log("auction.startingPrice", auction.startingPrice);
        console.log("auction.highestBid", auction.highestBid);
        console.log("auction.highestBidder", auction.highestBidder);
        console.log("auction.startTime", auction.startTime);
        console.log("auction.duration", auction.duration);
        console.log("auction.ended", auction.ended);
        console.log("auction.nftContract", auction.nftContract);
        console.log("auction.tokenId", auction.tokenId);
        console.log("auction.tokenAddress", auction.tokenAddress);

        require(
            !auction.ended &&
                block.timestamp >= auction.startTime + auction.duration,
            "Auction is still ongoing or already ended"
        );
        // 结算拍卖
        auction.ended = true;
        // 将NFT转移给最高出价者
        if (auction.highestBidder != address(0)) {
            // 通过ERC721合约转移NFT
            ERC721(auction.nftContract).safeTransferFrom(
                address(this),
                auction.highestBidder,
                auction.tokenId
            );
            // 将最高出价转移给卖家
            if (auction.tokenAddress != address(0)) {
                // 通过ERC20合约转移代币
                IERC20(auction.tokenAddress).transfer(
                    auction.seller,
                    auction.highestBid
                );
            } else {
                console.log(unicode"转移最终价 %s ETH到seller: %s 账户", auction.highestBid, auction.seller);
                // // 转移ETH
                // (bool success, ) = payable(auction.seller).call{
                //     value: auction.highestBid
                // }("");
                // require(success, "Failed to transfer ETH");
            }
        } else {
            // 如果没有出价者，退还NFT给卖家
            ERC721(auction.nftContract).safeTransferFrom(
                address(this),
                auction.seller,
                auction.tokenId
            );
        }
    }

    // 预言机接口
    function getPriceFromOracle(
        address _tokenAddress
    ) internal view returns (uint256) {
        // 获取预言机地址
        AggregatorV3Interface priceFeed = tokenToPriceFeed[_tokenAddress];
        require(
            address(priceFeed) != address(0),
            "Price feed not set for this token"
        );
        // 通过预言机地址获取价格
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return uint256(price);
    }

    // 设置预言机地址
    function setPriceFeed(address _tokenAddress, address _priceFeed) external {
        tokenToPriceFeed[_tokenAddress] = AggregatorV3Interface(_priceFeed);
    }

    // 获取当前最高出价usd
    function getCurrentHighestBidInUsd(
        uint256 auctionId
    ) external view returns (uint256) {
        AuctionStruct storage auction = auctions[auctionId];
        if (auction.highestBid == 0) {
            return 0;
        }
        uint256 highestBidInUsd = (auction.highestBid *
            uint256(getPriceFromOracle(auction.tokenAddress))) / 1e8;
        return highestBidInUsd;
    }

    fallback() external payable {
        console.log("auction fallback");
    }

    receive() external payable {
        console.log("auction receive");
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC721Received.selector; // 必须返回固定值
    }

        // 升级合约
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
