// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

// 罗马数字转整数
// 罗马数字包含以下七种字符: I， V， X， L，C，D 和 M。
// 字符          数值
// I             1
// V             5
// X             10
// L             50
// C             100
// D             500
// M             1000
// 例如， 罗马数字 2 写做 II ，即为两个并列的 1 。12 写做 XII ，即为 X + II 。 27 写做  XXVII, 即为 XX + V + II 。
// 通常情况下，罗马数字中小的数字在大的数字的右边。但也存在特例，例如 4 不写做 IIII，而是 IV。数字 1 在数字 5 的左边，所表示的数等于大数 5 减小数 1 得到的数值 4 。
// 同样地，数字 9 表示为 IX。这个特殊的规则只适用于以下六种情况：

// I 可以放在 V (5) 和 X (10) 的左边，来表示 4 和 9。
// X 可以放在 L (50) 和 C (100) 的左边，来表示 40 和 90。
// C 可以放在 D (500) 和 M (1000) 的左边，来表示 400 和 900。
// 给定一个罗马数字，将其转换成整数。
contract RomanNumber2Int {
    mapping(bytes1 => uint256) private charMapping;

    constructor() {
        charMapping["I"] = 1;
        charMapping["V"] = 5;
        charMapping["X"] = 10;
        charMapping["L"] = 50;
        charMapping["C"] = 100;
        charMapping["D"] = 500;
        charMapping["M"] = 1000;
    }

    function parse(string calldata input) public view returns (uint256) {
        bytes memory inputBytes = bytes(input);
        uint256 total = 0;

        for (uint256 i = 0; i < inputBytes.length; i++) {
            bytes1 char = inputBytes[i];
            uint256 value = charMapping[char];
            if (value == 0) {
                return 0;
            }
            uint256 valueNext = 0;
            if (i < inputBytes.length - 1) {
                valueNext = charMapping[inputBytes[i + 1]];
            }

            if (value < valueNext) {
                uint256 twoValue = 0;
                // I 可以放在 V (5) 和 X (10) 的左边
                if (value == 1 && (valueNext == 5 || valueNext == 10)) {
                    twoValue = valueNext - value;
                }
                // X 可以放在 L (50) 和 C (100) 的左边
                else if (value == 10 && (valueNext == 50 || valueNext == 100)) {
                    twoValue = valueNext - value;
                }
                // C 可以放在 D (500) 和 M (1000) 的左边
                else if (
                    value == 100 && (valueNext == 500 || valueNext == 1000)
                ) {
                    twoValue = valueNext - value;
                }
                if (twoValue == 0) {
                    return 0;
                }
                value = twoValue;
                i++;
            }
            if (value > 0) {
                total += value;
            }
        }
        return total;
    }
}
