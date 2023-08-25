// SPDX-License-Identifier: GPL-v3
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import "../../contracts/libraries/GammaSwapLib.sol";

contract GammaSwapLibTest is Test {

    function testCalcTradeLiquidity(uint128 amount, bool isToken0) public {
        uint256 reserve0 = 1_000_000_000_000 * 1e18;
        uint256 reserve1 = 1_000_000_000_000 * 1e18;
        uint256 amount0 = isToken0 ? amount : 0;
        uint256 amount1 = !isToken0 ? amount : 0;
        uint256 tradeLiquidity = GammaSwapLib.calcTradeLiquidity(amount0, amount1, reserve0, reserve1);
        assertEq(tradeLiquidity, Math.sqrt(uint256(amount)*amount));
        assertEq(GammaSwapLib.calcTradeLiquidity(0, 0, reserve0, reserve1), 0);
    }

    function testCalcTradingFee(uint256 lastLiquidityTradedEMA, uint128 lastLiquidityEMA) public {
        uint256 fee = GammaSwapLib.calcTradingFee(lastLiquidityTradedEMA, lastLiquidityEMA);
        if(lastLiquidityTradedEMA >= uint256(lastLiquidityEMA) * 2000 / 10000) {// if trade > 20% of liquidity, charge 1% fee => ~10% of liquidity value, ~40% px change
            assertEq(fee,3);
        } else if(lastLiquidityTradedEMA >= uint256(lastLiquidityEMA) * 1000 / 10000) {// if trade > 10% of liquidity, charge 0.3% fee => ~5% of liquidity value, ~20% px change
            assertEq(fee,2);
        } else if(lastLiquidityTradedEMA >= uint256(lastLiquidityEMA) * 500 / 10000) {// if trade > 5% of liquidity, charge 0.1% fee => ~2.5% of liquidity value, ~10% px change
            assertEq(fee,1);
        } else {
            assertEq(fee,0);
        }
    }

    function testCalcEMAFail() public {
        vm.expectRevert("EMA_WEIGHT > 100");
        GammaSwapLib.calcEMA(1, 1, 101);
    }

    function testCalcEMA0pctWeight() public {
        uint256 last = 0;
        uint256 emaLast = 0;
        uint256 emaWeight = 0; // out of 100
        uint256 ema = GammaSwapLib.calcEMA(last, emaLast, emaWeight);
        assertEq(ema, 0);

        last = 1 * 1e18;
        ema = GammaSwapLib.calcEMA(last, emaLast, emaWeight);
        assertEq(ema, last);

        emaLast = ema;

        last = 2 * 1e18;
        ema = GammaSwapLib.calcEMA(last, emaLast, emaWeight);
        assertEq(ema, 1e18);

        emaLast = ema;

        last = 3 * 1e18;
        ema = GammaSwapLib.calcEMA(last, emaLast, emaWeight);
        assertEq(ema, 1e18);

        emaLast = ema;

        last = 4 * 1e18;
        ema = GammaSwapLib.calcEMA(last, emaLast, emaWeight);
        assertEq(ema, 1e18);
    }

    function testCalcEMA100pctWeight() public {
        uint256 last = 0;
        uint256 emaLast = 0;
        uint256 emaWeight = 100; // out of 100
        uint256 ema = GammaSwapLib.calcEMA(last, emaLast, emaWeight);
        assertEq(ema, 0);
        last = 1 * 1e18;
        ema = GammaSwapLib.calcEMA(last, emaLast, emaWeight);
        assertEq(ema, last);

        emaLast = ema;

        last = 2 * 1e18;
        ema = GammaSwapLib.calcEMA(last, emaLast, emaWeight);
        assertEq(ema, last);

        emaLast = ema;

        last = 3 * 1e18;
        ema = GammaSwapLib.calcEMA(last, emaLast, emaWeight);
        assertEq(ema, last);

        emaLast = ema;

        last = 4 * 1e18;
        ema = GammaSwapLib.calcEMA(last, emaLast, emaWeight);
        assertEq(ema, last);
    }

    function testCalcEMA() public {
        uint256 last = 0;
        uint256 emaLast = 0;
        uint256 emaWeight = 20; // out of 100
        uint256 ema = GammaSwapLib.calcEMA(last, emaLast, emaWeight);
        assertEq(ema, 0);

        last = 1 * 1e18;
        ema = GammaSwapLib.calcEMA(last, emaLast, emaWeight);
        assertEq(ema, last);

        emaLast = ema;

        last = 2 * 1e18;
        ema = GammaSwapLib.calcEMA(last, emaLast, emaWeight);
        assertEq(ema, 12*1e17);

        emaLast = ema;

        last = 3 * 1e18;
        ema = GammaSwapLib.calcEMA(last, emaLast, emaWeight);
        assertEq(ema, 156*1e16);

        emaLast = ema;

        last = 4 * 1e18;
        ema = GammaSwapLib.calcEMA(last, emaLast, emaWeight);
        assertEq(ema, 2048*1e15);

        emaLast = ema;

        last = 5 * 1e18;
        ema = GammaSwapLib.calcEMA(last, emaLast, emaWeight);
        assertEq(ema, 26384*1e14);

        emaLast = ema;

        last = 4 * 1e18;
        ema = GammaSwapLib.calcEMA(last, emaLast, emaWeight);
        assertEq(ema, 291072*1e13);

        emaLast = ema;

        last = 3 * 1e18;
        ema = GammaSwapLib.calcEMA(last, emaLast, emaWeight);
        assertEq(ema, 2928576*1e12);

        emaLast = ema;

        last = 2 * 1e18;
        ema = GammaSwapLib.calcEMA(last, emaLast, emaWeight);
        assertEq(ema, 27428608*1e11);

        emaLast = ema;

        last = 1 * 1e18;
        ema = GammaSwapLib.calcEMA(last, emaLast, emaWeight);
        assertEq(ema, 239428864*1e10);
    }
}