// SPDX-License-Identifier: GPL-v3
pragma solidity =0.8.21;

import '../DeltaSwapV2ERC20.sol';

contract ERC20 is DeltaSwapV2ERC20 {
    constructor(uint256 _totalSupply) {
        _initializeDomainSeparator();
        _mint(msg.sender, _totalSupply);
    }
}