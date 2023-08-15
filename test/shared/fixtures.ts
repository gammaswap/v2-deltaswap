import { ethers } from "hardhat";
import {BigNumber, Contract, Wallet} from 'ethers'
import { expandTo18Decimals } from './utilities'

interface FactoryFixture {
    factory: Contract
}

interface PairFixture extends FactoryFixture {
    token0: Contract
    token1: Contract
    pair: Contract
}

const overrides = {
    gasLimit: 9999999
}

let UniswapV2Factory: any;
let UniswapV2Pair: any;
let ERC20: any;

export async function factoryFixture(wallet: any): Promise<FactoryFixture> {
    UniswapV2Factory = await ethers.getContractFactory("UniswapV2Factory");
    const factory = await UniswapV2Factory.deploy(wallet.address, overrides);
    return { factory }
}

export async function pairFixture(wallet: any): Promise<PairFixture> {
    const { factory } = await factoryFixture(wallet);

    ERC20 = await ethers.getContractFactory("ERC20");
    const tokenA = await ERC20.deploy(expandTo18Decimals(10000), overrides);
    const tokenB = await ERC20.deploy(expandTo18Decimals(10000), overrides);

    await factory.createPair(tokenA.address, tokenB.address, overrides)
    const pairAddress = await factory.getPair(tokenA.address, tokenB.address)

    UniswapV2Pair = await ethers.getContractFactory("UniswapV2Pair");
    const pair = UniswapV2Pair.attach(pairAddress);

    const token0Address = (await pair.token0())
    const tokenAisToken0 = BigNumber.from(tokenA.address.toString()).eq(BigNumber.from(token0Address));
    const token0 = tokenAisToken0 ? tokenA : tokenB
    const token1 = tokenAisToken0 ? tokenB : tokenA

    return { factory, token0, token1, pair }
}