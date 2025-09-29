// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
/*
任务目标
    使用 Solidity 编写一个合约，允许用户向合约地址发送以太币。
    记录每个捐赠者的地址和捐赠金额。
    允许合约所有者提取所有捐赠的资金。

任务步骤
编写合约
    创建一个名为 BeggingContract 的合约。
    合约应包含以下功能：
    一个 mapping 来记录每个捐赠者的捐赠金额。
    一个 donate 函数，允许用户向合约发送以太币，并记录捐赠信息。
    一个 withdraw 函数，允许合约所有者提取所有资金。
    一个 getDonation 函数，允许查询某个地址的捐赠金额。
    使用 payable 修饰符和 address.transfer 实现支付和提款。
部署合约
    在 Remix IDE 中编译合约。
    部署合约到 Goerli 或 Sepolia 测试网。
测试合约
    使用 MetaMask 向合约发送以太币，测试 donate 功能。
    调用 withdraw 函数，测试合约所有者是否可以提取资金。
    调用 getDonation 函数，查询某个地址的捐赠金额。

任务要求
合约代码：
    使用 mapping 记录捐赠者的地址和金额。
    使用 payable 修饰符实现 donate 和 withdraw 函数。
    使用 onlyOwner 修饰符限制 withdraw 函数只能由合约所有者调用。
测试网部署：
    合约必须部署到 Goerli 或 Sepolia 测试网。
功能测试：
    确保 donate、withdraw 和 getDonation 函数正常工作。

提交内容
    合约代码：提交 Solidity 合约文件（如 BeggingContract.sol）。
    合约地址：提交部署到测试网的合约地址。
    测试截图：提交在 Remix 或 Etherscan 上测试合约的截图。

额外挑战（可选）
    捐赠事件：添加 Donation 事件，记录每次捐赠的地址和金额。
    捐赠排行榜：实现一个功能，显示捐赠金额最多的前 3 个地址。
    时间限制：添加一个时间限制，只有在特定时间段内才能捐赠。
*/
import "@openzeppelin/contracts/utils/Arrays.sol";

contract BeggingContract {
    // 合约所有者
    address public owner;
    // 一个 mapping 来记录每个捐赠者的捐赠金额。
    mapping(address => uint256) private donations;

    // 添加 Donation 事件，记录每次捐赠的地址和金额。
    event donateLog(address user, uint256 amount);

    // 添加一个时间限制，只有在特定时间段内才能捐赠。
    uint256 private start;
    uint256 private end;

    // 捐赠者信息结构体
    struct User {
        address account;
        uint256 amount;
    }

    User[] private allUsers;

    constructor(uint256 _start, uint256 _end) {
        owner = msg.sender;
        start = _start;
        end = _end;
    }

    // 只有所有者可以调用
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    // 只有在特定时间段内才能捐赠。
    modifier checkTime() {
        require(
            block.timestamp > start && block.timestamp < end,
            "concurrent time can not operate function"
        );
        _;
    }

    receive() external payable {}

    // 一个 donate 函数，允许用户向合约发送以太币，并记录捐赠信息。
    function donate(uint256 amount) external payable checkTime {
        require(msg.sender != address(0), "address error");

        donations[msg.sender] += amount;

        bool exist = false;
        if (allUsers.length == 0) {
            allUsers.push(User(msg.sender, amount));
            exist = true;
        } else {
            for (uint256 i = 0; i < allUsers.length; i++) {
                if (allUsers[i].account == msg.sender) {
                    allUsers[i].amount = donations[msg.sender];
                    exist = true;
                    break;
                }
            }
        }
        if (!exist) {
            allUsers.push(User(msg.sender, amount));
        }

        emit donateLog(msg.sender, amount);
    }

    // 一个 withdraw 函数，允许合约所有者提取所有资金。
    function withdraw() external payable onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = payable(owner).call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    // 一个 getDonation 函数，允许查询某个地址的捐赠金额。
    function getDonation(address user) external view returns (uint256) {
        return donations[user];
    }

    function getOwnerBalance() external view returns (uint256) {
        return owner.balance;
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // 实现一个功能，显示捐赠金额最多的前 3 个地址。
    function getTop3User() external view returns (address[] memory) {
        if (allUsers.length == 0) {
            return new address[](0);
        }

        User[] memory sortedUser = new User[](allUsers.length);
        for (uint256 i = 0; i < allUsers.length; i++) {
            sortedUser[i] = allUsers[i];
        }

        // 冒泡排序
        for (uint256 i = 0; i < sortedUser.length - 1; i++) {
            for (uint256 j = 0; j < sortedUser.length - i - 1; j++) {
                if (sortedUser[j].amount < sortedUser[j + 1].amount) {
                    User memory temp = sortedUser[j];
                    sortedUser[j] = sortedUser[j + 1];
                    sortedUser[j + 1] = temp;
                }
            }
        }

        uint256 count = 3;
        if (sortedUser.length < count) {
            count = sortedUser.length;
        }

        address[] memory top3 = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            top3[i] = sortedUser[i].account;
        }

        return top3;
    }

    function test() public view returns(uint256) {
        return allUsers.length;
    }
}
