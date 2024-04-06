// SPDX-License-Identifier: GPL-v3
pragma solidity =0.8.21;

import './interfaces/IDeltaSwapV2Router02.sol';
import './DeltaSwapV2Router01.sol';

contract DeltaSwapV2Router02 is DeltaSwapV2Router01, IDeltaSwapV2Router02 {

    constructor(address _factory, address _WETH) DeltaSwapV2Router01(_factory, _WETH) {
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountETH) {
        (, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        DSTransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
        IWETH(WETH).withdraw(amountETH);
        DSTransferHelper.safeTransferETH(to, amountETH);
    }
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint256 amountETH) {
        address pair = DeltaSwapV2Library.pairFor(factory, token, WETH);
        uint256 value = approveMax ? type(uint256).max : liquidity;
        IDeltaSwapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
            token, liquidity, amountTokenMin, amountETHMin, to, deadline
        );
    }
    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = DeltaSwapV2Library.sortTokens(input, output);
            IDeltaSwapV2Pair pair = IDeltaSwapV2Pair(DeltaSwapV2Library.pairFor(factory, input, output));
            uint256 amountInput;
            uint256 amountOutput;
            { // scope to avoid stack too deep errors
                (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
                (uint256 reserveInput, uint256 reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                amountInput = IERC20(input).balanceOf(address(pair)) - reserveInput;
                uint256 fee = DeltaSwapV2Library.calcPairTradingFee(amountInput, reserveInput, reserveOutput, address(pair));
                amountOutput = DeltaSwapV2Library.getAmountOut(amountInput, reserveInput, reserveOutput, fee);
            }
            (uint256 amount0Out, uint256 amount1Out) = input == token0 ? (uint256(0), amountOutput) : (amountOutput, uint256(0));
            address to = i < path.length - 2 ? DeltaSwapV2Library.pairFor(factory, output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) {
        DSTransferHelper.safeTransferFrom(
            path[0], msg.sender, DeltaSwapV2Library.pairFor(factory, path[0], path[1]), amountIn
        );
        uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore >= amountOutMin,
            'DeltaSwapV2Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    )
    external
    virtual
    override
    payable
    ensure(deadline)
    {
        require(path[0] == WETH, 'DeltaSwapV2Router: INVALID_PATH');
        uint256 amountIn = msg.value;
        IWETH(WETH).deposit{value: amountIn}();
        assert(IWETH(WETH).transfer(DeltaSwapV2Library.pairFor(factory, path[0], path[1]), amountIn));
        uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore >= amountOutMin,
            'DeltaSwapV2Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    )
    external
    virtual
    override
    ensure(deadline)
    {
        require(path[path.length - 1] == WETH, 'DeltaSwapV2Router: INVALID_PATH');
        DSTransferHelper.safeTransferFrom(
            path[0], msg.sender, DeltaSwapV2Library.pairFor(factory, path[0], path[1]), amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint256 amountOut = IERC20(WETH).balanceOf(address(this));
        require(amountOut >= amountOutMin, 'DeltaSwapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).withdraw(amountOut);
        DSTransferHelper.safeTransferETH(to, amountOut);
    }

}