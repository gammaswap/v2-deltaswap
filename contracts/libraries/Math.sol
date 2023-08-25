// SPDX-License-Identifier: GPL-v3
pragma solidity >=0.5.16;

// a library for performing various math operations

library Math {
    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }

    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    /// @dev Update pool invariant, LP tokens borrowed plus interest, interest rate index, and last block update
    /// @param last - last value added to ema calculation
    /// @param emaLast - last calculated ema
    /// @param emaWeight - weight given to last value in ema calculation compared to last ema value
    /// @return ema - result of ema calculation
    function calcEMA(uint256 last, uint256 emaLast, uint256 emaWeight) internal pure returns(uint256) {
        require(emaWeight <= 100, "EMA_WEIGHT > 100");
        if(emaLast == 0) {
            return last;
        } else {
            // EMA_1 = last * weight + EMA_0 * (1 - weight)
            return last * emaWeight / 100 + emaLast * (100 - emaWeight) / 100;
        }
    }

    function calcSingleSideLiquidity(uint256 amount, uint256 reserve0, uint256 reserve1) internal pure returns(uint256) {
        return Math.sqrt(amount * (amount * reserve1 / reserve0));//sqrt(A*P*A) = L
    }

    function calcTradeLiquidity(uint256 amount0, uint256 amount1, uint256 reserve0, uint256 reserve1) internal pure returns(uint256) {
        if(amount0 > 0) {
            return calcSingleSideLiquidity(amount0, reserve0, reserve1);
        } else if(amount1 > 0) {
            return calcSingleSideLiquidity(amount1, reserve1, reserve0);
        }
        return 0;
    }
}
