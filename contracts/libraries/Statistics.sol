// SPDX-License-Identifier: GPL-v3
pragma solidity ^0.8.0;

library Statistics {
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

}
