// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 将两个有序数组合并为一个有序数组。
contract MergeArray {
    function mergeSortedArrays(uint256[] memory arr1, uint256[] memory arr2)
        public
        pure
        returns (uint256[] memory)
    {
        uint256 size = arr1.length + arr2.length;
        uint256[] memory mergeArr = new uint256[](size);

        uint256 i = 0;
        uint256 j = 0;
        uint256 k = 0;
        // [1, 3, 5]
        // [2 ,4, 6]
        for (; i < arr1.length && j < arr2.length; k++) {
            if (arr1[i] < arr2[j]) {
                mergeArr[k] = arr1[i];
                i++;
            } else {
                mergeArr[k] = arr2[j];
                j++;
            }
        }

        for (; i < arr1.length; i++) {
            mergeArr[k] = arr1[i];
            k++;
        }

        for (; j < arr2.length; j++) {
            mergeArr[k] = arr2[j];
            k++;
        }
        return mergeArr;
    }
}
