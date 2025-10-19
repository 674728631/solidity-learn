// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// NFT合约
contract NFT is ERC721, ERC721URIStorage, Ownable {
    using Strings for uint256;

    uint256 private _tokenIdCounter = 1;

    constructor() ERC721("NFT", "CAT") Ownable(msg.sender) {}

    // 铸造新的NFT
    // @param to 接收NFT的地址
    // @param tokenURI NFT的元数据URI
    function safeMint(address to, string memory _tokenURI) public onlyOwner {
        _safeMint(to, _tokenIdCounter);
        _setTokenURI(_tokenIdCounter, _tokenURI);
        _tokenIdCounter++;
    }

    // 重写tokenURI函数以支持ERC721和ERC721URIStorage接口
    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    // 重写supportsInterface函数以支持ERC721和ERC721URIStorage接口
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // 获取所有NFT的tokenId
    function getAllTokenIds(
        uint256 totalSupply
    ) public view returns (address[] memory) {
        address[] memory tokenAddress = new address[](totalSupply);
        for (uint256 i = 0; i < totalSupply; i++) {
            tokenAddress[i] = _ownerOf(i);
        }
        return tokenAddress;
    }
}
