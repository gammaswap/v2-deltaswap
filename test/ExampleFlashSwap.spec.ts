import { ethers } from "hardhat"
import { expect } from 'chai'
import { BigNumber, Contract, utils, constants } from 'ethers'

import { expandTo18Decimals } from './shared/utilities'
import { v2Fixture } from './shared/fixtures'

const overrides = {
    gasLimit: 9999999,
    gasPrice: utils.parseUnits('10', 'gwei'),
}

describe('ExampleFlashSwap', () => {
    let WETH: Contract
    let WETHPartner: Contract
    let WETHExchangeV1: Contract
    let WETHPair: Contract
    let flashSwapExample: Contract
    let wallet: any
    let ExampleFlashSwap: any
    let provider: any
    beforeEach(async function() {
        provider = ethers.provider;
        [wallet] = await ethers.getSigners();
        const fixture = await v2Fixture(wallet);
        WETH = fixture.WETH
        WETHPartner = fixture.WETHPartner
        WETHExchangeV1 = fixture.WETHExchangeV1
        WETHPair = fixture.WETHPair

        ExampleFlashSwap = await ethers.getContractFactory("ExampleFlashSwap");
        flashSwapExample = await ExampleFlashSwap.deploy(fixture.factoryV2.address, fixture.factoryV1.address, fixture.router.address, overrides);
    })

    it('deltaSwapCall:0', async () => {
        // add liquidity to V1 at a rate of 1 ETH / 200 X
        const WETHPartnerAmountV1 = expandTo18Decimals(2000)
        const ETHAmountV1 = expandTo18Decimals(10)
        await WETHPartner.approve(WETHExchangeV1.address, WETHPartnerAmountV1)
        await WETHExchangeV1.addLiquidity(BigNumber.from(1), WETHPartnerAmountV1, constants.MaxUint256, {
            ...overrides,
            value: ETHAmountV1
        })

        // add liquidity to V2 at a rate of 1 ETH / 100 X
        const WETHPartnerAmountV2 = expandTo18Decimals(1000)
        const ETHAmountV2 = expandTo18Decimals(10)
        await WETHPartner.transfer(WETHPair.address, WETHPartnerAmountV2)
        await WETH.deposit({ value: ETHAmountV2 })
        await WETH.transfer(WETHPair.address, ETHAmountV2)
        await WETHPair.mint(wallet.address, overrides)

        const balanceBefore = await WETHPartner.balanceOf(wallet.address)

        // now, execute arbitrage via deltaSwapCall:
        // receive 1 ETH from V2, get as much X from V1 as we can, repay V2 with minimum X, keep the rest!
        const arbitrageAmount = expandTo18Decimals(1)
        // instead of being 'hard-coded', the above value could be calculated optimally off-chain. this would be
        // better, but it'd be better yet to calculate the amount at runtime, on-chain. unfortunately, this requires a
        // swap-to-price calculation, which is a little tricky, and out of scope for the moment
        const WETHPairToken0 = await WETHPair.token0()
        const amount0 = WETHPairToken0 === WETHPartner.address ? BigNumber.from(0) : arbitrageAmount
        const amount1 = WETHPairToken0 === WETHPartner.address ? arbitrageAmount : BigNumber.from(0)
        await WETHPair.swap(
            amount0,
            amount1,
            flashSwapExample.address,
            utils.defaultAbiCoder.encode(['uint256'], [BigNumber.from(1)]),
            overrides
        )

        const balanceAfter = await WETHPartner.balanceOf(wallet.address)
        const profit = balanceAfter.sub(balanceBefore).div(expandTo18Decimals(1))
        const reservesV1 = [
            await WETHPartner.balanceOf(WETHExchangeV1.address),
            await provider.getBalance(WETHExchangeV1.address)
        ]
        const priceV1 = reservesV1[0].div(reservesV1[1])
        const reservesV2 = (await WETHPair.getReserves()).slice(0, 2)
        const priceV2 =
            WETHPairToken0 === WETHPartner.address ? reservesV2[0].div(reservesV2[1]) : reservesV2[1].div(reservesV2[0])

        expect(profit.toString()).to.eq('69') // our profit is ~69 tokens
        expect(priceV1.toString()).to.eq('165') // we pushed the v1 price down to ~165
        expect(priceV2.toString()).to.eq('123') // we pushed the v2 price up to ~123
    })

    it('deltaSwapCall:1', async () => {
        // add liquidity to V1 at a rate of 1 ETH / 100 X
        const WETHPartnerAmountV1 = expandTo18Decimals(1000)
        const ETHAmountV1 = expandTo18Decimals(10)
        await WETHPartner.approve(WETHExchangeV1.address, WETHPartnerAmountV1)
        await WETHExchangeV1.addLiquidity(BigNumber.from(1), WETHPartnerAmountV1, constants.MaxUint256, {
            ...overrides,
            value: ETHAmountV1
        })

        // add liquidity to V2 at a rate of 1 ETH / 200 X
        const WETHPartnerAmountV2 = expandTo18Decimals(2000)
        const ETHAmountV2 = expandTo18Decimals(10)
        await WETHPartner.transfer(WETHPair.address, WETHPartnerAmountV2)
        await WETH.deposit({ value: ETHAmountV2 })
        await WETH.transfer(WETHPair.address, ETHAmountV2)
        await WETHPair.mint(wallet.address, overrides)

        const balanceBefore = await provider.getBalance(wallet.address)

        // now, execute arbitrage via deltaSwapCall:
        // receive 200 X from V2, get as much ETH from V1 as we can, repay V2 with minimum ETH, keep the rest!
        const arbitrageAmount = expandTo18Decimals(200)
        // instead of being 'hard-coded', the above value could be calculated optimally off-chain. this would be
        // better, but it'd be better yet to calculate the amount at runtime, on-chain. unfortunately, this requires a
        // swap-to-price calculation, which is a little tricky, and out of scope for the moment
        const WETHPairToken0 = await WETHPair.token0()
        const amount0 = WETHPairToken0 === WETHPartner.address ? arbitrageAmount : BigNumber.from(0)
        const amount1 = WETHPairToken0 === WETHPartner.address ? BigNumber.from(0) : arbitrageAmount
        await WETHPair.swap(
            amount0,
            amount1,
            flashSwapExample.address,
            utils.defaultAbiCoder.encode(['uint256'], [BigNumber.from(1)]),
            overrides
        )

        const balanceAfter = await provider.getBalance(wallet.address)
        const profit = balanceAfter.sub(balanceBefore)
        const reservesV1 = [
            await WETHPartner.balanceOf(WETHExchangeV1.address),
            await provider.getBalance(WETHExchangeV1.address)
        ]
        const priceV1 = reservesV1[0].div(reservesV1[1])
        const reservesV2 = (await WETHPair.getReserves()).slice(0, 2)
        const priceV2 =
            WETHPairToken0 === WETHPartner.address ? reservesV2[0].div(reservesV2[1]) : reservesV2[1].div(reservesV2[0])

        expect(profit).to.gt(utils.parseEther("0.5")); // our profit is ~.5 ETH
        expect(profit).to.lt(utils.parseEther("0.55")); // our profit is ~.5 ETH
        expect(priceV1.toString()).to.eq('143') // we pushed the v1 price up to ~143
        expect(priceV2.toString()).to.eq('161') // we pushed the v2 price down to ~161
    })
})