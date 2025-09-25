// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

contract Voting {
    // 一个mapping来存储候选人的得票数
    mapping(string => uint256) public voteMapping;

    string[] private allUser;

    // 一个vote函数，允许用户投票给某个候选人
    function vote(string memory name, uint256 voteCount) public {
        voteMapping[name] += voteCount;
        allUser.push(name);
    }

    // 一个getVotes函数，返回某个候选人的得票数
    function getVotes(string memory name) public view returns (uint256) {
        return voteMapping[name];
    }

    // 一个resetVotes函数，重置所有候选人的得票数
    function resetVotes() public {
        for (uint256 i = 0; i < allUser.length; i++) {
            voteMapping[allUser[i]] = 0;
        }
    }
}
