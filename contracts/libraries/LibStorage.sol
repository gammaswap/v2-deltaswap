// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

/// @title Library containing global storage variables for GammaPools according to App Storage pattern
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Structs are packed to minimize storage size
library LibStorage {
    struct Storage {
        address token0;
        address token1;
        /// @dev unlocked - flag used in mutex implementation (1 = unlocked, 0 = locked). Initialized at 1
        uint8 unlocked; // 8 bits

        address gammaPool;
        uint24 gsFee; // GammaPool swap fee
        uint24 dsFee; // Fee on large trades
        uint24 dsFeeThreshold; // 0.003% of liquidity
        uint24 yieldPeriod; // 8 hours in seconds

        uint112 rootK0;
        uint112 liquidityEMA;
        uint32 lastLiquidityBlockNumber;

        uint112 tradeLiquidityEMA;     // uses single storage slot
        uint112 lastTradeLiquiditySum; // uses single storage slot
        uint32 lastTradeBlockNumber;   // uses single storage slot

        uint112 reserve0;           // uses single storage slot, accessible via getReserves
        uint112 reserve1;           // uses single storage slot, accessible via getReserves
        uint32  blockTimestampLast; // uses single storage slot, accessible via getReserves

        uint256 price0CumulativeLast;
        uint256 price1CumulativeLast;
        uint256 kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

        bytes32 DOMAIN_SEPARATOR;
        uint256 totalSupply;
        mapping(address => uint256) balanceOf;
        mapping(address => mapping(address => uint256)) allowance;
        mapping(address => uint256) nonces;
    }

    /// @dev Initializes global storage variables of GammaPool, must be called right after instantiating GammaPool
    /// @param self - pointer to storage variables (doesn't need to be passed)
    /// @param _token0 - tokens of CFMM this GammaPool is for
    /// @param _token1 -decimals of the tokens of the CFMM the GammaPool is for, indices must match tokens array
    function initialize(Storage storage self, address _token0, address _token1) internal {
        require(self.token0 == address(0) && self.token1 == address(0), 'DeltaSwap: INITIALIZED');// cannot initialize twice

        self.unlocked = 1; // mutex initialized as unlocked
        self.token0 = _token0;
        self.token1 = _token1;

        self.gsFee = 30; // GammaPool swap fee
        self.dsFee = 30; // Fee on large trades
        self.dsFeeThreshold = 3000; // 0.003% of liquidity
        self.yieldPeriod = 28800; // 8 hours in seconds
    }
}