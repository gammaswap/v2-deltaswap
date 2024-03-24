// SPDX-License-Identifier: GPL-v3
pragma solidity >=0.5.16;

// a library for performing various math operations

library DSMath {

    function max(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x > y ? x : y;
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }

    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        else{
            uint256 xx = x;
            uint256 r = 1;
            if (xx >= 0x100000000000000000000000000000000) { xx >>= 128; r <<= 64; }
            if (xx >= 0x10000000000000000) { xx >>= 64; r <<= 32; }
            if (xx >= 0x100000000) { xx >>= 32; r <<= 16; }
            if (xx >= 0x10000) { xx >>= 16; r <<= 8; }
            if (xx >= 0x100) { xx >>= 8; r <<= 4; }
            if (xx >= 0x10) { xx >>= 4; r <<= 2; }
            if (xx >= 0x8) { r <<= 1; }
            r = (r + x / r) >> 1;
            r = (r + x / r) >> 1;
            r = (r + x / r) >> 1;
            r = (r + x / r) >> 1;
            r = (r + x / r) >> 1;
            r = (r + x / r) >> 1;
            r = (r + x / r) >> 1;
            uint256 r1 = x / r;
            return uint128 (r < r1 ? r : r1);
        }
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
            emaWeight = min(100, emaWeight);
            // EMA_1 = last * weight + EMA_0 * (1 - weight)
            return last * emaWeight / 100 + emaLast * (100 - emaWeight) / 100;
        }
    }

    function calcSingleSideLiquidity(uint256 amount, uint256 reserve0, uint256 reserve1) internal pure returns(uint256) {
        uint256 amount0 = amount / 2;
        uint256 amount1 = amount0 * reserve1 / reserve0;
        return sqrt(amount0 * amount1);
    }

    function calcTradeLiquidity(uint256 amount0, uint256 amount1, uint256 reserve0, uint256 reserve1) internal pure returns(uint256) {
        return max(
            calcSingleSideLiquidity(amount0, reserve0, reserve1),
                calcSingleSideLiquidity(amount1, reserve1, reserve0));
    }
}
