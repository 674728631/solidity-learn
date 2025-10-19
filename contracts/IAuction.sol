// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

interface IAuction {
    function createAuctionNFT(
        address nftContract,
        uint256 tokenId,
        uint256 startingPrice,
        uint256 duration
    ) external;

    function placeBid(
        address _tokenAddress,
        uint256 tokenId,
        uint256 amount
    ) external payable;

    function endAuction(uint256 auctionId) external;
}
