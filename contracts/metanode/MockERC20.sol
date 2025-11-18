// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20{
    constructor() ERC20("MockERC20", "MC"){
        _mint(msg.sender, 10_0000);
    }
}