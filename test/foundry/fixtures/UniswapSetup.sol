// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../../../contracts/interfaces/IUniswapV2Factory.sol";
import "../../../contracts/interfaces/IUniswapV2Pair.sol";
import "../../../contracts/interfaces/IUniswapV2Router02.sol";

import "../../../contracts/UniswapV2Router02.sol";
import "../../../contracts/UniswapV2Factory.sol";

import "../../../contracts/test/WETH9.sol";
import "../../../contracts/test/ERC20Test.sol";

contract UniswapSetup is Test {

    WETH9 public weth;
    ERC20Test public usdc;
    ERC20Test public wbtc;

    address public owner;
    address public addr1;
    address public addr2;

    IUniswapV2Factory public uniFactory;
    IUniswapV2Router02 public uniRouter;
    IUniswapV2Pair public uniPair;

    function initUniswap(address owner, address weth, address usdc, address wbtc) public {
        // Let's do the same thing with `getCode`
        //bytes memory args = abi.encode(arg1, arg2);

        uniFactory = new UniswapV2Factory(owner);
        uniRouter = new UniswapV2Router02(address(uniFactory), weth);

        uniPair = UniswapV2Pair(createPair(address(usdc), address(wbtc)));
        /*bytes memory bytecode = type(UniswapV2Pair).creationCode;
        bytes32 initCode = keccak256(bytecode);
        console.log("initCode");
        console.logBytes32(initCode);
        console.log("uniPair");
        console.log(address(uniPair));/**/
    }

    function createPair(address token0, address token1) public returns(address) {
        return uniFactory.createPair(token0, token1);
    }

    function addLiquidity(address token0, address token1, uint256 amount0, uint256 amount1, address to) public returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        (amountA, amountB, liquidity) = uniRouter.addLiquidity(token0, token1, amount0, amount1, 0, 0, to, type(uint256).max);
    }

    function removeLiquidity(address token0, address token1, uint256 liquidity) public returns (uint256 amount0, uint256 amount1) {
        return uniRouter.removeLiquidity(token0, token1, liquidity, 0, 0, msg.sender, type(uint256).max);
    }

    function buyTokenOut(uint256 amountOut, address tokenIn, address tokenOut) public returns(uint256[] memory amounts) {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        return uniRouter.swapTokensForExactTokens(amountOut, type(uint256).max, path, msg.sender, type(uint256).max);
    }

    function sellTokenIn(uint256 amountIn, address tokenIn, address tokenOut, address to) public returns(uint256[] memory amounts) {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        return uniRouter.swapExactTokensForTokens(amountIn, 0, path, to, type(uint256).max);
    }

    function approveRouter(address[] memory _addresses, address[] memory _tokens) public {
        for(uint256 i = 0; i < _addresses.length;i++) {
            approveRouterForAddress(_addresses[i], _tokens);
        }
    }

    function approveRouterForAddress(address _address, address[] memory _tokens) public {
        vm.startPrank(_address);
        for(uint256 j = 0; j < _tokens.length;j++) {
            IERC20Test(_tokens[j]).approve(address(uniRouter), type(uint256).max);
        }
        uniPair.approve(address(uniRouter), type(uint256).max);
        vm.stopPrank();
    }
}
