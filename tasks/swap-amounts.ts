import { task } from "hardhat/config"
import { BigNumber, Contract, utils } from "ethers";

// run as "npx hardhat --network december swap-amounts"
task("swap-amounts", "Checks available address")
    .addParam("token0", "amount of token0 in CFMM")
    .addParam("token1", "amount of token1 in CFMM")
    .addParam("amount0", "amount to swap")
    .addOptionalParam("fee", "fee amount")
    .addOptionalParam("v", "Print all accounts").setAction(async (taskArgs, hre) => {
    if (hre.network.name === "hardhat") {
        console.warn(
            "You are running on Hardhat network, which" +
            "gets automatically created and destroyed every time. Use the Hardhat" +
            " option '--network localhost'"
        )
    }

    const ONE = BigNumber.from(10).pow(18);
    const token0amt = BigNumber.from(taskArgs.token0).mul(ONE)
    const token1amt = BigNumber.from(taskArgs.token1).mul(ONE)
    if(token0amt.eq(0)) {
        console.log("missing token0");
        return;
    }
    if(token1amt.eq(0)) {
        console.log("missing token1");
        return;
    }
    const amount = BigNumber.from(taskArgs.amount0).mul(ONE)
    const fee = BigNumber.from(taskArgs.fee);
    const oneBps = BigNumber.from(10000);

    const amountInWithFee = amount.mul(oneBps.sub(fee))
    const numerator = amountInWithFee.mul(token1amt);
    const denominator = token0amt.mul(oneBps).add(amountInWithFee);
    const amountOut = numerator.div(denominator);
    console.log("amountOut:", utils.formatUnits(amountOut, 18).toString(), ", BN:", amountOut.toString())

    const _numerator = token0amt.mul(amount).mul(oneBps);
    const _denominator = (token1amt.sub(amount)).mul(oneBps.sub(fee));
    const amountIn = (_numerator.div(_denominator)).add(1);
    console.log("amountIn:", utils.formatUnits(amountIn, 18).toString(), ", BN:", amountIn.toString())
    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    /*function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn.mul(amountOut).mul(1000);
        uint denominator = reserveOut.sub(amountOut).mul(997);
        amountIn = (numerator / denominator).add(1);
    }/**/
    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    /*function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }/**/

})