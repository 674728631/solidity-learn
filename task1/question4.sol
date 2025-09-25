// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 整数转罗马数字
// 七个不同的符号代表罗马数字，其值如下：

// 符号	值
// I	1
// V	5
// X	10
// L	50
// C	100
// D	500
// M	1000
// 罗马数字是通过添加从最高到最低的小数位值的转换而形成的。将小数位值转换为罗马数字有以下规则：

// 如果该值不是以 4 或 9 开头，请选择可以从输入中减去的最大值的符号，将该符号附加到结果，减去其值，然后将其余部分转换为罗马数字。
// 如果该值以 4 或 9 开头，使用 减法形式，表示从以下符号中减去一个符号，例如 4 是 5 (V) 减 1 (I): IV ，9 是 10 (X) 减 1 (I)：IX。
// 仅使用以下减法形式：4 (IV)，9 (IX)，40 (XL)，90 (XC)，400 (CD) 和 900 (CM)。
// 只有 10 的次方（I, X, C, M）最多可以连续附加 3 次以代表 10 的倍数。你不能多次附加 5 (V)，50 (L) 或 500 (D)。如果需要将符号附加4次，请使用 减法形式。
// 给定一个整数，将其转换为罗马数字。
contract Int2RomanNumber {
    mapping(bytes1 => uint256) private charMapping;

    function parse(uint256 input) public pure returns (string memory) {
        if (input < 0 || input > 3999) {
            return "";
        }
        string memory output = "";

        uint256 q = input / 1000;
        if (q > 0) {
            for (uint8 i = 0; i < q; i++) {
                output = string.concat(output, "M");
            }
        }
        input -= q * 1000;
        uint256 b = input / 100;
        if (b > 0) {
            if (b < 4) {
                for (uint8 i = 0; i < b; i++) {
                    output = string.concat(output, "C");
                }
            } else if (b == 4) {
                output = string.concat(output, "CD");
            } else if (b < 9) {
                output = string.concat(output, "D");
                for (uint8 i = 0; i < (b - 5); i++) {
                    output = string.concat(output, "C");
                }
            } else {
                output = string.concat(output, "CM");
            }
        }

        input -= b * 100;
        uint256 s = input / 10;
        if (s > 0) {
            if (s < 4) {
                for (uint8 i = 0; i < s; i++) {
                    output = string.concat(output, "X");
                }
            } else if (s == 4) {
                output = string.concat(output, "XL");
            } else if (s < 9) {
                output = string.concat(output, "L");
                for (uint8 i = 0; i < (s - 5); i++) {
                    output = string.concat(output, "X");
                }
            } else {
                output = string.concat(output, "XC");
            }
        }

        input -= s * 10;
        if (input > 0) {
            if (input < 4) {
                for (uint8 i = 0; i < input; i++) {
                    output = string.concat(output, "I");
                }
            } else if (input == 4) {
                output = string.concat(output, "IV");
            } else if (input < 9) {
                output = string.concat(output, "V");
                for (uint8 i = 0; i < (input - 5); i++) {
                    output = string.concat(output, "I");
                }
            } else {
                output = string.concat(output, "IX");
            }
        }

        return output;
    }
}
