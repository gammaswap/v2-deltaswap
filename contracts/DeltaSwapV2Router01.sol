// SPDX-License-Identifier: GPL-v3
pragma solidity =0.8.21;

import './libraries/DSTransferHelper.sol';
import './libraries/DeltaSwapV2Library.sol';
import './interfaces/IDeltaSwapV2Factory.sol';
import './interfaces/IDeltaSwapV2Router01.sol';
import './interfaces/IDSERC20.sol';
import './interfaces/IDSWETH.sol';

contract DeltaSwapV2Router01 is IDeltaSwapV2Router01 {
    address public immutable override factory;
    address public immutable override WETH;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, 'DeltaSwapV2Router: EXPIRED');
        _;
    }

    constructor(address _factory, address _WETH) {
        factory = _factory;
        WETH = _WETH;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal virtual returns (uint256 amountA, uint256 amountB) {
        // create the pair if it doesn't exist yet
        if (IDeltaSwapV2Factory(factory).getPair(tokenA, tokenB) == address(0)) {
            IDeltaSwapV2Factory(factory).createPair(tokenA, tokenB);
        }
        (uint256 reserveA, uint256 reserveB,) = DeltaSwapV2Library.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = DeltaSwapV2Library.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'DeltaSwapV2Router: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = DeltaSwapV2Library.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'DeltaSwapV2Router: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = DeltaSwapV2Library.pairFor(factory, tokenA, tokenB);
        DSTransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        DSTransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IDeltaSwapV2Pair(pair).mint(to);
    }
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external virtual override payable ensure(deadline) returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        address pair = DeltaSwapV2Library.pairFor(factory, token, WETH);
        DSTransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IDSWETH(WETH).deposit{value: amountETH}();
        assert(IDSWETH(WETH).transfer(pair, amountETH));
        liquidity = IDeltaSwapV2Pair(pair).mint(to);
        if (msg.value > amountETH) DSTransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);// refund dust eth, if any
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        address pair = DeltaSwapV2Library.pairFor(factory, tokenA, tokenB);
        IDeltaSwapV2Pair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint256 amount0, uint256 amount1) = IDeltaSwapV2Pair(pair).burn(to);
        (address token0,) = DeltaSwapV2Library.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, 'DeltaSwapV2Router: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'DeltaSwapV2Router: INSUFFICIENT_B_AMOUNT');
    }
    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountToken, uint256 amountETH) {
        (amountToken, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        DSTransferHelper.safeTransfer(token, to, amountToken);
        IDSWETH(WETH).withdraw(amountETH);
        DSTransferHelper.safeTransferETH(to, amountETH);
    }
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint256 amountA, uint256 amountB) {
        address pair = DeltaSwapV2Library.pairFor(factory, tokenA, tokenB);
        uint256 value = approveMax ? type(uint256).max : liquidity;
        IDeltaSwapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }
    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint256 amountToken, uint256 amountETH) {
        address pair = DeltaSwapV2Library.pairFor(factory, token, WETH);
        uint256 value = approveMax ? type(uint256).max : liquidity;
        IDeltaSwapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint256[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = DeltaSwapV2Library.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
            address to = i < path.length - 2 ? DeltaSwapV2Library.pairFor(factory, output, path[i + 2]) : _to;
            IDeltaSwapV2Pair(DeltaSwapV2Library.pairFor(factory, input, output)).swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        amounts = DeltaSwapV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'DeltaSwapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        DSTransferHelper.safeTransferFrom(path[0], msg.sender, DeltaSwapV2Library.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        amounts = DeltaSwapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'DeltaSwapV2Router: EXCESSIVE_INPUT_AMOUNT');
        DSTransferHelper.safeTransferFrom(path[0], msg.sender, DeltaSwapV2Library.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }
    function swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
    external
    virtual
    override
    payable
    ensure(deadline)
    returns (uint256[] memory amounts)
    {
        require(path[0] == WETH, 'DeltaSwapV2Router: INVALID_PATH');
        amounts = DeltaSwapV2Library.getAmountsOut(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'DeltaSwapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        IDSWETH(WETH).deposit{value: amounts[0]}();
        assert(IDSWETH(WETH).transfer(DeltaSwapV2Library.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
    }
    function swapTokensForExactETH(uint256 amountOut, uint256 amountInMax, address[] calldata path, address to, uint256 deadline)
    external
    virtual
    override
    ensure(deadline)
    returns (uint256[] memory amounts)
    {
        require(path[path.length - 1] == WETH, 'DeltaSwapV2Router: INVALID_PATH');
        amounts = DeltaSwapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'DeltaSwapV2Router: EXCESSIVE_INPUT_AMOUNT');
        DSTransferHelper.safeTransferFrom(path[0], msg.sender, DeltaSwapV2Library.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, address(this));
        IDSWETH(WETH).withdraw(amounts[amounts.length - 1]);
        DSTransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }
    function swapExactTokensForETH(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
    external
    virtual
    override
    ensure(deadline)
    returns (uint256[] memory amounts)
    {
        require(path[path.length - 1] == WETH, 'DeltaSwapV2Router: INVALID_PATH');
        amounts = DeltaSwapV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'DeltaSwapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        DSTransferHelper.safeTransferFrom(path[0], msg.sender, DeltaSwapV2Library.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, address(this));
        IDSWETH(WETH).withdraw(amounts[amounts.length - 1]);
        DSTransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }
    function swapETHForExactTokens(uint256 amountOut, address[] calldata path, address to, uint256 deadline)
    external
    virtual
    override
    payable
    ensure(deadline)
    returns (uint256[] memory amounts)
    {
        require(path[0] == WETH, 'DeltaSwapV2Router: INVALID_PATH');
        amounts = DeltaSwapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, 'DeltaSwapV2Router: EXCESSIVE_INPUT_AMOUNT');
        IDSWETH(WETH).deposit{value: amounts[0]}();
        assert(IDSWETH(WETH).transfer(DeltaSwapV2Library.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        if (msg.value > amounts[0]) DSTransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);// refund dust eth, if any
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) public pure virtual override returns (uint256 amountB) {
        return DeltaSwapV2Library.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut, uint256 fee) public pure virtual override returns (uint256 amountOut) {
        return DeltaSwapV2Library.getAmountOut(amountIn, reserveIn, reserveOut, fee);
    }

    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut, uint256 fee) public pure virtual override returns (uint256 amountIn) {
        return DeltaSwapV2Library.getAmountIn(amountOut, reserveIn, reserveOut, fee);
    }

    function getAmountsOut(uint256 amountIn, address[] memory path) public view virtual override returns (uint256[] memory amounts) {
        return DeltaSwapV2Library.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint256 amountOut, address[] memory path) public view virtual override returns (uint256[] memory amounts) {
        return DeltaSwapV2Library.getAmountsIn(factory, amountOut, path);
    }
}