// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract CatNFT is ERC721, ERC721URIStorage, Ownable {
    using Strings for uint256;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    constructor(address _owner) ERC721("CatNFT", "CAT") Ownable(_owner) {}

    // 铸造新的NFT
    // @param to 接收NFT的地址
    // @param tokenURI NFT的元数据URI
    function safeMint(address to, string memory _tokenURI) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, _tokenURI);
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
}
