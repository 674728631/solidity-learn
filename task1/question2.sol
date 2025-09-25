// SPDX-License-Identifier: MIT
pragma solidity ~0.8.21;

// 反转字符串 (Reverse String)
// 题目描述：反转一个字符串。输入 "abcde"，输出 "edcba"
contract ReverseString {
    function reverse(string memory input) public pure returns (string memory) {
        bytes memory strBytes = bytes(input);
        bytes memory output = new bytes(strBytes.length);
        for (uint256 i = 0; i < strBytes.length - 1; i++) {
            output[i] = strBytes[strBytes.length - 1 - i];
        }
        return string(output);
    }
}
