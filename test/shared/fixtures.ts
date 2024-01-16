import { ethers } from "hardhat";
import { BigNumber, Contract } from 'ethers'
import { expandTo18Decimals } from './utilities'

const UniswapV1FactoryJSON = require("../../buildV1/UniswapV1Factory.json");
const UniswapV1ExchangeJSON = require("../../buildV1/UniswapV1Exchange.json");
const GammaPoolFactoryJSON = require("@gammaswap/v1-core/artifacts/contracts/GammaPoolFactory.sol/GammaPoolFactory.json");

const overrides = {
    gasLimit: 9999999
}

interface FactoryFixture {
    factory: Contract
}

interface PairFixture extends FactoryFixture {
    token0: Contract
    token1: Contract
    pair: Contract
}

interface V2Fixture {
    token0: Contract
    token1: Contract
    WETH: Contract
    WETHPartner: Contract
    factoryV1: Contract
    factoryV2: Contract
    router01: Contract
    router02: Contract
    routerEventEmitter: Contract
    router: Contract
    //migrator: Contract
    WETHExchangeV1: Contract
    pair: Contract
    WETHPair: Contract
}

let DeltaSwapFactory: any;
let DeltaSwapPair: any;
let DeltaSwapRouter01: any;
let DeltaSwapRouter02: any;
let RouterEventEmitter: any;
let UniswapV1Factory: any;
let UniswapV1Exchange: any;
let GammaPoolFactory: any;
let WETH9: any;
let ERC20: any;

export async function factoryFixture(wallet: any): Promise<FactoryFixture> {
    GammaPoolFactory = await ethers.getContractFactory(GammaPoolFactoryJSON.abi, GammaPoolFactoryJSON.bytecode, wallet);
    const gsFactory = await GammaPoolFactory.deploy(wallet.address, overrides);
    DeltaSwapFactory = await ethers.getContractFactory("DeltaSwapFactory");
    const factory = await DeltaSwapFactory.deploy(wallet.address, wallet.address, gsFactory.address, overrides);
    return { factory }
}

export async function pairFixture(wallet: any): Promise<PairFixture> {
    const { factory } = await factoryFixture(wallet);

    ERC20 = await ethers.getContractFactory("ERC20");
    const tokenA = await ERC20.deploy(expandTo18Decimals(10000), overrides);
    const tokenB = await ERC20.deploy(expandTo18Decimals(10000), overrides);

    await factory.createPair(tokenA.address, tokenB.address, overrides)
    const pairAddress = await factory.getPair(tokenA.address, tokenB.address)

    DeltaSwapPair = await ethers.getContractFactory("DeltaSwapPair");
    const pair = DeltaSwapPair.attach(pairAddress);

    const token0Address = (await pair.token0())
    const tokenAisToken0 = BigNumber.from(tokenA.address.toString()).eq(BigNumber.from(token0Address));
    const token0 = tokenAisToken0 ? tokenA : tokenB
    const token1 = tokenAisToken0 ? tokenB : tokenA

    return { factory, token0, token1, pair }
}

export async function v2Fixture(wallet: any): Promise<V2Fixture> {
    // deploy tokens
    ERC20 = await ethers.getContractFactory("ERC20");
    const tokenA = await ERC20.deploy(expandTo18Decimals(10000), overrides);
    const tokenB = await ERC20.deploy(expandTo18Decimals(10000), overrides);

    WETH9 = await ethers.getContractFactory("WETH9");
    const WETH = await WETH9.deploy();
    const WETHPartner = await ERC20.deploy(expandTo18Decimals(10000), overrides);

    // deploy V1
    UniswapV1Factory = await ethers.getContractFactory(UniswapV1FactoryJSON.abi, UniswapV1FactoryJSON.evm.bytecode.object, wallet);
    UniswapV1Exchange = await ethers.getContractFactory(UniswapV1ExchangeJSON.abi, UniswapV1ExchangeJSON.evm.bytecode.object, wallet);
    const exchangeV1 = await UniswapV1Exchange.deploy(overrides);
    const factoryV1 = await UniswapV1Factory.deploy(overrides);
    await (await factoryV1.initializeFactory(exchangeV1.address, overrides)).wait();

    GammaPoolFactory = await ethers.getContractFactory(GammaPoolFactoryJSON.abi, GammaPoolFactoryJSON.bytecode, wallet);
    const gsFactory = await GammaPoolFactory.deploy(wallet.address, overrides);

    // deploy V2
    DeltaSwapFactory = await ethers.getContractFactory("DeltaSwapFactory");
    const factoryV2 = await DeltaSwapFactory.deploy(wallet.address, wallet.address, gsFactory.address, overrides);

    // deploy routers
    DeltaSwapRouter01 = await ethers.getContractFactory("DeltaSwapRouter01");
    DeltaSwapRouter02 = await ethers.getContractFactory("DeltaSwapRouter02");
    const router01 = await DeltaSwapRouter01.deploy(factoryV2.address, WETH.address, overrides);
    const router02 = await DeltaSwapRouter02.deploy(factoryV2.address, WETH.address, overrides);

    // event emitter for testing
    RouterEventEmitter = await ethers.getContractFactory("RouterEventEmitter");
    const routerEventEmitter = await RouterEventEmitter.deploy();

    // deploy migrator
    //const migrator = await deployContract(wallet, UniswapV2Migrator, [factoryV1.address, router01.address], overrides)

    // initialize V1
    await (await factoryV1.createExchange(WETHPartner.address, overrides)).wait();
    const WETHExchangeV1Address = await factoryV1.getExchange(WETHPartner.address)
    const WETHExchangeV1 = UniswapV1Exchange.attach(WETHExchangeV1Address);

    // initialize V2
    await factoryV2.createPair(tokenA.address, tokenB.address);
    const pairAddress = await factoryV2.getPair(tokenA.address, tokenB.address);
    DeltaSwapPair = await ethers.getContractFactory("DeltaSwapPair");
    const pair = DeltaSwapPair.attach(pairAddress);

    const token0Address = await pair.token0()
    const token0 = tokenA.address === token0Address ? tokenA : tokenB
    const token1 = tokenA.address === token0Address ? tokenB : tokenA

    await factoryV2.createPair(WETH.address, WETHPartner.address)
    const WETHPairAddress = await factoryV2.getPair(WETH.address, WETHPartner.address)
    const WETHPair = DeltaSwapPair.attach(WETHPairAddress);

    return {
        token0,
        token1,
        WETH,
        WETHPartner,
        factoryV1,
        factoryV2,
        router01,
        router02,
        router: router02, // the default router, 01 had a minor bug
        routerEventEmitter,
        //migrator,
        WETHExchangeV1,
        pair,
        WETHPair
    }
}