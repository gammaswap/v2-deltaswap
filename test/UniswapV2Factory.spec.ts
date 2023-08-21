import { ethers } from "hardhat";
import { expect } from 'chai'
import { BigNumber, Contract, utils, constants } from 'ethers'

import { getCreate2Address } from './shared/utilities'
import { factoryFixture } from './shared/fixtures'

const TEST_ADDRESSES: [string, string] = [
    '0x1000000000000000000000000000000000000000',
    '0x2000000000000000000000000000000000000000'
]

describe('UniswapV2Factory', () => {
    let UniswapV2Pair: any;
    let wallet: any;
    let other: any;
    let factory: Contract

    beforeEach(async () => {
        UniswapV2Pair = await ethers.getContractFactory("UniswapV2Pair");
        [wallet, other] = await ethers.getSigners();
        const fixture = await factoryFixture(wallet)
        factory = fixture.factory
        console.log("initCodeHash >> ", utils.keccak256(UniswapV2Pair.bytecode).toString())
    })

    it('feeTo, feeToSetter, allPairsLength', async () => {
        expect(await factory.feeTo()).to.eq(constants.AddressZero)
        expect(await factory.feeToSetter()).to.eq(wallet.address)
        expect(await factory.allPairsLength()).to.eq(0)
    })

    async function createPair(tokens: [string, string]) {
        const bytecode = `${UniswapV2Pair.bytecode}`
        const create2Address = getCreate2Address(factory.address, tokens, bytecode)
        await expect(factory.createPair(...tokens))
            .to.emit(factory, 'PairCreated')
            .withArgs(TEST_ADDRESSES[0], TEST_ADDRESSES[1], create2Address, BigNumber.from(1))

        await expect(factory.createPair(...tokens)).to.be.reverted // UniswapV2: PAIR_EXISTS
        await expect(factory.createPair(...tokens.slice().reverse())).to.be.reverted // UniswapV2: PAIR_EXISTS
        expect(await factory.getPair(...tokens)).to.eq(create2Address)
        expect(await factory.getPair(...tokens.slice().reverse())).to.eq(create2Address)
        expect(await factory.allPairs(0)).to.eq(create2Address)
        expect(await factory.allPairsLength()).to.eq(1)

        const pair = UniswapV2Pair.attach(create2Address);
        expect(await pair.factory()).to.eq(factory.address)
        expect(await pair.token0()).to.eq(TEST_ADDRESSES[0])
        expect(await pair.token1()).to.eq(TEST_ADDRESSES[1])
    }

    it('createPair', async () => {
        await createPair(TEST_ADDRESSES)
    })

    it('createPair:reverse', async () => {
        await createPair(TEST_ADDRESSES.slice().reverse() as [string, string])
    })

    it.skip('createPair:gas', async () => {
        const gasPrice = utils.parseUnits('10', 'gwei');  // Set your desired gas price
        const tx = await factory.createPair(...TEST_ADDRESSES, {gasLimit: 9999999, gasPrice: gasPrice})
        const receipt = await tx.wait()
        expect(receipt.gasUsed).to.eq(2302567)
    })

    it('setFeeTo', async () => {
        await expect(factory.connect(other).setFeeTo(other.address)).to.be.revertedWith('UniswapV2: FORBIDDEN')
        await factory.setFeeTo(wallet.address)
        expect(await factory.feeTo()).to.eq(wallet.address)
    })

    it('setFeeToSetter', async () => {
        await expect(factory.connect(other).setFeeToSetter(other.address)).to.be.revertedWith('UniswapV2: FORBIDDEN')
        await factory.setFeeToSetter(other.address)
        expect(await factory.feeToSetter()).to.eq(other.address)
        await expect(factory.setFeeToSetter(wallet.address)).to.be.revertedWith('UniswapV2: FORBIDDEN')
    })
})