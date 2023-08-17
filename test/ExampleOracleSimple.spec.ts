import { ethers } from "hardhat";
import { expect } from 'chai'
import { Contract } from 'ethers'

import { expandTo18Decimals, mineBlock, encodePrice } from './shared/utilities'
import { v2Fixture } from './shared/fixtures'

const overrides = {
    gasLimit: 9999999
}

const token0Amount = expandTo18Decimals(5)
const token1Amount = expandTo18Decimals(10)

describe('ExampleOracleSimple', () => {
    let token0: Contract
    let token1: Contract
    let pair: Contract
    let exampleOracleSimple: Contract
    let wallet: any;
    let other: any;
    let ExampleOracleSimple: any;
    let provider: any;
    async function addLiquidity() {
        await token0.transfer(pair.address, token0Amount)
        await token1.transfer(pair.address, token1Amount)
        await pair.mint(wallet.address, overrides)
    }

    beforeEach(async function() {
        provider = ethers.provider;
        [wallet, other] = await ethers.getSigners();
        const fixture = await v2Fixture(wallet);
        token0 = fixture.token0
        token1 = fixture.token1
        pair = fixture.pair

        await addLiquidity()
        ExampleOracleSimple = await ethers.getContractFactory("ExampleOracleSimple");
        exampleOracleSimple = await ExampleOracleSimple.deploy(fixture.factoryV2.address, token0.address, token1.address, overrides);
    })

    it('update', async () => {
        const blockTimestamp = (await pair.getReserves())[2]
        await mineBlock(provider, blockTimestamp + 60 * 60 * 23)
        await expect(exampleOracleSimple.update(overrides)).to.be.reverted
        await mineBlock(provider, blockTimestamp + 60 * 60 * 24)
        await exampleOracleSimple.update(overrides)

        const expectedPrice = encodePrice(token0Amount, token1Amount)

        expect(await exampleOracleSimple.price0Average()).to.eq(expectedPrice[0])
        expect(await exampleOracleSimple.price1Average()).to.eq(expectedPrice[1])

        expect(await exampleOracleSimple.consult(token0.address, token0Amount)).to.eq(token1Amount)
        expect(await exampleOracleSimple.consult(token1.address, token1Amount)).to.eq(token0Amount)
    })
})