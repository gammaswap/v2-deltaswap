// SPDX-License-Identifier: GPL-v3
pragma solidity =0.8.17;

import '../UniswapV2ERC20.sol';

contract ERC20 is UniswapV2ERC20 {
    constructor(uint256 _totalSupply) {
        _mint(msg.sender, _totalSupply);
    }
}