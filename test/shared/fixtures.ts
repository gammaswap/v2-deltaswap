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

interface V2Fixture {
    token0: Contract
    token1: Contract
    WETH: Contract
    WETHPartner: Contract
    //factoryV1: Contract
    factoryV2: Contract
    router01: Contract
    router02: Contract
    routerEventEmitter: Contract
    router: Contract
    //migrator: Contract
    //WETHExchangeV1: Contract
    pair: Contract
    WETHPair: Contract
}

let UniswapV2Router01: any;
let UniswapV2Router02: any;
let RouterEventEmitter: any;
let WETH9: any;

//export async function v2Fixture(provider: Web3Provider, [wallet]: Wallet[]): Promise<V2Fixture> {
export async function v2Fixture(wallet: any): Promise<V2Fixture> {

    const { factory } = await factoryFixture(wallet);

    ERC20 = await ethers.getContractFactory("ERC20");
    const tokenA = await ERC20.deploy(expandTo18Decimals(10000), overrides);
    const tokenB = await ERC20.deploy(expandTo18Decimals(10000), overrides);

    WETH9 = await ethers.getContractFactory("WETH9");
    const WETH = await WETH9.deploy();
    const WETHPartner = await ERC20.deploy(expandTo18Decimals(10000), overrides);
    // deploy tokens
    /*const tokenA = await deployContract(wallet, ERC20, [expandTo18Decimals(10000)])
    const tokenB = await deployContract(wallet, ERC20, [expandTo18Decimals(10000)])
    const WETH = await deployContract(wallet, WETH9)
    const WETHPartner = await deployContract(wallet, ERC20, [expandTo18Decimals(10000)])/**/

    // deploy V1
    /*const factoryV1 = await deployContract(wallet, UniswapV1Factory, [])
    await factoryV1.initializeFactory((await deployContract(wallet, UniswapV1Exchange, [])).address)/**/

    // deploy V2
    UniswapV2Factory = await ethers.getContractFactory("UniswapV2Factory");
    const factoryV2 = await UniswapV2Factory.deploy(wallet.address, overrides);

    // deploy routers
    UniswapV2Router01 = await ethers.getContractFactory("UniswapV2Router01");
    UniswapV2Router02 = await ethers.getContractFactory("UniswapV2Router02");
    const router01 = await UniswapV2Router01.deploy(factoryV2.address, WETH.address, overrides);
    const router02 = await UniswapV2Router02.deploy(factoryV2.address, WETH.address, overrides);
    //const router01 = await deployContract(wallet, UniswapV2Router01, [factoryV2.address, WETH.address], overrides)
    //const router02 = await deployContract(wallet, UniswapV2Router02, [factoryV2.address, WETH.address], overrides)

    // event emitter for testing
    RouterEventEmitter = await ethers.getContractFactory("RouterEventEmitter");
    const routerEventEmitter = await RouterEventEmitter.deploy();
    //const routerEventEmitter = await deployContract(wallet, RouterEventEmitter, [])

    // deploy migrator
    //const migrator = await deployContract(wallet, UniswapV2Migrator, [factoryV1.address, router01.address], overrides)

    // initialize V1
    //await factoryV1.createExchange(WETHPartner.address, overrides)
    //const WETHExchangeV1Address = await factoryV1.getExchange(WETHPartner.address)
    //const WETHExchangeV1 = new Contract(WETHExchangeV1Address, JSON.stringify(UniswapV1Exchange.abi), provider).connect(
    //    wallet
    //)

    // initialize V2
    await factoryV2.createPair(tokenA.address, tokenB.address);
    const pairAddress = await factoryV2.getPair(tokenA.address, tokenB.address);
    UniswapV2Pair = await ethers.getContractFactory("UniswapV2Pair");
    const pair = UniswapV2Pair.attach(pairAddress);
    //const pair = new Contract(pairAddress, JSON.stringify(IUniswapV2Pair.abi), provider).connect(wallet)

    const token0Address = await pair.token0()
    const token0 = tokenA.address === token0Address ? tokenA : tokenB
    const token1 = tokenA.address === token0Address ? tokenB : tokenA

    await factoryV2.createPair(WETH.address, WETHPartner.address)
    const WETHPairAddress = await factoryV2.getPair(WETH.address, WETHPartner.address)
    const WETHPair = UniswapV2Pair.attach(WETHPairAddress);
    //const WETHPair = new Contract(WETHPairAddress, JSON.stringify(IUniswapV2Pair.abi), provider).connect(wallet)

    return {
        token0,
        token1,
        WETH,
        WETHPartner,
        //factoryV1,
        factoryV2,
        router01,
        router02,
        router: router02, // the default router, 01 had a minor bug
        routerEventEmitter,
        //migrator,
        //WETHExchangeV1,
        pair,
        WETHPair
    }
}