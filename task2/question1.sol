// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// 任务：参考 openzeppelin-contracts/contracts/token/ERC20/IERC20.sol实现一个简单的 ERC20 代币合约。要求：
// 合约包含以下标准 ERC20 功能：
// balanceOf：查询账户余额。
// transfer：转账。
// approve 和 transferFrom：授权和代扣转账。
// 使用 event 记录转账和授权操作。
// 提供 mint 函数，允许合约所有者增发代币。

contract MyERC20  {

    string private _name;
    string private _symbol;

    // 所有者地址
    address public owner;
    uint256 private totalSupply;

    constructor() {
        _name="MyToken";
        _symbol="MTK";
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner,"only owner can call this function");
        _;
    }

    // 账户余额
    mapping(address account => uint256) private _balances;
    // 授权额度
    mapping(address account => mapping(address spender => uint256)) private _allowances;
    // 日志
    event TransferLog(address indexed from, address indexed to, uint256 value);
    event ApprovalLog(address indexed owner, address indexed spender, uint256 value);

    // mint函数
    function mint(address to, uint256 amount) public onlyOwner {
        require(to !=address(0),"receive address error");
        require(amount > 0, "amount must be greater than 0");
        _balances[to] += amount;
        totalSupply += amount;
    }


    // 余额查询函数
    function balanceOf(address account) public view returns (uint256) {
        require(account !=address(0),"receive address error");
        return _balances[account];
    }

    // 转账函数
    function transfer(address to, uint256 amount) public returns (bool) {
        // 参数判断
        require(to !=address(0),"receive address error");
        require(amount > 0,"amount must greet than 0");

        // 检查余额
        uint256 ownerValue = _balances[msg.sender];
        if (ownerValue < amount) {
            revert("owner balance not enough");
        } else {
            // 扣款
            _balances[msg.sender] -= amount;
        }
        // 转账
        _balances[to] += amount;

        // 日志
        emit TransferLog(msg.sender, to, amount);
        return true;
    }

    // 授权函数
    function approve(address spender, uint256 amount)  public returns (bool) {
        // 参数判断
        require(spender !=address(0),"spender address error");
        require(amount > 0,"amount must greet than 0");

        _allowances[msg.sender][spender] = amount;

        emit ApprovalLog(msg.sender, spender, amount);
        return true;
    }

    // 转账函数
    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        // 参数判断
        require(from !=address(0),"from address error");
        require(to !=address(0),"to address error");
        require(amount > 0,"amount must greet than 0");
        // 授权额度不足
        require(_allowances[from][msg.sender] >= amount,"allowance exceeded");

        // 检查余额
        uint256 ownerValue = _balances[from];
        if (ownerValue < amount) {
            revert("owner balance not enough");
        } else {
            // 扣款
            _balances[from] -= amount;
        }
        // 转账
        _balances[to] += amount;
        _allowances[from][msg.sender] -= amount;

        // 日志
        emit TransferLog(from, to, amount);
        return true;
    }
}
