// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./fixtures/UniswapSetup.sol";

contract UniswapV2PairTest is UniswapSetup {

    function setUp() public {
        usdc = new ERC20Test("USDC", "USDC");
        wbtc = new ERC20Test("Wrapped Bitcoin", "WBTC");
        weth = new WETH9();

        owner = address(this);

        uint256 amount = 1_000_000 * 1e18;

        addr1 = vm.addr(5);
        usdc.mint(addr1, amount);
        wbtc.mint(addr1, amount);

        addr2 = vm.addr(6);
        usdc.mint(addr2, amount);
        wbtc.mint(addr2, amount);

        initUniswap(owner, address(weth), address(usdc), address(wbtc));

        address[] memory _addresses = new address[](2);
        _addresses[0] = addr1;
        _addresses[1] = addr2;
        address[] memory _tokens = new address[](3);
        _tokens[0] = address(weth);
        _tokens[1] = address(usdc);
        _tokens[2] = address(wbtc);

        approveRouter(_addresses, _tokens);
    }

    function depositLiquidityInCFMM(address addr, uint256 usdcAmount, uint256 wbtcAmount) public {
        vm.startPrank(addr);
        addLiquidity(address(usdc), address(wbtc), usdcAmount, wbtcAmount, addr); // 1 weth = 1,000 USDC
        vm.stopPrank();
    }

    function withdrawLiquidityFromCFMM(address addr, uint256 liquidity) public {
        vm.startPrank(addr);
        removeLiquidity(address(usdc), address(wbtc), liquidity); // 1 wbtc = 1 USDC
        vm.stopPrank();
    }

    function sell_wbtc(address addr, uint256 amount) public {
        vm.startPrank(addr);
        sellTokenIn(amount, address(wbtc), address(usdc), msg.sender); // quote: 1 wbtc = 1 USDC
        vm.stopPrank();
    }

    function testTradingFees1pct() public {
        depositLiquidityInCFMM(addr1, 100*1e18, 100*1e18);
        (uint256 reserve0, uint256 reserve1,) = uniPair.getReserves();
        assertEq(reserve0, 100*1e18);
        assertEq(reserve1, 100*1e18);

        uint256 liquidity = Math.sqrt(reserve0 * reserve1);

        sell_wbtc(addr1, 1*1e18);

        (reserve0, reserve1,) = uniPair.getReserves();
        assertNotEq(reserve0, 100*1e18);
        assertNotEq(reserve1, 100*1e18);

        assertEq(liquidity, Math.sqrt(reserve0 * reserve1));
    }

    function testTradingFees2pct() public {
        depositLiquidityInCFMM(addr1, 100*1e18, 100*1e18);
        (uint256 reserve0, uint256 reserve1,) = uniPair.getReserves();
        assertEq(reserve0, 100*1e18);
        assertEq(reserve1, 100*1e18);

        uint256 liquidity = Math.sqrt(reserve0 * reserve1);

        sell_wbtc(addr1, 2*1e18);

        (reserve0, reserve1,) = uniPair.getReserves();
        assertNotEq(reserve0, 100*1e18);
        assertNotEq(reserve1, 100*1e18);

        assertEq(liquidity, Math.sqrt(reserve0 * reserve1));
    }

    function testTradingFees3pct() public {
        depositLiquidityInCFMM(addr1, 100*1e18, 100*1e18);
        (uint256 reserve0, uint256 reserve1,) = uniPair.getReserves();
        assertEq(reserve0, 100*1e18);
        assertEq(reserve1, 100*1e18);

        uint256 liquidity = Math.sqrt(reserve0 * reserve1);

        sell_wbtc(addr1, 3*1e18);

        (reserve0, reserve1,) = uniPair.getReserves();
        assertNotEq(reserve0, 100*1e18);
        assertNotEq(reserve1, 100*1e18);

        assertEq(liquidity, Math.sqrt(reserve0 * reserve1));
    }

    function testTradingFees4pct() public {
        depositLiquidityInCFMM(addr1, 100*1e18, 100*1e18);
        (uint256 reserve0, uint256 reserve1,) = uniPair.getReserves();
        assertEq(reserve0, 100*1e18);
        assertEq(reserve1, 100*1e18);

        uint256 liquidity = Math.sqrt(reserve0 * reserve1);

        sell_wbtc(addr1, 4*1e18);

        (reserve0, reserve1,) = uniPair.getReserves();
        assertNotEq(reserve0, 100*1e18);
        assertNotEq(reserve1, 100*1e18);

        assertEq(liquidity, Math.sqrt(reserve0 * reserve1));
    }

    function testTradingFees5pct() public {
        depositLiquidityInCFMM(addr1, 100*1e18, 100*1e18);
        (uint256 reserve0, uint256 reserve1,) = uniPair.getReserves();
        assertEq(reserve0, 100*1e18);
        assertEq(reserve1, 100*1e18);

        uint256 liquidity = Math.sqrt(reserve0 * reserve1);

        sell_wbtc(addr1, 5*1e18);

        (reserve0, reserve1,) = uniPair.getReserves();
        assertNotEq(reserve0, 100*1e18);
        assertNotEq(reserve1, 100*1e18);

        assertLt(liquidity, Math.sqrt(reserve0 * reserve1));
    }

    function testSetGammaPool() public {
        address gsFactory = vm.addr(100);
        uint16 protocolId = 1;
        address implementation = vm.addr(200);
        bytes32 gsPoolKey = keccak256(abi.encode(address(uniPair), protocolId));

        address poolAddr = GammaSwapLib.predictDeterministicAddress(implementation, gsPoolKey, gsFactory);

        vm.startPrank(address(uniFactory));
        uniPair.setGammaPool(gsFactory,  implementation, protocolId);
        vm.stopPrank();

        assertEq(uniPair.gammaPool(), poolAddr);
    }

    function testSetGammaPoolFail() public {
        address gsFactory = vm.addr(100);
        uint16 protocolId = 1;
        address implementation = vm.addr(200);
        bytes32 gsPoolKey = keccak256(abi.encode(address(uniPair), protocolId));
        vm.expectRevert("UniswapV2: FORBIDDEN");
        uniPair.setGammaPool(gsFactory,  implementation, protocolId);
    }

    function testTradingFeesGS() public {
        depositLiquidityInCFMM(addr1, 100*1e18, 100*1e18);
        (uint256 reserve0, uint256 reserve1,) = uniPair.getReserves();
        assertEq(reserve0, 100*1e18);
        assertEq(reserve1, 100*1e18);

        uint256 liquidity = Math.sqrt(reserve0 * reserve1);

        address gsFactory = vm.addr(100);
        uint16 protocolId = 1;
        address implementation = vm.addr(200);
        bytes32 gsPoolKey = keccak256(abi.encode(address(uniPair), protocolId));

        vm.startPrank(address(uniFactory));
        uniPair.setGammaPool(gsFactory,  implementation, protocolId);
        vm.stopPrank();

        address poolAddr = GammaSwapLib.predictDeterministicAddress(implementation, gsPoolKey, gsFactory);

        wbtc.mint(poolAddr, 10*1e18);
        uint256 amountIn = 5*1e18;

        (reserve0, reserve1,) = uniPair.getReserves();
        uint256 amountOut = uniRouter.getAmountOut(amountIn, reserve0, reserve1, 0);

        vm.startPrank(poolAddr);
        wbtc.transfer(address(uniPair), amountIn);
        uniPair.swap(0, amountOut, poolAddr, new bytes(0));
        vm.stopPrank();

        (reserve0, reserve1,) = uniPair.getReserves();
        assertNotEq(reserve0, 100*1e18);
        assertNotEq(reserve1, 100*1e18);

        assertEq(liquidity, Math.sqrt(reserve0 * reserve1));
    }

    function testTradeLiquidityEMA() public {
        uint128 reserve0;
        uint128 reserve1;
        uint256 tradeSum;
        uint256 tradeBlockNum;
        uint256 tradeLiquidityEMA;
        uint256 lastTradeLiquidityEMA;

        (reserve0, reserve1,) = uniPair.getReserves();
        assertEq(reserve0, 0);
        assertEq(reserve1, 0);
        (tradeLiquidityEMA, lastTradeLiquidityEMA,) = uniPair.getTradeLiquidityEMA(0);
        assertEq(tradeLiquidityEMA, 0);
        assertEq(lastTradeLiquidityEMA, 0);

        depositLiquidityInCFMM(addr1, 100*1e18, 100*1e18);
        (reserve0, reserve1,) = uniPair.getReserves();
        assertEq(reserve0, 100*1e18);
        assertEq(reserve1, 100*1e18);

        sell_wbtc(addr1, 1*1e18);

        (tradeLiquidityEMA, lastTradeLiquidityEMA,) = uniPair.getTradeLiquidityEMA(0*1e18);
        assertEq(tradeLiquidityEMA, 1*1e18);
        assertEq(lastTradeLiquidityEMA, 1*1e18);

        (tradeLiquidityEMA, lastTradeLiquidityEMA,) = uniPair.getTradeLiquidityEMA(1*1e18);
        assertEq(tradeLiquidityEMA, 12*1e17);
        assertEq(lastTradeLiquidityEMA, 1*1e18);

        uint256 tradeLiq = calculateTradeLiquidity(1*1e18);

        (tradeLiquidityEMA, lastTradeLiquidityEMA,) = uniPair.getTradeLiquidityEMA(tradeLiq);

        uint256 expectedTradeLiquidityEMA = tradeLiquidityEMA;
        sell_wbtc(addr1, 1*1e18);

        (tradeLiquidityEMA, lastTradeLiquidityEMA,) = uniPair.getTradeLiquidityEMA(0);
        assertEq(lastTradeLiquidityEMA,expectedTradeLiquidityEMA);
        assertEq(tradeLiquidityEMA,expectedTradeLiquidityEMA);

        vm.roll(2);

        (tradeLiquidityEMA, lastTradeLiquidityEMA,) = uniPair.getTradeLiquidityEMA(0);
        assertEq(lastTradeLiquidityEMA,expectedTradeLiquidityEMA);
        assertEq(tradeLiquidityEMA,lastTradeLiquidityEMA);

        expectedTradeLiquidityEMA = lastTradeLiquidityEMA;

        tradeLiq = calculateTradeLiquidity(1*1e18);

        (tradeLiquidityEMA, lastTradeLiquidityEMA,) = uniPair.getTradeLiquidityEMA(tradeLiq);
        assertEq(lastTradeLiquidityEMA,expectedTradeLiquidityEMA);
        assertLt(tradeLiquidityEMA,lastTradeLiquidityEMA);

        expectedTradeLiquidityEMA = tradeLiquidityEMA;

        sell_wbtc(addr1, 1*1e18);

        (tradeLiquidityEMA, lastTradeLiquidityEMA,) = uniPair.getTradeLiquidityEMA(0);
        assertEq(lastTradeLiquidityEMA,expectedTradeLiquidityEMA);
        assertEq(tradeLiquidityEMA,expectedTradeLiquidityEMA);

        tradeLiq = calculateTradeLiquidity(2*1e18);

        (tradeLiquidityEMA, lastTradeLiquidityEMA,) = uniPair.getTradeLiquidityEMA(tradeLiq);
        assertEq(lastTradeLiquidityEMA,expectedTradeLiquidityEMA);
        assertNotEq(tradeLiquidityEMA,expectedTradeLiquidityEMA);

        expectedTradeLiquidityEMA = tradeLiquidityEMA;

        sell_wbtc(addr1, 2*1e18);

        (tradeLiquidityEMA, lastTradeLiquidityEMA,) = uniPair.getTradeLiquidityEMA(0);
        assertEq(lastTradeLiquidityEMA, expectedTradeLiquidityEMA);
        assertEq(tradeLiquidityEMA, expectedTradeLiquidityEMA);

        expectedTradeLiquidityEMA = lastTradeLiquidityEMA;

        vm.roll(52);

        (tradeLiquidityEMA, lastTradeLiquidityEMA,) = uniPair.getTradeLiquidityEMA(0);
        assertEq(lastTradeLiquidityEMA, expectedTradeLiquidityEMA);
        assertEq(tradeLiquidityEMA, expectedTradeLiquidityEMA);

        tradeLiq = calculateTradeLiquidity(3*1e18);

        (tradeLiquidityEMA, lastTradeLiquidityEMA,) = uniPair.getTradeLiquidityEMA(tradeLiq);
        assertEq(lastTradeLiquidityEMA, expectedTradeLiquidityEMA);
        assertNotEq(tradeLiquidityEMA, expectedTradeLiquidityEMA);

        expectedTradeLiquidityEMA = tradeLiquidityEMA;

        sell_wbtc(addr1, 3*1e18);

        (tradeLiquidityEMA, lastTradeLiquidityEMA,) = uniPair.getTradeLiquidityEMA(0);
        assertEq(lastTradeLiquidityEMA, expectedTradeLiquidityEMA);
        assertEq(tradeLiquidityEMA, expectedTradeLiquidityEMA);

        vm.roll(102);

        (tradeLiquidityEMA, lastTradeLiquidityEMA,) = uniPair.getTradeLiquidityEMA(0);
        assertEq(lastTradeLiquidityEMA, expectedTradeLiquidityEMA);
        assertEq(tradeLiquidityEMA, expectedTradeLiquidityEMA);

        vm.roll(103);

        (tradeLiquidityEMA, lastTradeLiquidityEMA,) = uniPair.getTradeLiquidityEMA(0);
        assertEq(lastTradeLiquidityEMA, 0);
        assertEq(tradeLiquidityEMA, 0);

        tradeLiq = calculateTradeLiquidity(4*1e18);

        (tradeLiquidityEMA, lastTradeLiquidityEMA,) = uniPair.getTradeLiquidityEMA(tradeLiq);
        assertEq(lastTradeLiquidityEMA, 0);
        assertEq(tradeLiquidityEMA, tradeLiq);

        expectedTradeLiquidityEMA = tradeLiquidityEMA;

        sell_wbtc(addr1, 4*1e18);

        (tradeLiquidityEMA, lastTradeLiquidityEMA,) = uniPair.getTradeLiquidityEMA(0);
        assertEq(lastTradeLiquidityEMA, expectedTradeLiquidityEMA);
        assertEq(tradeLiquidityEMA, expectedTradeLiquidityEMA);
    }

    function calculateTradeLiquidity(uint256 amount) internal view returns(uint256) {
        (uint256 reserve0, uint256 reserve1,) = uniPair.getReserves();
        return GammaSwapLib.calcTradeLiquidity(amount, 0, reserve0, reserve1);
    }

    function testTradeLiquiditySum() public {
        uint128 reserve0;
        uint128 reserve1;
        uint256 tradeLiquiditySum;
        uint256 tradeBlockNum;

        (reserve0, reserve1,) = uniPair.getReserves();
        assertEq(reserve0, 0);
        assertEq(reserve1, 0);
        (tradeLiquiditySum, tradeBlockNum) = uniPair.getLastTradeLiquiditySum(0);
        assertEq(tradeLiquiditySum, 0);
        assertEq(tradeBlockNum, 0);

        depositLiquidityInCFMM(addr1, 100*1e18, 100*1e18);
        (reserve0, reserve1,) = uniPair.getReserves();
        assertEq(reserve0, 100*1e18);
        assertEq(reserve1, 100*1e18);

        uint256 tradeLiq = GammaSwapLib.calcTradeLiquidity(1*1e18, 0, reserve0, reserve1);
        sell_wbtc(addr1, 1*1e18);

        (tradeLiquiditySum, tradeBlockNum) = uniPair.getLastTradeLiquiditySum(0);
        assertEq(tradeLiquiditySum, tradeLiq);
        assertEq(tradeBlockNum, 1);

        uint256 prevTradeLiquiditySum = tradeLiquiditySum;

        (tradeLiquiditySum, tradeBlockNum) = uniPair.getLastTradeLiquiditySum(1e18);
        assertEq(tradeLiquiditySum, 2*1e18);
        assertEq(tradeBlockNum, 1);

        (tradeLiquiditySum, tradeBlockNum) = uniPair.getLastTradeLiquiditySum(4*1e18);
        assertEq(tradeLiquiditySum, 5*1e18);
        assertEq(tradeBlockNum, 1);

        (reserve0, reserve1,) = uniPair.getReserves();
        tradeLiq = GammaSwapLib.calcTradeLiquidity(1*1e18, 0, reserve0, reserve1);

        sell_wbtc(addr1, 1*1e18);

        (tradeLiquiditySum, tradeBlockNum) = uniPair.getLastTradeLiquiditySum(0*1e18);
        assertEq(tradeBlockNum, 1);
        assertEq(tradeLiquiditySum,tradeLiq + prevTradeLiquiditySum);

        prevTradeLiquiditySum = tradeLiquiditySum;

        (reserve0, reserve1,) = uniPair.getReserves();
        tradeLiq = GammaSwapLib.calcTradeLiquidity(1*1e18, 0, reserve0, reserve1);

        sell_wbtc(addr1, 1*1e18);

        (tradeLiquiditySum, tradeBlockNum) = uniPair.getLastTradeLiquiditySum(2*1e18);
        assertEq(tradeBlockNum, 1);
        assertEq(tradeLiquiditySum,tradeLiq + prevTradeLiquiditySum + 2*1e18);

        vm.roll(2);

        (tradeLiquiditySum, tradeBlockNum) = uniPair.getLastTradeLiquiditySum(0);
        assertEq(tradeBlockNum, 1);
        assertEq(tradeLiquiditySum,0);

        (tradeLiquiditySum, tradeBlockNum) = uniPair.getLastTradeLiquiditySum(2*1e18);
        assertEq(tradeBlockNum, 1);
        assertEq(tradeLiquiditySum,2*1e18);

        (reserve0, reserve1,) = uniPair.getReserves();
        tradeLiq = GammaSwapLib.calcTradeLiquidity(2*1e18, 0, reserve0, reserve1);

        sell_wbtc(addr1, 2*1e18);

        (tradeLiquiditySum, tradeBlockNum) = uniPair.getLastTradeLiquiditySum(0);
        assertEq(tradeBlockNum, 2);
        assertEq(tradeLiquiditySum,tradeLiq);

        (tradeLiquiditySum, tradeBlockNum) = uniPair.getLastTradeLiquiditySum(tradeLiq);
        assertEq(tradeBlockNum, 2);
        assertEq(tradeLiquiditySum,tradeLiq * 2);

        (reserve0, reserve1,) = uniPair.getReserves();
        tradeLiq = GammaSwapLib.calcTradeLiquidity(2*1e18, 0, reserve0, reserve1);

        (tradeLiquiditySum, tradeBlockNum) = uniPair.getLastTradeLiquiditySum(0);
        prevTradeLiquiditySum = tradeLiquiditySum;

        sell_wbtc(addr1, 2*1e18);

        (tradeLiquiditySum, tradeBlockNum) = uniPair.getLastTradeLiquiditySum(0);
        assertEq(tradeBlockNum, 2);
        assertEq(tradeLiquiditySum,prevTradeLiquiditySum + tradeLiq);

        vm.roll(10);

        (tradeLiquiditySum, tradeBlockNum) = uniPair.getLastTradeLiquiditySum(0);
        assertEq(tradeBlockNum, 2);
        assertEq(tradeLiquiditySum,0);

        (reserve0, reserve1,) = uniPair.getReserves();
        tradeLiq = GammaSwapLib.calcTradeLiquidity(3*1e18, 0, reserve0, reserve1);

        sell_wbtc(addr1, 3*1e18);

        (tradeLiquiditySum, tradeBlockNum) = uniPair.getLastTradeLiquiditySum(0);
        assertEq(tradeBlockNum, 10);
        assertEq(tradeLiquiditySum, tradeLiq);
    }

    function testLiquidityEMA() public {
        uint128 reserve0;
        uint128 reserve1;
        uint256 liquidityEMA;
        uint256 lastLiquidityEMABlockNum;

        (reserve0, reserve1,) = uniPair.getReserves();
        assertEq(reserve0, 0);
        assertEq(reserve1, 0);
        (liquidityEMA,lastLiquidityEMABlockNum) = uniPair.getLiquidityEMA();
        assertEq(lastLiquidityEMABlockNum, 0);
        assertEq(liquidityEMA, 0);

        depositLiquidityInCFMM(addr1, 1*1e18, 1*1e18);
        (reserve0, reserve1,) = uniPair.getReserves();
        assertEq(reserve0, 1*1e18);
        assertEq(reserve1, 1*1e18);
        (liquidityEMA,lastLiquidityEMABlockNum) = uniPair.getLiquidityEMA();
        assertEq(lastLiquidityEMABlockNum, 1);
        assertEq(liquidityEMA, 1*1e18);

        depositLiquidityInCFMM(addr1, 1*1e18, 1*1e18);
        (reserve0, reserve1,) = uniPair.getReserves();
        assertEq(reserve0, 2*1e18);
        assertEq(reserve1, 2*1e18);
        (liquidityEMA,lastLiquidityEMABlockNum) = uniPair.getLiquidityEMA();
        assertEq(lastLiquidityEMABlockNum, 1);
        assertEq(liquidityEMA, 1*1e18);

        vm.roll(2);

        depositLiquidityInCFMM(addr1, 1*1e18, 1*1e18);
        (reserve0, reserve1,) = uniPair.getReserves();
        assertEq(reserve0, 3*1e18);
        assertEq(reserve1, 3*1e18);
        (liquidityEMA,lastLiquidityEMABlockNum) = uniPair.getLiquidityEMA();
        assertEq(lastLiquidityEMABlockNum, 2);
        assertEq(liquidityEMA, 12*1e17);

        vm.roll(6);

        depositLiquidityInCFMM(addr1, 3*1e18, 3*1e18);
        (reserve0, reserve1,) = uniPair.getReserves();
        assertEq(reserve0, 6*1e18);
        assertEq(reserve1, 6*1e18);
        (liquidityEMA,lastLiquidityEMABlockNum) = uniPair.getLiquidityEMA();
        assertEq(lastLiquidityEMABlockNum, 6);
        assertEq(liquidityEMA, 168*1e16);

        withdrawLiquidityFromCFMM(addr1, 4*1e18);
        (reserve0, reserve1,) = uniPair.getReserves();
        assertEq(reserve0, 2*1e18);
        assertEq(reserve1, 2*1e18);
        (liquidityEMA,lastLiquidityEMABlockNum) = uniPair.getLiquidityEMA();
        assertEq(lastLiquidityEMABlockNum, 6);
        assertEq(liquidityEMA, 168*1e16);

        depositLiquidityInCFMM(addr1, 2*1e18, 2*1e18);
        (reserve0, reserve1,) = uniPair.getReserves();
        assertEq(reserve0, 4*1e18);
        assertEq(reserve1, 4*1e18);
        (liquidityEMA,lastLiquidityEMABlockNum) = uniPair.getLiquidityEMA();
        assertEq(lastLiquidityEMABlockNum, 6);
        assertEq(liquidityEMA, 168*1e16);

        vm.roll(7);
        (reserve0, reserve1,) = uniPair.getReserves();
        assertEq(reserve0, 4*1e18);
        assertEq(reserve1, 4*1e18);
        (liquidityEMA,lastLiquidityEMABlockNum) = uniPair.getLiquidityEMA();
        assertEq(lastLiquidityEMABlockNum, 6);
        assertEq(liquidityEMA, 168*1e16); // not updated yet

        uniPair.sync();
        (reserve0, reserve1,) = uniPair.getReserves();
        assertEq(reserve0, 4*1e18);
        assertEq(reserve1, 4*1e18);
        (liquidityEMA,lastLiquidityEMABlockNum) = uniPair.getLiquidityEMA();
        assertEq(lastLiquidityEMABlockNum, 7);
        assertEq(liquidityEMA, 1912*1e15);

        vm.roll(10);
        depositLiquidityInCFMM(addr1, 4*1e18, 4*1e18);
        (reserve0, reserve1,) = uniPair.getReserves();
        assertEq(reserve0, 8*1e18);
        assertEq(reserve1, 8*1e18);
        (liquidityEMA,lastLiquidityEMABlockNum) = uniPair.getLiquidityEMA();
        assertEq(lastLiquidityEMABlockNum, 10);
        assertEq(liquidityEMA, 25208*1e14);

        vm.roll(11);

        withdrawLiquidityFromCFMM(addr1, 6*1e18);
        (reserve0, reserve1,) = uniPair.getReserves();
        assertEq(reserve0, 2*1e18);
        assertEq(reserve1, 2*1e18);
        (liquidityEMA,lastLiquidityEMABlockNum) = uniPair.getLiquidityEMA();
        assertEq(lastLiquidityEMABlockNum, 11);
        assertEq(liquidityEMA, 246872*1e13);
    }
}
