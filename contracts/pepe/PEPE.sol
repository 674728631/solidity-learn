// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// /**
//  * @title PepeToken
//  * @dev 这是一个基于 ERC20 标准的代币合约，具有黑名单功能和交易限制规则。
//  * 合约所有者可以设置交易规则，包括最大和最小持有量限制，以及黑名单地址。
//  */
// contract PepeToken is Ownable, ERC20 {
//     // 是否启用交易限制
//     bool public limited;
//     // 最大持有量限制
//     uint256 public maxHoldingAmount;
//     // 最小持有量限制
//     uint256 public minHoldingAmount;
//     // Uniswap V2 交易对地址
//     address public uniswapV2Pair;
//     // 黑名单地址映射
//     mapping(address => bool) public blacklists;

//     /**
//      * @dev 构造函数，初始化代币名称、符号和总供应量。
//      * @param _totalSupply 代币的总供应量
//      */
//     constructor(uint256 _totalSupply) ERC20("Pepe", "PEPE") {
//         _mint(msg.sender, _totalSupply);
//     }

//     /**
//      * @dev 设置地址的黑名单状态。
//      * @param _address 目标地址
//      * @param _isBlacklisting 是否加入黑名单
//      */
//     function blacklist(
//         address _address,
//         bool _isBlacklisting
//     ) external onlyOwner {
//         blacklists[_address] = _isBlacklisting;
//     }

//     /**
//      * @dev 设置交易规则。
//      * @param _limited 是否启用交易限制
//      * @param _uniswapV2Pair Uniswap V2 交易对地址
//      * @param _maxHoldingAmount 最大持有量限制
//      * @param _minHoldingAmount 最小持有量限制
//      */
//     function setRule(
//         bool _limited,
//         address _uniswapV2Pair,
//         uint256 _maxHoldingAmount,
//         uint256 _minHoldingAmount
//     ) external onlyOwner {
//         limited = _limited;
//         uniswapV2Pair = _uniswapV2Pair;
//         maxHoldingAmount = _maxHoldingAmount;
//         minHoldingAmount = _minHoldingAmount;
//     }

//     /**
//      * @dev 在代币转账前执行检查，包括黑名单和交易限制。
//      * @param from 发送方地址
//      * @param to 接收方地址
//      * @param amount 转账数量
//      */
//     function _beforeTokenTransfer(
//         address from,
//         address to,
//         uint256 amount
//     ) internal virtual override {
//         // 检查发送方或接收方是否在黑名单中
//         require(!blacklists[to] && !blacklists[from], "Blacklisted");

//         // 如果未设置交易对地址，仅允许合约所有者进行转账
//         if (uniswapV2Pair == address(0)) {
//             require(from == owner() || to == owner(), "trading is not started");
//             return;
//         }
//         // 如果启用交易限制且发送方是交易对地址，检查接收方的持有量限制
//         if (limited && from == uniswapV2Pair) {
//             require(
//                 super.balanceOf(to) + amount <= maxHoldingAmount &&
//                     super.balanceOf(to) + amount >= minHoldingAmount,
//                 "Forbid"
//             );
//         }
//     }

//     /**
//      * @dev 销毁指定数量的代币。
//      * @param value 销毁的代币数量
//      */
//     function burn(uint256 value) external {
//         _burn(msg.sender, value);
//     }
// }
