// SPDX-License-Identifier: GPL-v3
pragma solidity =0.8.21;

import './libraries/DSMath.sol';
import './libraries/UQ112x112.sol';
import './interfaces/IERC20.sol';
import './interfaces/IDeltaSwapV2Pair.sol';
import './interfaces/IDeltaSwapV2Factory.sol';
import './interfaces/IDeltaSwapV2Callee.sol';
import './DeltaSwapV2ERC20.sol';

/// @title DeltaSwapV2Pair contract
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice x*y=k AMM implementation that streams fee yield to LPs and charges fees for swaps above a certain threshold
contract DeltaSwapV2Pair is DeltaSwapV2ERC20, IDeltaSwapV2Pair {

    using LibStorage for LibStorage.Storage;
    using UQ112x112 for uint224;

    uint256 public constant override MINIMUM_LIQUIDITY = 10**3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    address public immutable override factory;

    function price0CumulativeLast() external override view returns(uint256) {
        return s.price0CumulativeLast;
    }

    function price1CumulativeLast() external override view returns(uint256) {
        return s.price1CumulativeLast;
    }

    function kLast() external override view returns(uint256) {
        return s.kLast;
    }

    function rootK0() external override view returns(uint112) {
        return s.rootK0;
    }

    function gammaPool() external override view returns(address) {
        return s.gammaPool;
    }

    function token0() external override view returns(address) {
        return s.token0;
    }

    function token1() external override view returns(address) {
        return s.token1;
    }

    function getReserves() public override view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = s.reserve0;
        _reserve1 = s.reserve1;
        _blockTimestampLast = s.blockTimestampLast;
    }

    function getLPReserves() public override view returns (uint112 _reserve0, uint112 _reserve1, uint256 _rate) {
        uint32 _blockTimestampLast;
        (_reserve0, _reserve1, _blockTimestampLast) = getReserves();
        uint256 _rootK0 = s.rootK0;
        uint256 _rootK1 = DSMath.sqrt(uint256(_reserve0)*_reserve1);
        if(_rootK1 == 0) { // no deposits yet
            return(0, 0, 0);
        }

        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed;
        unchecked {
            timeElapsed = blockTimestamp - _blockTimestampLast; // overflow is desired
        }

        if(timeElapsed > 0 && _rootK0 > 0 && _rootK1 > _rootK0) {
            uint32 _yieldPeriod = s.yieldPeriod; // save gas
            timeElapsed = uint32(DSMath.min(timeElapsed, _yieldPeriod));
            _rootK0 = _rootK0 + (_rootK1 - _rootK0) * timeElapsed / _yieldPeriod; // 1 day in seconds
            _rate = _yieldPeriod > timeElapsed ? (_rootK1 - _rootK0) * 1e18 / (_yieldPeriod - timeElapsed) : 0;
        }

        _reserve0 = uint112(_reserve0 * _rootK0 / _rootK1);
        _reserve1 = uint112(_reserve1 * _rootK0 / _rootK1);
    }

    function _safeTransfer(address token, address to, uint256 value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'DeltaSwapV2: TRANSFER_FAILED');
    }

    constructor(address _factory) {
        factory = _factory;
    }

    // called once by the factory at time of deployment
    function initialize(address _token0, address _token1) external override {
        require(msg.sender == factory, 'DeltaSwapV2: FORBIDDEN'); // sufficient check
        s.initialize(_token0, _token1);
        _initializeDomainSeparator();
    }

    function setFeeParameters(uint24 _gsFee, uint24 _dsFee, uint24 _dsFeeThreshold, uint24 _yieldPeriod) external override {
        require(msg.sender == factory, 'DeltaSwapV2: FORBIDDEN');
        require(_yieldPeriod > 0, 'DeltaSwapV2: YIELD_PERIOD');
        s.gsFee = _gsFee;
        s.dsFee = _dsFee;
        s.dsFeeThreshold = _dsFeeThreshold;
        s.yieldPeriod = _yieldPeriod;
    }

    function getFeeParameters() external view returns(address _gammaPool, uint24 _gsFee, uint24 _dsFee, uint24 _dsFeeThreshold, uint24 _yieldPeriod) {
        _gammaPool = s.gammaPool;
        _gsFee = s.gsFee;
        _dsFee = s.dsFee;
        _dsFeeThreshold = s.dsFeeThreshold;
        _yieldPeriod = s.yieldPeriod;
    }

    // called by the factory after deployment
    function setGammaPool(address pool) external override {
        require(msg.sender == factory, 'DeltaSwapV2: FORBIDDEN'); // sufficient check
        s.gammaPool = pool;
    }

    // update reserves and, on the first call per block, price accumulators
    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1, uint112 amount0, uint112 amount1, bool isDeposit) private returns(uint112,uint112) {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, 'DeltaSwapV2: OVERFLOW');
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed;
        unchecked {
            timeElapsed = blockTimestamp - s.blockTimestampLast; // overflow is desired
        }
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // * never overflows, and + overflow is desired
            unchecked{
                s.price0CumulativeLast += uint256(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
                s.price1CumulativeLast += uint256(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
            }
        }
        (uint112 _liquidityEMA, uint32 _lastLiquidityBlockNumber) = getLiquidityEMA(); // saves gas
        if(block.number != _lastLiquidityBlockNumber) {
            s.liquidityEMA = uint112(DSMath.calcEMA(DSMath.sqrt(balance0 * balance1), _liquidityEMA, DSMath.max(block.number - _lastLiquidityBlockNumber, 10)));
            s.lastLiquidityBlockNumber = uint32(block.number);
        }
        (_reserve0, _reserve1,) = getLPReserves();
        if(isDeposit) {
            _reserve0 += amount0;
            _reserve1 += amount1;
        } else {
            _reserve0 -= amount0;
            _reserve1 -= amount1;
        }
        uint256 _rootK1 = DSMath.sqrt(balance0*balance1);
        s.rootK0 = uint112(DSMath.min(DSMath.sqrt(uint256(_reserve0)*_reserve1) + 1, _rootK1)); // +1 because square root formula rounds down
        s.reserve0 = uint112(balance0);
        s.reserve1 = uint112(balance1);
        s.blockTimestampLast = blockTimestamp;
        emit Sync(s.reserve0, s.reserve1);
        return(_reserve0, _reserve1);
    }

    function _updateLiquidityTradedEMA(uint256 tradeLiquidity) internal virtual returns(uint256 _tradeLiquidityEMA) {
        require(tradeLiquidity > 0, "DeltaSwapV2: ZERO_TRADE_LIQUIDITY");
        uint256 blockNum = block.number;
        uint256 tradeLiquiditySum;
        (_tradeLiquidityEMA,,tradeLiquiditySum) = _getTradeLiquidityEMA(tradeLiquidity, blockNum);
        s.lastTradeLiquiditySum = uint112(tradeLiquiditySum);
        s.tradeLiquidityEMA = uint112(_tradeLiquidityEMA);
        if(s.lastTradeBlockNumber != blockNum) {
            s.lastTradeBlockNumber = uint32(blockNum);
        }
    }

    function estimateTradingFee(uint256 tradeLiquidity) external virtual override view returns(uint256 fee) {
        (uint256 _tradeLiquidityEMA,,) = _getTradeLiquidityEMA(tradeLiquidity, block.number);
        fee = calcTradingFee(tradeLiquidity, _tradeLiquidityEMA, s.liquidityEMA);
    }

    function calcTradingFee(uint256 tradeLiquidity, uint256 lastLiquidityTradedEMA, uint256 lastLiquidityEMA) public virtual override view returns(uint256) {
        if(s.dsFee > 0 && DSMath.max(tradeLiquidity, lastLiquidityTradedEMA) >= lastLiquidityEMA * s.dsFeeThreshold / 1e8) { // if trade >= threshold, charge fee
            return s.dsFee;
        }
        return 0;
    }

    function getLiquidityEMA() public virtual override view returns(uint112 _liquidityEMA, uint32 _lastLiquidityBlockNumber) {
        _liquidityEMA = s.liquidityEMA;
        _lastLiquidityBlockNumber = s.lastLiquidityBlockNumber;
    }

    function getTradeLiquidityEMAParams() external virtual override view returns(uint112 _tradeLiquidityEMA, uint112 _lastTradeLiquiditySum, uint32 _lastTradeBlockNumber) {
        _tradeLiquidityEMA = s.tradeLiquidityEMA;
        _lastTradeLiquiditySum = s.lastTradeLiquiditySum;
        _lastTradeBlockNumber = s.lastTradeBlockNumber;
    }

    function getTradeLiquidityEMA(uint256 tradeLiquidity) external virtual override view
        returns(uint256 _tradeLiquidityEMA, uint256 lastTradeLiquidityEMA, uint256 tradeLiquiditySum) {
        return _getTradeLiquidityEMA(tradeLiquidity, block.number);
    }

    function _getTradeLiquidityEMA(uint256 tradeLiquidity, uint256 blockNumber) internal virtual view
        returns(uint256 _tradeLiquidityEMA, uint256 lastTradeLiquidityEMA, uint256 tradeLiquiditySum) {
        uint256 blockDiff = blockNumber - s.lastTradeBlockNumber;
        tradeLiquiditySum = _getLastTradeLiquiditySum(tradeLiquidity, blockDiff);
        lastTradeLiquidityEMA = _getLastTradeLiquidityEMA(blockDiff);
        _tradeLiquidityEMA = tradeLiquidity > 0 ? DSMath.calcEMA(tradeLiquiditySum, lastTradeLiquidityEMA, 20) : lastTradeLiquidityEMA;
    }

    function getLastTradeLiquiditySum(uint256 tradeLiquidity) external virtual override view returns(uint112 _tradeLiquiditySum, uint32 _lastTradeBlockNumber) {
        _lastTradeBlockNumber = s.lastTradeBlockNumber;
        _tradeLiquiditySum = uint112(_getLastTradeLiquiditySum(tradeLiquidity, block.number - _lastTradeBlockNumber));
    }

    function getLastTradeLiquidityEMA() external virtual override view returns(uint256) {
        return _getLastTradeLiquidityEMA(block.number - s.lastLiquidityBlockNumber);
    }

    function _getLastTradeLiquiditySum(uint256 tradeLiquidity, uint256 blockDiff) internal virtual view returns(uint256) {
        if(blockDiff > 0) {
            return tradeLiquidity;
        } else {
            return s.lastTradeLiquiditySum + tradeLiquidity;
        }
    }

    function _getLastTradeLiquidityEMA(uint256 blockDiff) internal virtual view returns(uint256) {
        if(blockDiff > 50) {
            // if no trade in 50 blocks (~10 minutes), then reset
            return 0;
        }
        return s.tradeLiquidityEMA;
    }

    // if fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        (address feeTo, uint256 feeNum) = IDeltaSwapV2Factory(factory).feeInfo();
        feeOn = feeTo != address(0);
        uint256 _kLast = s.kLast; // gas savings
        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = DSMath.sqrt(uint256(_reserve0) * _reserve1);
                uint256 rootKLast = DSMath.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint256 numerator = s.totalSupply * (rootK - rootKLast);
                    uint256 denominator = rootK * feeNum / 1000 + rootKLast;
                    uint256 liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            s.kLast = 0;
        }
    }

    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) external override lock returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        uint256 balance0 = IERC20(s.token0).balanceOf(address(this));
        uint256 balance1 = IERC20(s.token1).balanceOf(address(this));
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;

        (_reserve0, _reserve1,) = getLPReserves(); // gas savings
        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = s.totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            liquidity = DSMath.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = DSMath.min(amount0 * _totalSupply / _reserve0, amount1 * _totalSupply / _reserve1);
        }
        require(liquidity > 0, 'DeltaSwapV2: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);

        (_reserve0, _reserve1) = _update(balance0, balance1, s.reserve0, s.reserve1, uint112(amount0), uint112(amount1), true);
        if (feeOn) s.kLast = (uint256(_reserve0)* _reserve1); // reserve0 and reserve1 are up-to-date
        emit Mint(msg.sender, amount0, amount1);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) external override lock returns (uint256 amount0, uint256 amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getLPReserves(); // gas savings
        address _token0 = s.token0;                                // gas savings
        address _token1 = s.token1;                                // gas savings
        uint256 balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(_token1).balanceOf(address(this));
        uint256 liquidity = s.balanceOf[address(this)];

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = s.totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        amount0 = liquidity * _reserve0 / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = liquidity * _reserve1 / _totalSupply; // using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, 'DeltaSwapV2: INSUFFICIENT_LIQUIDITY_BURNED');
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        (_reserve0, _reserve1) = _update(balance0, balance1, s.reserve0, s.reserve1, uint112(amount0), uint112(amount1), false);
        if (feeOn) s.kLast = (uint256(_reserve0) * _reserve1); // reserve0 and reserve1 are up-to-date
        emit Burn(msg.sender, amount0, amount1, to);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external override lock {
        require(amount0Out > 0 || amount1Out > 0, 'DeltaSwapV2: INSUFFICIENT_OUTPUT_AMOUNT');
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'DeltaSwapV2: INSUFFICIENT_LIQUIDITY');

        uint256 balance0;
        uint256 balance1;
        { // scope for _token{0,1}, avoids stack too deep errors
            address _token0 = s.token0;
            address _token1 = s.token1;
            require(to != _token0 && to != _token1, 'DeltaSwapV2: INVALID_TO');
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
            if (data.length > 0) IDeltaSwapV2Callee(to).deltaSwapCall(msg.sender, amount0Out, amount1Out, data);
            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }
        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, 'DeltaSwapV2: INSUFFICIENT_INPUT_AMOUNT');
        { // scope for reserve{0,1}Adjusted, avoids stack too deep errors
            uint256 fee;
            if(msg.sender != s.gammaPool) {
                uint256 tradeLiquidity = DSMath.calcTradeLiquidity(amount0In, amount1In, _reserve0, _reserve1);
                fee = calcTradingFee(tradeLiquidity, _updateLiquidityTradedEMA(tradeLiquidity), s.liquidityEMA);
            } else {
                fee = s.gsFee;
            }
            uint256 balance0Adjusted = balance0 * 10000 - amount0In * fee;
            uint256 balance1Adjusted = balance1 * 10000 - amount1In * fee;
            require(balance0Adjusted * balance1Adjusted >= uint256(_reserve0) * _reserve1 * (10000**2), 'DeltaSwapV2: K');
        }

        _update(balance0, balance1, _reserve0, _reserve1, 0, 0, false);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    // force balances to match reserves
    function skim(address to) external override lock {
        address _token0 = s.token0; // gas savings
        address _token1 = s.token1; // gas savings
        _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)) - s.reserve0);
        _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)) - s.reserve1);
    }

    // force reserves to match balances
    function sync() external override lock {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        _update(IERC20(s.token0).balanceOf(address(this)), IERC20(s.token1).balanceOf(address(this)), _reserve0, _reserve1, 0, 0, false);
    }
}