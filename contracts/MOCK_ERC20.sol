// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MOCK_ERC20 is ERC20{
    
    constructor(string memory name, string memory symbol, uint initialSupply ) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
}