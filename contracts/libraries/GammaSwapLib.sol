// SPDX-License-Identifier: GPL-v3
pragma solidity ^0.8.0;

import './Math.sol';

library GammaSwapLib {

    function calcTradingFee(uint256 lastLiquidityTradedEMA, uint256 lastLiquidityEMA) internal view returns(uint256) {
        if(lastLiquidityTradedEMA >= lastLiquidityEMA * 500 / 10000) { // if trade > 5% of liquidity, charge 0.1% fee => ~2.5% of liquidity value, ~10% px change
            if(lastLiquidityTradedEMA >= lastLiquidityEMA * 1000 / 10000) { // if trade > 10% of liquidity, charge 0.3% fee => ~5% of liquidity value, ~20% px change
                if(lastLiquidityTradedEMA >= lastLiquidityEMA * 2000 / 10000) {// if trade > 20% of liquidity, charge 1% fee => ~10% of liquidity value, ~40% px change
                    return 3;
                }
                return 2;
            }
            return 1;
        }
        return 0;
    }

    function calcTradeLiquidity(uint256 amount0, uint256 amount1, uint256 reserve0, uint256 reserve1) internal pure returns(uint256) {
        if(amount0 > 0) {
            return Math.sqrt(amount0 * amount0 * reserve1 / reserve0);
        } else if(amount1 > 0) {
            return Math.sqrt(amount1 * amount1 * reserve0 / reserve1);
        }
        return 0;
    }

    /// @dev Update pool invariant, LP tokens borrowed plus interest, interest rate index, and last block update
    /// @param last - last value added to ema calculation
    /// @param emaLast - last calculated ema
    /// @param emaWeight - weight given to last value in ema calculation compared to last ema value
    /// @return ema - result of ema calculation
    function calcEMA(uint256 last, uint256 emaLast, uint256 emaWeight) internal pure returns(uint256) {
        if(emaLast == 0) {
            return last;
        } else {
            // EMA_1 = last * weight + EMA_0 * (1 - weight)
            return last * emaWeight / 100 + emaLast * (100 - emaWeight) / 100;
        }
    }

    function predictDeterministicAddress(
        address implementation,
        bytes32 salt,
        address factory
    ) internal pure returns (address predicted) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(add(ptr, 0x38), factory)
            mstore(add(ptr, 0x24), 0x5af43d82803e903d91602b57fd5bf3ff)
            mstore(add(ptr, 0x14), implementation)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73)
            mstore(add(ptr, 0x58), salt)
            mstore(add(ptr, 0x78), keccak256(add(ptr, 0x0c), 0x37))
            predicted := keccak256(add(ptr, 0x43), 0x55)
        }
    }
}
