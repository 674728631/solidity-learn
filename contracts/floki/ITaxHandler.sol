// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.11;

// /**
//  * @title 税务处理接口
//  * @dev 任何实现此接口的类都可以用于协议特定的税务计算。
//  */
// interface ITaxHandler {
//     /**
//      * @notice 获取需要支付的代币数量作为税务。
//      * @param benefactor 支付方的地址。
//      * @param beneficiary 受益方的地址。
//      * @param amount 转账的代币数量。
//      * @return 需要支付的代币数量作为税务。
//      */
//     function getTax(
//         address benefactor,
//         address beneficiary,
//         uint256 amount
//     ) external view returns (uint256);
// }