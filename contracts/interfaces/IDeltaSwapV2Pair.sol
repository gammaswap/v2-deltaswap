// SPDX-License-Identifier: GPL-v3
pragma solidity >=0.5.0;

import "./IDeltaSwapV2ERC20.sol";

interface IDeltaSwapV2Pair is IDeltaSwapV2ERC20 {

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint256);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function getLPReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint256 _rate);
    function price0CumulativeLast() external view returns (uint256);
    function price1CumulativeLast() external view returns (uint256);
    function kLast() external view returns (uint256);
    function rootK0() external view returns(uint112);

    function mint(address to) external returns (uint256 liquidity);
    function burn(address to) external returns (uint256 amount0, uint256 amount1);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;

    function setFeeParameters(bool _stream0, bool _stream1, uint16 _gsFee, uint16 _dsFee, uint24 _dsFeeThreshold, uint24 _yieldPeriod) external;
    function getFeeParameters() external view returns(address _gammaPool, bool _stream0, bool _stream1, uint16 _gsFee, uint16 _dsFee, uint24 _dsFeeThreshold, uint24 _yieldPeriod);
    function gammaPool() external view returns (address);
    function setGammaPool(address gammaPool) external;

    function getLiquidityEMA() external view returns(uint112 liquidityEMA, uint32 lastLiquidityEMABlockNumber);
    function getLastTradeLiquidityEMA() external view returns(uint256);
    function getTradeLiquidityEMA(uint256 tradeLiquidity) external view returns(uint256 tradeLiquidityEMA, uint256 lastTradeLiquidityEMA, uint256 tradeLiquiditySum);
    function getTradeLiquidityEMAParams() external view returns(uint112 _tradeLiquidityEMA, uint112 _lastTradeLiquiditySum, uint32 _lastTradeBlockNumber);
    function getLastTradeLiquiditySum(uint256 tradeLiquidity) external view returns(uint112 _tradeLiquiditySum, uint32 _lastTradeBlockNum);
    function estimateTradingFee(uint256 tradeLiquidity) external view returns(uint256 fee);
    function calcTradingFee(uint256 tradeLiquidity, uint256 tradeLiquidityEMA, uint256 liquidityEMA) external view returns(uint256 fee);
}