// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";

// import "./ITaxHandler.sol";
// import "./ITreasuryHandler.sol";
// import "./IGovernanceToken.sol";

// /**
//  * @title Floki 代币合约
//  * @dev Floki 代币具有模块化的税收和资金处理系统以及治理功能。
//  */
// contract FLOKI is IERC20, IGovernanceToken, Ownable {
//     /// @dev 用户代币余额的注册表。
//     mapping(address => uint256) private _balances;

//     /// @dev 用户授权的地址注册表。
//     mapping(address => mapping(address => uint256)) private _allowances;

//     /// @notice 用户治理委托的注册表。
//     mapping(address => address) public delegates;

//     /// @notice 投票委托的随机数注册表。
//     mapping(address => uint256) public nonces;

//     /// @notice 账户余额检查点数量的注册表。
//     mapping(address => uint32) public numCheckpoints;

//     /// @notice 每个账户的余额检查点注册表。
//     mapping(address => mapping(uint32 => Checkpoint)) public checkpoints;

//     /// @notice 合约域的 EIP-712 类型哈希。
//     bytes32 public constant DOMAIN_TYPEHASH =
//         keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

//     /// @notice 合约使用的委托结构的 EIP-712 类型哈希。
//     bytes32 public constant DELEGATION_TYPEHASH =
//         keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

//     /// @notice 实现税收计算的合约。
//     ITaxHandler public taxHandler;

//     /// @notice 执行资金相关操作的合约。
//     ITreasuryHandler public treasuryHandler;

//     /// @notice 当税收处理合约更改时触发的事件。
//     event TaxHandlerChanged(address oldAddress, address newAddress);

//     /// @notice 当资金处理合约更改时触发的事件。
//     event TreasuryHandlerChanged(address oldAddress, address newAddress);

//     /// @dev 代币名称。
//     string private _name;

//     /// @dev 代币符号。
//     string private _symbol;

//     /**
//      * @param name_ 代币名称。
//      * @param symbol_ 代币符号。
//      * @param taxHandlerAddress 初始税收处理合约地址。
//      * @param treasuryHandlerAddress 初始资金处理合约地址。
//      */
//     constructor(
//         string memory name_,
//         string memory symbol_,
//         address taxHandlerAddress,
//         address treasuryHandlerAddress
//     ) {
//         _name = name_;
//         _symbol = symbol_;

//         taxHandler = ITaxHandler(taxHandlerAddress);
//         treasuryHandler = ITreasuryHandler(treasuryHandlerAddress);

//         _balances[_msgSender()] = totalSupply();

//         emit Transfer(address(0), _msgSender(), totalSupply());
//     }

//     /**
//      * @notice 获取代币名称。
//      * @return 代币名称。
//      */
//     function name() public view returns (string memory) {
//         return _name;
//     }

//     /**
//      * @notice 获取代币符号。
//      * @return 代币符号。
//      */
//     function symbol() external view returns (string memory) {
//         return _symbol;
//     }

//     /**
//      * @notice 获取代币使用的小数位数。
//      * @return 代币使用的小数位数。
//      */
//     function decimals() external pure returns (uint8) {
//         return 9;
//     }

//     /**
//      * @notice 获取代币的最大供应量。
//      * @return 代币的最大供应量。
//      */
//     function totalSupply() public pure override returns (uint256) {
//         // 十万亿，即 10,000,000,000,000 个代币。
//         return 1e13 * 1e9;
//     }

//     /**
//      * @notice 获取给定账户的代币余额。
//      * @param account 要检索余额的地址。
//      * @return `account` 拥有的代币数量。
//      */
//     function balanceOf(address account) external view override returns (uint256) {
//         return _balances[account];
//     }

//     /**
//      * @notice 将调用者的代币转移到另一个地址。
//      * @param recipient 接收代币的地址。
//      * @param amount 要转移的代币数量。
//      * @return 如果转移成功，则返回 true，否则会引发错误。
//      */
//     function transfer(address recipient, uint256 amount) external override returns (bool) {
//         _transfer(_msgSender(), recipient, amount);
//         return true;
//     }

//     /**
//      * @notice 获取 `owner` 授权给 `spender` 的额度。
//      * @param owner 代币所有者地址。
//      * @param spender 被授权代表 `owner` 花费代币的地址。
//      * @return `owner` 授权给 `spender` 的额度。
//      */
//     function allowance(address owner, address spender) external view override returns (uint256) {
//         return _allowances[owner][spender];
//     }

//     /**
//      * @notice 授权地址花费调用者的代币。
//      * @dev 如果 `spender` 的额度已经非零，则此方法可能被恶意利用。
//      * 详情请参阅：https://docs.google.com/document/d/1YLPtQxZu1UAvO9cZ1O2RPXBbT0mooh4DYKjA_jp-RLM/edit。
//      * 如果 `spender` 之前已被授权，请确保其可信后再调用此方法。
//      * 否则，请使用 `increaseAllowance` 或 `decreaseAllowance` 方法，或先将额度设置为零，再设置新额度。
//      * @param spender 被授权花费代币的地址。
//      * @param amount `spender` 被允许花费的代币数量。
//      * @return 如果授权成功，则返回 true，否则会引发错误。
//      */
//     function approve(address spender, uint256 amount) external override returns (bool) {
//         _approve(_msgSender(), spender, amount);
//         return true;
//     }

//     /**
//      * @notice 从一个地址转移代币到另一个地址。
//      * @param sender 代币来源地址。
//      * @param recipient 接收代币的地址。
//      * @param amount 要转移的代币数量。
//      * @return 如果转移成功，则返回 true，否则会引发错误。
//      */
//     function transferFrom(
//         address sender,
//         address recipient,
//         uint256 amount
//     ) external override returns (bool) {
//         _transfer(sender, recipient, amount);

//         uint256 currentAllowance = _allowances[sender][_msgSender()];
//         require(
//             currentAllowance >= amount,
//             "FLOKI:transferFrom:ALLOWANCE_EXCEEDED: 转移数量超过授权额度。"
//         );
//         unchecked {
//             _approve(sender, _msgSender(), currentAllowance - amount);
//         }

//         return true;
//     }

//     /**
//      * @notice 增加 `spender` 的授权额度。
//      * @param spender 被授权花费代币的地址。
//      * @param addedValue 要增加的额度数量。
//      * @return 如果额度增加成功，则返回 true，否则会引发错误。
//      */
//     function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
//         _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);

//         return true;
//     }

//     /**
//      * @notice 减少 `spender` 的授权额度。
//      * @param spender 被授权花费代币的地址。
//      * @param subtractedValue 要减少的额度数量。
//      * @return 如果额度减少成功，则返回 true，否则会引发错误。
//      */
//     function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
//         uint256 currentAllowance = _allowances[_msgSender()][spender];
//         require(
//             currentAllowance >= subtractedValue,
//             "FLOKI:decreaseAllowance:ALLOWANCE_UNDERFLOW: 减法结果导致负额度。"
//         );
//         unchecked {
//             _approve(_msgSender(), spender, currentAllowance - subtractedValue);
//         }

//         return true;
//     }

//     /**
//      * @notice 将投票权委托给指定地址。
//      * @dev 注意，想要自己投票的用户也需要调用此方法，尽管是委托给自己。
//      * @param delegatee 被委托投票的地址。
//      */
//     function delegate(address delegatee) external {
//         return _delegate(msg.sender, delegatee);
//     }

//     /**
//      * @notice 通过签名将投票权从签名者委托给 `delegatee`。
//      * @param delegatee 被委托的地址（接收投票权）
//      * @param nonce 随机数（防止签名重放）
//      * @param expiry 签名过期时间（时间戳）
//      * @param v 签名的 v 值（ECDSA 签名的一部分）
//      * @param r 签名的 r 值（ECDSA 签名的一部分）
//      * @param s 签名的 s 值（ECDSA 签名的一部分）
//      */
//     function delegateBySig(
//         address delegatee,
//         uint256 nonce,
//         uint256 expiry,
//         uint8 v,
//         bytes32 r,
//         bytes32 s
//     ) external {
//         bytes32 domainSeparator = keccak256(
//             abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name())), block.chainid, address(this))
//         );
//         bytes32 structHash = keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry));
//         bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
//         address signatory = ecrecover(digest, v, r, s);

//         require(signatory != address(0), "FLOKI:delegateBySig:INVALID_SIGNATURE: 收到的签名无效。");
//         require(block.timestamp <= expiry, "FLOKI:delegateBySig:EXPIRED_SIGNATURE: 收到的签名已过期。");
//         require(nonce == nonces[signatory]++, "FLOKI:delegateBySig:INVALID_NONCE: 收到的随机数无效。");

//         return _delegate(signatory, delegatee);
//     }

//     /**
//      * @notice 获取账户在指定区块的投票数量。
//      * @dev 区块号必须是已确认的区块，否则此函数将回滚以防止误导信息。
//      * @param account 要检查的账户地址。
//      * @param blockNumber 要获取投票余额的区块号。
//      * @return 账户在给定区块的投票数量。
//      */
//     function getVotesAtBlock(address account, uint32 blockNumber) public view returns (uint224) {
//         require(
//             blockNumber < block.number,
//             "FLOKI:getVotesAtBlock:FUTURE_BLOCK: 无法获取未来区块的投票。"
//         );

//         uint32 nCheckpoints = numCheckpoints[account];
//         if (nCheckpoints == 0) {
//             return 0;
//         }

//         // 首先检查最近的余额。
//         if (checkpoints[account][nCheckpoints - 1].blockNumber <= blockNumber) {
//             return checkpoints[account][nCheckpoints - 1].votes;
//         }

//         // 接下来检查隐式零余额。
//         if (checkpoints[account][0].blockNumber > blockNumber) {
//             return 0;
//         }

//         // 执行二分查找。
//         uint32 lowerBound = 0;
//         uint32 upperBound = nCheckpoints - 1;
//         while (upperBound > lowerBound) {
//             uint32 center = upperBound - (upperBound - lowerBound) / 2;
//             Checkpoint memory checkpoint = checkpoints[account][center];

//             if (checkpoint.blockNumber == blockNumber) {
//                 return checkpoint.votes;
//             } else if (checkpoint.blockNumber < blockNumber) {
//                 lowerBound = center;
//             } else {
//                 upperBound = center - 1;
//             }
//         }

//         // 未找到确切的区块号。使用该区块号之前的最后一个已知余额。
//         return checkpoints[account][lowerBound].votes;
//     }

//     /**
//      * @notice 设置新的税收处理合约。
//      * @param taxHandlerAddress 新的税收处理合约地址。
//      */
//     function setTaxHandler(address taxHandlerAddress) external onlyOwner {
//         address oldTaxHandlerAddress = address(taxHandler);
//         taxHandler = ITaxHandler(taxHandlerAddress);

//         emit TaxHandlerChanged(oldTaxHandlerAddress, taxHandlerAddress);
//     }

//     /**
//      * @notice 设置新的资金处理合约。
//      * @param treasuryHandlerAddress 新的资金处理合约地址。
//      */
//     function setTreasuryHandler(address treasuryHandlerAddress) external onlyOwner {
//         address oldTreasuryHandlerAddress = address(treasuryHandler);
//         treasuryHandler = ITreasuryHandler(treasuryHandlerAddress);

//         emit TreasuryHandlerChanged(oldTreasuryHandlerAddress, treasuryHandlerAddress);
//     }

//     /**
//      * @notice 将一个地址的投票权委托给另一个地址。
//      * @param delegator 委托投票的来源地址。
//      * @param delegatee 被委托投票的地址。
//      */
//     function _delegate(address delegator, address delegatee) private {
//         address currentDelegate = delegates[delegator];
//         uint256 delegatorBalance = _balances[delegator];
//         delegates[delegator] = delegatee;

//         emit DelegateChanged(delegator, currentDelegate, delegatee);

//         _moveDelegates(currentDelegate, delegatee, uint224(delegatorBalance));
//     }

//     /**
//      * @notice 将投票权从一个地址转移到另一个地址。
//      * @param from 投票权来源地址。
//      * @param to 投票权目标地址。
//      * @param amount 要转移的投票权数量。
//      */
//     function _moveDelegates(
//         address from,
//         address to,
//         uint224 amount
//     ) private {
//         // 如果投票权实际上是在相同的代表之间转移，则无需更新检查点。
//         // 例如，代币在两个委托给同一地址的账户之间转移时会出现这种情况。
//         if (from == to) {
//             return;
//         }

//         // 有些用户会预先委托投票权（即在拥有代币之前）。在这种情况下无需更新检查点。
//         if (amount == 0) {
//             return;
//         }

//         if (from != address(0)) {
//             uint32 fromRepNum = numCheckpoints[from];
//             uint224 fromRepOld = fromRepNum > 0 ? checkpoints[from][fromRepNum - 1].votes : 0;
//             uint224 fromRepNew = fromRepOld - amount;

//             _writeCheckpoint(from, fromRepNum, fromRepOld, fromRepNew);
//         }

//         if (to != address(0)) {
//             uint32 toRepNum = numCheckpoints[to];
//             uint224 toRepOld = toRepNum > 0 ? checkpoints[to][toRepNum - 1].votes : 0;
//             uint224 toRepNew = toRepOld + amount;

//             _writeCheckpoint(to, toRepNum, toRepOld, toRepNew);
//         }
//     }

//     /**
//      * @notice 将余额检查点写入链上。
//      * @param delegatee 要写入检查点的地址。
//      * @param nCheckpoints `delegatee` 已有的检查点数量。
//      * @param oldVotes 此检查点之前的投票数量。
//      * @param newVotes `delegatee` 现在拥有的投票数量。
//      */
//     function _writeCheckpoint(
//         address delegatee,
//         uint32 nCheckpoints,
//         uint224 oldVotes,
//         uint224 newVotes
//     ) private {
//         uint32 blockNumber = uint32(block.number);

//         if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].blockNumber == blockNumber) {
//             checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
//         } else {
//             checkpoints[delegatee][nCheckpoints] = Checkpoint(blockNumber, newVotes);
//             numCheckpoints[delegatee] = nCheckpoints + 1;
//         }

//         emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
//     }

//     /**
//      * @notice 代表所有者授权 `spender`。
//      * @param owner 代币所有者地址。
//      * @param spender 被授权花费代币的地址。
//      * @param amount `spender` 被允许花费的代币数量。
//      */
//     function _approve(
//         address owner,
//         address spender,
//         uint256 amount
//     ) private {
//         require(owner != address(0), "FLOKI:_approve:OWNER_ZERO: 不能为零地址授权。");
//         require(spender != address(0), "FLOKI:_approve:SPENDER_ZERO: 不能授权给零地址。");

//         _allowances[owner][spender] = amount;

//         emit Approval(owner, spender, amount);
//     }

//     /**
//      * @notice 从账户 `from` 转移 `amount` 个代币到账户 `to`。
//      * @param from 代币来源地址。
//      * @param to 代币目标地址。
//      * @param amount 要转移的代币数量。
//      */
//     function _transfer(
//         address from,
//         address to,
//         uint256 amount
//     ) private {
//         require(from != address(0), "FLOKI:_transfer:FROM_ZERO: 不能从零地址转移。");
//         require(to != address(0), "FLOKI:_transfer:TO_ZERO: 不能转移到零地址。");
//         require(amount > 0, "FLOKI:_transfer:ZERO_AMOUNT: 转移数量必须大于零。");
//         require(amount <= _balances[from], "FLOKI:_transfer:INSUFFICIENT_BALANCE: 转移数量超过余额。");

//         treasuryHandler.beforeTransferHandler(from, to, amount);

//         uint256 tax = taxHandler.getTax(from, to, amount);
//         uint256 taxedAmount = amount - tax;

//         _balances[from] -= amount;
//         _balances[to] += taxedAmount;
//         _moveDelegates(delegates[from], delegates[to], uint224(taxedAmount));

//         if (tax > 0) {
//             _balances[address(treasuryHandler)] += tax;

//             _moveDelegates(delegates[from], delegates[address(treasuryHandler)], uint224(tax));

//             emit Transfer(from, address(treasuryHandler), tax);
//         }

//         treasuryHandler.afterTransferHandler(from, to, amount);

//         emit Transfer(from, to, taxedAmount);
//     }
// }