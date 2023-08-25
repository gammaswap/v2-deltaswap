import { ethers } from "hardhat";
import { expect } from 'chai'
import { BigNumber, Contract, constants } from 'ethers'

import { v2Fixture} from './shared/fixtures'
import { expandTo18Decimals, getApprovalDigest, MINIMUM_LIQUIDITY } from './shared/utilities'

import { ecsign } from 'ethereumjs-util'

const overrides = {
    gasLimit: 9999999
}

describe('DeltaSwapRouter02', () => {
    let token0: Contract
    let token1: Contract
    let router: Contract
    let wallet: any
    let other: any
    beforeEach(async function() {
        [wallet, other] = await ethers.getSigners();
        const fixture = await v2Fixture(wallet);
        token0 = fixture.token0
        token1 = fixture.token1
        router = fixture.router02
    })

    it('quote', async () => {
        expect(await router.quote(BigNumber.from(1), BigNumber.from(100), BigNumber.from(200))).to.eq(BigNumber.from(2))
        expect(await router.quote(BigNumber.from(2), BigNumber.from(200), BigNumber.from(100))).to.eq(BigNumber.from(1))
        await expect(router.quote(BigNumber.from(0), BigNumber.from(100), BigNumber.from(200))).to.be.revertedWith(
            'DeltaSwapLibrary: INSUFFICIENT_AMOUNT'
        )
        await expect(router.quote(BigNumber.from(1), BigNumber.from(0), BigNumber.from(200))).to.be.revertedWith(
            'DeltaSwapLibrary: INSUFFICIENT_LIQUIDITY'
        )
        await expect(router.quote(BigNumber.from(1), BigNumber.from(100), BigNumber.from(0))).to.be.revertedWith(
            'DeltaSwapLibrary: INSUFFICIENT_LIQUIDITY'
        )
    })

    it('getAmountOut', async () => {
        const ONE = BigNumber.from(10).pow(18);
        const swapAmt = BigNumber.from(1).mul(ONE);

        let reserveIn = BigNumber.from(5).mul(ONE);
        let reserveOut = BigNumber.from(10).mul(ONE);
        expect(await router.getAmountOut(swapAmt, reserveIn, reserveOut, 3)).to.eq("1662497915624478906");

        reserveIn = BigNumber.from(5).mul(ONE);
        reserveOut = BigNumber.from(10).mul(ONE);
        expect(await router.getAmountOut(swapAmt.mul(2), reserveIn, reserveOut, 3)).to.eq("2851015155847869602");

        reserveIn = BigNumber.from(10).mul(ONE);
        reserveOut = BigNumber.from(5).mul(ONE);
        expect(await router.getAmountOut(swapAmt.mul(2), reserveIn, reserveOut, 3)).to.eq("831248957812239453");

        reserveIn = BigNumber.from(10).mul(ONE);
        reserveOut = BigNumber.from(5).mul(ONE);
        expect(await router.getAmountOut(swapAmt, reserveIn, reserveOut, 2)).to.eq("453718857974177123");

        reserveIn = BigNumber.from(10).mul(ONE);
        reserveOut = BigNumber.from(10).mul(ONE);
        expect(await router.getAmountOut(swapAmt, reserveIn, reserveOut, 2)).to.eq("907437715948354246");

        reserveIn = BigNumber.from(100).mul(ONE);
        reserveOut = BigNumber.from(100).mul(ONE);
        expect(await router.getAmountOut(swapAmt, reserveIn, reserveOut, 0)).to.eq("990099009900990099");

        reserveIn = BigNumber.from(1000).mul(ONE);
        reserveOut = BigNumber.from(1000).mul(ONE);
        expect(await router.getAmountOut(swapAmt, reserveIn, reserveOut, 0)).to.eq("999000999000999000");

        expect(await router.getAmountOut(BigNumber.from(2), BigNumber.from(100), BigNumber.from(100), 3)).to.eq(BigNumber.from(1))
        await expect(router.getAmountOut(BigNumber.from(0), BigNumber.from(100), BigNumber.from(100), 3)).to.be.revertedWith(
            'DeltaSwapLibrary: INSUFFICIENT_INPUT_AMOUNT'
        )
        await expect(router.getAmountOut(BigNumber.from(2), BigNumber.from(0), BigNumber.from(100), 3)).to.be.revertedWith(
            'DeltaSwapLibrary: INSUFFICIENT_LIQUIDITY'
        )
        await expect(router.getAmountOut(BigNumber.from(2), BigNumber.from(100), BigNumber.from(0), 3)).to.be.revertedWith(
            'DeltaSwapLibrary: INSUFFICIENT_LIQUIDITY'
        )
    })

    it('getAmountIn', async () => {
        expect(await router.getAmountIn(BigNumber.from(1), BigNumber.from(100), BigNumber.from(100), 3)).to.eq(BigNumber.from(2))
        await expect(router.getAmountIn(BigNumber.from(0), BigNumber.from(100), BigNumber.from(100), 3)).to.be.revertedWith(
            'DeltaSwapLibrary: INSUFFICIENT_OUTPUT_AMOUNT'
        )
        await expect(router.getAmountIn(BigNumber.from(1), BigNumber.from(0), BigNumber.from(100), 3)).to.be.revertedWith(
            'DeltaSwapLibrary: INSUFFICIENT_LIQUIDITY'
        )
        await expect(router.getAmountIn(BigNumber.from(1), BigNumber.from(100), BigNumber.from(0), 3)).to.be.revertedWith(
            'DeltaSwapLibrary: INSUFFICIENT_LIQUIDITY'
        )
    })

    it('getAmountsOut', async () => {
        await token0.approve(router.address, constants.MaxUint256)
        await token1.approve(router.address, constants.MaxUint256)
        await router.addLiquidity(
            token0.address,
            token1.address,
            BigNumber.from(10000),
            BigNumber.from(10000),
            0,
            0,
            wallet.address,
            constants.MaxUint256,
            overrides
        )

        await expect(router.getAmountsOut(BigNumber.from(2), [token0.address])).to.be.revertedWith(
            'DeltaSwapLibrary: INVALID_PATH'
        )
        const path = [token0.address, token1.address]
        expect(await router.getAmountsOut(BigNumber.from(2), path)).to.deep.eq([BigNumber.from(2), BigNumber.from(1)])
    })

    it('getAmountsIn', async () => {
        await token0.approve(router.address, constants.MaxUint256)
        await token1.approve(router.address, constants.MaxUint256)
        await router.addLiquidity(
            token0.address,
            token1.address,
            BigNumber.from(10000),
            BigNumber.from(10000),
            0,
            0,
            wallet.address,
            constants.MaxUint256,
            overrides
        )

        await expect(router.getAmountsIn(BigNumber.from(1), [token0.address])).to.be.revertedWith(
            'DeltaSwapLibrary: INVALID_PATH'
        )
        const path = [token0.address, token1.address]
        expect(await router.getAmountsIn(BigNumber.from(1), path)).to.deep.eq([BigNumber.from(2), BigNumber.from(1)])
    })
})

describe('fee-on-transfer tokens', () => {
    let DTT: Contract
    let WETH: Contract
    let router: Contract
    let pair: Contract
    let wallet: any
    let provider: any
    let DeflatingERC20: any;
    let DeltaSwapPair: any;
    beforeEach(async function() {
        provider = ethers.provider;
        [wallet] = await ethers.getSigners();
        const fixture = await v2Fixture(wallet);
        WETH = fixture.WETH
        router = fixture.router02

        DeflatingERC20 = await ethers.getContractFactory("DeflatingERC20");
        DTT = await DeflatingERC20.deploy(expandTo18Decimals(10000));

        // make a DTT<>WETH pair
        await fixture.factoryV2.createPair(DTT.address, WETH.address)
        const pairAddress = await fixture.factoryV2.getPair(DTT.address, WETH.address)
        DeltaSwapPair = await ethers.getContractFactory("DeltaSwapPair");
        pair = DeltaSwapPair.attach(pairAddress);
    })

    afterEach(async function() {
        expect(await provider.getBalance(router.address)).to.eq(0)
    })

    async function addLiquidity(DTTAmount: BigNumber, WETHAmount: BigNumber) {
        await DTT.approve(router.address, constants.MaxUint256)
        await router.addLiquidityETH(DTT.address, DTTAmount, DTTAmount, WETHAmount, wallet.address, constants.MaxUint256, {
            ...overrides,
            value: WETHAmount
        })
    }

    it('removeLiquidityETHSupportingFeeOnTransferTokens', async () => {
        const DTTAmount = expandTo18Decimals(1)
        const ETHAmount = expandTo18Decimals(4)
        await addLiquidity(DTTAmount, ETHAmount)

        const DTTInPair = await DTT.balanceOf(pair.address)
        const WETHInPair = await WETH.balanceOf(pair.address)
        const liquidity = await pair.balanceOf(wallet.address)
        const totalSupply = await pair.totalSupply()
        const NaiveDTTExpected = DTTInPair.mul(liquidity).div(totalSupply)
        const WETHExpected = WETHInPair.mul(liquidity).div(totalSupply)

        await pair.approve(router.address, constants.MaxUint256)
        await router.removeLiquidityETHSupportingFeeOnTransferTokens(
            DTT.address,
            liquidity,
            NaiveDTTExpected,
            WETHExpected,
            wallet.address,
            constants.MaxUint256,
            overrides
        )
    })

    it('removeLiquidityETHWithPermitSupportingFeeOnTransferTokens', async () => {
        const path = "m/44'/60'/0'/0/0"; // Default path for the first account
        const _wallet = ethers.Wallet.fromMnemonic("test test test test test test test test test test test junk", path)
        expect(_wallet.address).to.equal(wallet.address);

        const DTTAmount = expandTo18Decimals(1)
            .mul(100)
            .div(99)
        const ETHAmount = expandTo18Decimals(4)
        await addLiquidity(DTTAmount, ETHAmount)

        const expectedLiquidity = expandTo18Decimals(2)

        const nonce = await pair.nonces(_wallet.address)
        const digest = await getApprovalDigest(
            pair,
            { owner: _wallet.address, spender: router.address, value: expectedLiquidity.sub(MINIMUM_LIQUIDITY) },
            nonce,
            constants.MaxUint256
        )
        const { v, r, s } = ecsign(Buffer.from(digest.slice(2), 'hex'), Buffer.from(_wallet.privateKey.slice(2), 'hex'))

        const DTTInPair = await DTT.balanceOf(pair.address)
        const WETHInPair = await WETH.balanceOf(pair.address)
        const liquidity = await pair.balanceOf(_wallet.address)
        const totalSupply = await pair.totalSupply()
        const NaiveDTTExpected = DTTInPair.mul(liquidity).div(totalSupply)
        const WETHExpected = WETHInPair.mul(liquidity).div(totalSupply)

        await pair.approve(router.address, constants.MaxUint256)
        await router.removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
            DTT.address,
            liquidity,
            NaiveDTTExpected,
            WETHExpected,
            _wallet.address,
            constants.MaxUint256,
            false,
            v,
            r,
            s,
            overrides
        )
    })

    describe('swapExactTokensForTokensSupportingFeeOnTransferTokens', () => {
        const DTTAmount = expandTo18Decimals(5)
            .mul(100)
            .div(99)
        const ETHAmount = expandTo18Decimals(10)
        const amountIn = expandTo18Decimals(1)

        beforeEach(async () => {
            await addLiquidity(DTTAmount, ETHAmount)
        })

        it('DTT -> WETH', async () => {
            await DTT.approve(router.address, constants.MaxUint256)

            await router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                amountIn,
                0,
                [DTT.address, WETH.address],
                wallet.address,
                constants.MaxUint256,
                overrides
            )
        })

        // WETH -> DTT
        it('WETH -> DTT', async () => {
            await WETH.deposit({ value: amountIn }) // mint WETH
            await WETH.approve(router.address, constants.MaxUint256)

            await router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                amountIn,
                0,
                [WETH.address, DTT.address],
                wallet.address,
                constants.MaxUint256,
                overrides
            )
        })
    })

    // ETH -> DTT
    it('swapExactETHForTokensSupportingFeeOnTransferTokens', async () => {
        const DTTAmount = expandTo18Decimals(10)
            .mul(100)
            .div(99)
        const ETHAmount = expandTo18Decimals(5)
        const swapAmount = expandTo18Decimals(1)
        await addLiquidity(DTTAmount, ETHAmount)

        await router.swapExactETHForTokensSupportingFeeOnTransferTokens(
            0,
            [WETH.address, DTT.address],
            wallet.address,
            constants.MaxUint256,
            {
                ...overrides,
                value: swapAmount
            }
        )
    })

    // DTT -> ETH
    it('swapExactTokensForETHSupportingFeeOnTransferTokens', async () => {
        const DTTAmount = expandTo18Decimals(5)
            .mul(100)
            .div(99)
        const ETHAmount = expandTo18Decimals(10)
        const swapAmount = expandTo18Decimals(1)

        await addLiquidity(DTTAmount, ETHAmount)
        await DTT.approve(router.address, constants.MaxUint256)

        await router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            swapAmount,
            0,
            [DTT.address, WETH.address],
            wallet.address,
            constants.MaxUint256,
            overrides
        )
    })
})

describe('fee-on-transfer tokens: reloaded', () => {
    let DTT: Contract
    let DTT2: Contract
    let router: Contract
    let provider: any
    let wallet: any
    let DeflatingERC20: any
    beforeEach(async function() {
        provider = ethers.provider;
        [wallet] = await ethers.getSigners();
        const fixture = await v2Fixture(wallet);
        router = fixture.router02

        DeflatingERC20 = await ethers.getContractFactory("DeflatingERC20");
        DTT = await DeflatingERC20.deploy(expandTo18Decimals(10000));
        DTT2 = await DeflatingERC20.deploy(expandTo18Decimals(10000));

        // make a DTT<>WETH pair
        await fixture.factoryV2.createPair(DTT.address, DTT2.address)
        const pairAddress = await fixture.factoryV2.getPair(DTT.address, DTT2.address)
    })

    afterEach(async function() {
        expect(await provider.getBalance(router.address)).to.eq(0)
    })

    async function addLiquidity(DTTAmount: BigNumber, DTT2Amount: BigNumber) {
        await DTT.approve(router.address, constants.MaxUint256)
        await DTT2.approve(router.address, constants.MaxUint256)
        await router.addLiquidity(
            DTT.address,
            DTT2.address,
            DTTAmount,
            DTT2Amount,
            DTTAmount,
            DTT2Amount,
            wallet.address,
            constants.MaxUint256,
            overrides
        )
    }

    describe('swapExactTokensForTokensSupportingFeeOnTransferTokens', () => {
        const DTTAmount = expandTo18Decimals(5)
            .mul(100)
            .div(99)
        const DTT2Amount = expandTo18Decimals(5)
        const amountIn = expandTo18Decimals(1)

        beforeEach(async () => {
            await addLiquidity(DTTAmount, DTT2Amount)
        })

        it('DTT -> DTT2', async () => {
            await DTT.approve(router.address, constants.MaxUint256)

            await router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                amountIn,
                0,
                [DTT.address, DTT2.address],
                wallet.address,
                constants.MaxUint256,
                overrides
            )
        })
    })
})