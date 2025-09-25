// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 二分查找 (Binary Search) : 在一个有序数组中查找目标值。
contract BinarySearch {
    function binarySearch(uint256[] memory arr, uint256 target)
        public
        pure
        returns (int256)
    {
        // [1,3,5,6,7]
        uint256 left = 0;
        uint256 rigth = arr.length;

        while (left < rigth) {
            uint256 mid = left + (rigth - left) / 2;
            if (arr[mid] == target) {
                return int256(mid);
            } else if (arr[mid] < target) {
                left = mid + 1;
            } else {
                rigth = mid;
            }
        }

        return -1;
    }
}
