// SPDX-License-Identifier: GPL-v3
pragma solidity ^0.8.0;

library GammaSwapLib {
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
