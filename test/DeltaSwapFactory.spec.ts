import { ethers } from "hardhat";
import { expect } from 'chai'
import { BigNumber, Contract, utils, constants } from 'ethers'
import { config, userConfig } from "hardhat";

import { getCreate2Address } from './shared/utilities'
import { factoryFixture } from './shared/fixtures'

const TEST_ADDRESSES: [string, string] = [
    '0x1000000000000000000000000000000000000000',
    '0x2000000000000000000000000000000000000000'
]

const formatObject = (obj: any) => {
    return JSON.stringify(obj, (key, value) =>
        typeof value === 'bigint'
            ? value.toString()
            : value
    , 2);
}

describe('DeltaSwapFactory', () => {
    let DeltaSwapPair: any;
    let wallet: any;
    let other: any;
    let factory: Contract

    beforeEach(async () => {
        DeltaSwapPair = await ethers.getContractFactory("DeltaSwapPair");
        [wallet, other] = await ethers.getSigners();
        const fixture = await factoryFixture(wallet)
        factory = fixture.factory
        //console.log('============', formatObject(config), formatObject(userConfig));
        //console.log("initCodeHash >> ", utils.keccak256(DeltaSwapPair.bytecode).toString())
    })

    it('feeTo, feeToSetter, allPairsLength', async () => {
        expect(await factory.feeTo()).to.eq(constants.AddressZero)
        expect(await factory.feeToSetter()).to.eq(wallet.address)
        expect(await factory.allPairsLength()).to.eq(0)
    })

    async function createPair(tokens: [string, string]) {
        const bytecode = `${DeltaSwapPair.bytecode}`
        const create2Address = getCreate2Address(factory.address, tokens, bytecode)
        await expect(factory.createPair(...tokens))
            .to.emit(factory, 'PairCreated')
            .withArgs(TEST_ADDRESSES[0], TEST_ADDRESSES[1], create2Address, BigNumber.from(1))

        await expect(factory.createPair(...tokens)).to.be.reverted // DeltaSwap: PAIR_EXISTS
        await expect(factory.createPair(...tokens.slice().reverse())).to.be.reverted // DeltaSwap: PAIR_EXISTS
        expect(await factory.getPair(...tokens)).to.eq(create2Address)
        expect(await factory.getPair(...tokens.slice().reverse())).to.eq(create2Address)
        expect(await factory.allPairs(0)).to.eq(create2Address)
        expect(await factory.allPairsLength()).to.eq(1)

        const pair = DeltaSwapPair.attach(create2Address);
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

    it('createPair:gas', async () => {
        const gasPrice = utils.parseUnits('10', 'gwei');  // Set your desired gas price
        const tx = await factory.createPair(...TEST_ADDRESSES, {gasLimit: 9999999, gasPrice: gasPrice})
        const receipt = await tx.wait()
        expect(receipt.gasUsed).to.eq(2309658)
    })

    it('setFeeTo', async () => {
        await expect(factory.connect(other).setFeeTo(other.address)).to.be.revertedWith('DeltaSwap: FORBIDDEN')
        await factory.setFeeTo(wallet.address)
        expect(await factory.feeTo()).to.eq(wallet.address)
    })

    it('setFeeToSetter', async () => {
        await expect(factory.connect(other).setFeeToSetter(other.address)).to.be.revertedWith('DeltaSwap: FORBIDDEN')
        await factory.setFeeToSetter(other.address)
        expect(await factory.feeToSetter()).to.eq(other.address)
        await expect(factory.setFeeToSetter(wallet.address)).to.be.revertedWith('DeltaSwap: FORBIDDEN')
    })

    it('setGammaPool', async () => {
        const res = await (await factory.createPair(...TEST_ADDRESSES)).wait();
        const pair = DeltaSwapPair.attach(res.events[0].args.pair);
        expect(await pair.gammaPool()).to.eq(constants.AddressZero);

        const addr1 = '0x3000000000000000000000000000000000000000';
        const addr2 = '0x4000000000000000000000000000000000000000';
        await expect(factory.connect(other).setGammaPool(TEST_ADDRESSES[0], TEST_ADDRESSES[1], addr1, addr2, 1)).to.be.revertedWith('DeltaSwap: FORBIDDEN');
        expect(await pair.gammaPool()).to.eq(constants.AddressZero);

        await (await factory.setGammaPool(TEST_ADDRESSES[0], TEST_ADDRESSES[1], addr1, addr2, 1)).wait();
        expect(await pair.gammaPool()).to.not.eq(constants.AddressZero);
    })
})