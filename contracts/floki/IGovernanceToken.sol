// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// /**
//  * @title 治理代币接口。
//  */
// interface IGovernanceToken {
//     /// @notice 用于标记某个区块的投票数的检查点。
//     struct Checkpoint {
//         // 32位无符号整数在以下链的预估日期前有效：
//         //  - BSC: 2428年12月23日 18:23:11 UTC
//         //  - ETH: 3826年4月18日 09:27:12 UTC
//         // 此假设基于区块挖矿速率不会加快。
//         uint32 blockNumber;
//         // 此类型设置为 `uint224` 以优化目的（即，特别适合32字节的区块）。
//         // 假设实现治理代币的投票数永远不会超过224位数的最大值。
//         uint224 votes;
//     }

//     /**
//      * @notice 确定某个账户在特定区块的投票数。
//      * @dev 区块号必须是已确认的区块，否则此函数将回滚以防止错误信息。
//      * @param account 要检查的账户地址。
//      * @param blockNumber 获取投票数的区块号。
//      * @return 该账户在给定区块的投票数。
//      */
//     function getVotesAtBlock(address account, uint32 blockNumber) external view returns (uint224);

//     /// @notice 当为账户设置新委托时触发。
//     event DelegateChanged(address delegator, address currentDelegate, address newDelegate);

//     /// @notice 当委托人的投票数发生变化时触发。
//     event DelegateVotesChanged(address delegatee, uint224 oldVotes, uint224 newVotes);
// }