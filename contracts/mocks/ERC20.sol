//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SPHERON is ERC20 {
    constructor(uint256 initialSupply) ERC20("Test SPHERON", "SPHE") {
        _mint(msg.sender, initialSupply);
    }
}