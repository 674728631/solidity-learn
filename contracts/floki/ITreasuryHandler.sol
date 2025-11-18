// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// /**
//  * @title 金库处理接口
//  * @dev 任何实现此接口的类都可以用于与金库相关的协议特定操作。
//  */
// interface ITreasuryHandler {
//     /**
//      * @notice 在转账执行前执行操作。
//      * @param benefactor 转账发起者地址。
//      * @param beneficiary 转账接收者地址。
//      * @param amount 转账的代币数量。
//      */
//     function beforeTransferHandler(
//         address benefactor,
//         address beneficiary,
//         uint256 amount
//     ) external;

//     /**
//      * @notice 在转账执行后执行操作。
//      * @param benefactor 转账发起者地址。
//      * @param beneficiary 转账接收者地址。
//      * @param amount 转账的代币数量。
//      */
//     function afterTransferHandler(
//         address benefactor,
//         address beneficiary,
//         uint256 amount
//     ) external;
// }