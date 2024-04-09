// SPDX-License-Identifier: GPL-v3
pragma solidity >=0.5.0;

import '../../interfaces/IDeltaSwapV2Pair.sol';
import '../../interfaces/IDeltaSwapV2Factory.sol';
import '../../libraries/DeltaSwapV2Library.sol';

import './Babylonian.sol';
import './FullMath.sol';

// library containing some math for dealing with the liquidity shares of a pair, e.g. computing their exact value
// in terms of the underlying tokens
library DeltaSwapV2LiquidityMathLibrary {

    // computes the direction and magnitude of the profit-maximizing trade
    function computeProfitMaximizingTrade(
        uint256 truePriceTokenA,
        uint256 truePriceTokenB,
        uint256 reserveA,
        uint256 reserveB
    ) pure internal returns (bool aToB, uint256 amountIn) {
        aToB = FullMath.mulDiv(reserveA, truePriceTokenB, reserveB) < truePriceTokenA;

        uint256 invariant = reserveA * reserveB;

        uint256 leftSide = Babylonian.sqrt(
            FullMath.mulDiv(
                invariant * 1000,
                aToB ? truePriceTokenA : truePriceTokenB,
                (aToB ? truePriceTokenB : truePriceTokenA) * 997
            )
        );
        uint256 rightSide = (aToB ? reserveA * 1000 : reserveB * 1000) / 997;

        if (leftSide < rightSide) return (false, 0);

        // compute the amount that must be sent to move the price to the profit-maximizing price
        amountIn = leftSide - rightSide;
    }

    // gets the reserves after an arbitrage moves the price to the profit-maximizing ratio given an externally observed true price
    function getReservesAfterArbitrage(
        address factory,
        address tokenA,
        address tokenB,
        uint256 truePriceTokenA,
        uint256 truePriceTokenB
    ) view internal returns (uint256 reserveA, uint256 reserveB) {
        address pair;
        // first get reserves before the swap
        (reserveA, reserveB, pair) = DeltaSwapV2Library.getReserves(factory, tokenA, tokenB);

        require(reserveA > 0 && reserveB > 0, 'DeltaSwapV2ArbitrageLibrary: ZERO_PAIR_RESERVES');

        // then compute how much to swap to arb to the true price
        (bool aToB, uint256 amountIn) = computeProfitMaximizingTrade(truePriceTokenA, truePriceTokenB, reserveA, reserveB);

        if (amountIn == 0) {
            return (reserveA, reserveB);
        }

        uint256 fee = DeltaSwapV2Library.calcPairTradingFee(amountIn, reserveA, reserveB, pair);
        // now affect the trade to the reserves
        if (aToB) {
            uint256 amountOut = DeltaSwapV2Library.getAmountOut(amountIn, reserveA, reserveB, fee);
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            uint256 amountOut = DeltaSwapV2Library.getAmountOut(amountIn, reserveB, reserveA, fee);
            reserveB += amountIn;
            reserveA -= amountOut;
        }
    }

    // computes liquidity value given all the parameters of the pair
    function computeLiquidityValue(
        uint256 reservesA,
        uint256 reservesB,
        uint256 totalSupply,
        uint256 liquidityAmount,
        bool feeOn,
        uint256 kLast
    ) internal pure returns (uint256 tokenAAmount, uint256 tokenBAmount) {
        if (feeOn && kLast > 0) {
            uint256 rootK = Babylonian.sqrt(reservesA * reservesB);
            uint256 rootKLast = Babylonian.sqrt(kLast);
            if (rootK > rootKLast) {
                uint256 numerator1 = totalSupply;
                uint256 numerator2 = rootK - rootKLast;
                uint256 denominator = rootK * 5 + rootKLast;
                uint256 feeLiquidity = FullMath.mulDiv(numerator1, numerator2, denominator);
                totalSupply += feeLiquidity;
            }
        }
        return (reservesA * liquidityAmount / totalSupply, reservesB * liquidityAmount / totalSupply);
    }

    // get all current parameters from the pair and compute value of a liquidity amount
    // **note this is subject to manipulation, e.g. sandwich attacks**. prefer passing a manipulation resistant price to
    // #getLiquidityValueAfterArbitrageToPrice
    function getLiquidityValue(
        address factory,
        address tokenA,
        address tokenB,
        uint256 liquidityAmount
    ) internal view returns (uint256 tokenAAmount, uint256 tokenBAmount) {
        (uint256 reservesA, uint256 reservesB, address _pair) = DeltaSwapV2Library.getReserves(factory, tokenA, tokenB);
        IDeltaSwapV2Pair pair = IDeltaSwapV2Pair(_pair);
        bool feeOn = IDeltaSwapV2Factory(factory).feeTo() != address(0);
        uint256 kLast = feeOn ? pair.kLast() : 0;
        uint256 totalSupply = pair.totalSupply();
        return computeLiquidityValue(reservesA, reservesB, totalSupply, liquidityAmount, feeOn, kLast);
    }

    // given two tokens, tokenA and tokenB, and their "true price", i.e. the observed ratio of value of token A to token B,
    // and a liquidity amount, returns the value of the liquidity in terms of tokenA and tokenB
    function getLiquidityValueAfterArbitrageToPrice(
        address factory,
        address tokenA,
        address tokenB,
        uint256 truePriceTokenA,
        uint256 truePriceTokenB,
        uint256 liquidityAmount
    ) internal view returns (
        uint256 tokenAAmount,
        uint256 tokenBAmount
    ) {
        bool feeOn = IDeltaSwapV2Factory(factory).feeTo() != address(0);
        IDeltaSwapV2Pair pair = IDeltaSwapV2Pair(DeltaSwapV2Library.pairFor(factory, tokenA, tokenB));
        uint256 kLast = feeOn ? pair.kLast() : 0;
        uint256 totalSupply = pair.totalSupply();

        // this also checks that totalSupply > 0
        require(totalSupply >= liquidityAmount && liquidityAmount > 0, 'ComputeLiquidityValue: LIQUIDITY_AMOUNT');

        (uint256 reservesA, uint256 reservesB) = getReservesAfterArbitrage(factory, tokenA, tokenB, truePriceTokenA, truePriceTokenB);

        return computeLiquidityValue(reservesA, reservesB, totalSupply, liquidityAmount, feeOn, kLast);
    }
}