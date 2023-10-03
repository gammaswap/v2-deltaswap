// SPDX-License-Identifier: GPL-v3
pragma solidity >=0.8.0;

import "./fixtures/DeltaSwapSetup.sol";

contract DeltaSwapPairTest is DeltaSwapSetup {

    WETH9 public weth;
    ERC20Test public usdc;
    ERC20Test public wbtc;

    address public owner;
    address public addr1;
    address public addr2;

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

        initDeltaSwap(owner, address(weth), address(usdc), address(wbtc));

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

    function testCalcTradingFee(uint256 lastLiquidityTradedEMA, uint128 lastLiquidityEMA) public {
        uint256 fee = dsPair.calcTradingFee(lastLiquidityTradedEMA, lastLiquidityEMA);
        if(lastLiquidityTradedEMA >= uint256(lastLiquidityEMA) * 200 / 10000) {// if trade >= 2% of liquidity, charge 0.3% fee => 1% of liquidity value, ~4.04% px change and 2.3% slippage
            assertEq(fee,3);
        } else if(lastLiquidityTradedEMA >= uint256(lastLiquidityEMA) * 100 / 10000) {// if trade >= 1% of liquidity, charge 0.2% fee => 0.5% of liquidity value, ~2.01% px change and 1.3% slippage
            assertEq(fee,2);
        } else if(lastLiquidityTradedEMA >= uint256(lastLiquidityEMA) * 50 / 10000) {// if trade >= 0.5% of liquidity, charge 0.1% fee => 0.25% of liquidity value, ~1% px change and 0.8 % slippage
            assertEq(fee,1);
        } else {
            assertEq(fee,0);
        }
    }

    function testTradingFeesHalfPctMinus1() public {
        depositLiquidityInCFMM(addr1, 100*1e18, 100*1e18);
        (uint256 reserve0, uint256 reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 100*1e18);
        assertEq(reserve1, 100*1e18);

        uint256 liquidity = DSMath.sqrt(reserve0 * reserve1);

        sell_wbtc(addr1, 5*1e17 - 1);

        (reserve0, reserve1,) = dsPair.getReserves();
        assertNotEq(reserve0, 100*1e18);
        assertNotEq(reserve1, 100*1e18);

        assertEq(liquidity, DSMath.sqrt(reserve0 * reserve1));
    }

    function testTradingFeesHalfPct() public {
        depositLiquidityInCFMM(addr1, 100*1e18, 100*1e18);
        (uint256 reserve0, uint256 reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 100*1e18);
        assertEq(reserve1, 100*1e18);

        uint256 liquidity = DSMath.sqrt(reserve0 * reserve1);

        sell_wbtc(addr1, 5*1e17);

        (reserve0, reserve1,) = dsPair.getReserves();
        assertNotEq(reserve0, 100*1e18);
        assertNotEq(reserve1, 100*1e18);

        assertLt(liquidity, DSMath.sqrt(reserve0 * reserve1));
    }

    function testTradingFeesHalfPctPlus1() public {
        depositLiquidityInCFMM(addr1, 100*1e18, 100*1e18);
        (uint256 reserve0, uint256 reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 100*1e18);
        assertEq(reserve1, 100*1e18);

        uint256 liquidity = DSMath.sqrt(reserve0 * reserve1);

        sell_wbtc(addr1, 5*1e17 + 1);

        (reserve0, reserve1,) = dsPair.getReserves();
        assertNotEq(reserve0, 100*1e18);
        assertNotEq(reserve1, 100*1e18);

        assertLt(liquidity, DSMath.sqrt(reserve0 * reserve1));
    }

    function testTradingFees1pct() public {
        depositLiquidityInCFMM(addr1, 100*1e18, 100*1e18);
        (uint256 reserve0, uint256 reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 100*1e18);
        assertEq(reserve1, 100*1e18);

        uint256 liquidity = DSMath.sqrt(reserve0 * reserve1);

        sell_wbtc(addr1, 1e18);

        (reserve0, reserve1,) = dsPair.getReserves();
        assertNotEq(reserve0, 100*1e18);
        assertNotEq(reserve1, 100*1e18);

        uint256 liqDiff = DSMath.sqrt(reserve0 * reserve1) - liquidity;
        uint256 ret = liqDiff * 1e18 / liquidity;
        assertLt(2*4950531810910, ret);
    }

    function testTradingFees2pct() public {
        depositLiquidityInCFMM(addr1, 100*1e18, 100*1e18);
        (uint256 reserve0, uint256 reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 100*1e18);
        assertEq(reserve1, 100*1e18);

        uint256 liquidity = DSMath.sqrt(reserve0 * reserve1);

        sell_wbtc(addr1, 2*1e18);

        (reserve0, reserve1,) = dsPair.getReserves();
        assertNotEq(reserve0, 100*1e18);
        assertNotEq(reserve1, 100*1e18);

        uint256 liqDiff = DSMath.sqrt(reserve0 * reserve1) - liquidity;
        uint256 ret = liqDiff * 1e18 / liquidity;
        assertLt(3*19608419857370/2, ret);
    }

    function testSetGammaPool() public {
        address gsFactory = vm.addr(100);
        uint16 protocolId = 1;
        address implementation = vm.addr(200);
        bytes32 gsPoolKey = keccak256(abi.encode(address(dsPair), protocolId));

        address poolAddr = DeltaSwapLibrary.predictDeterministicAddress(implementation, gsPoolKey, gsFactory);

        vm.startPrank(address(dsFactory));
        dsPair.setGammaPool(poolAddr);
        vm.stopPrank();

        assertEq(dsPair.gammaPool(), poolAddr);
    }

    function testSetGammaPoolFail() public {
        address gsFactory = vm.addr(100);
        uint16 protocolId = 1;
        address implementation = vm.addr(200);
        bytes32 gsPoolKey = keccak256(abi.encode(address(dsPair), protocolId));
        address poolAddr = DeltaSwapLibrary.predictDeterministicAddress(implementation, gsPoolKey, gsFactory);
        vm.expectRevert("DeltaSwap: FORBIDDEN");
        dsPair.setGammaPool(poolAddr);
    }

    function testTradingFeesGS() public {
        depositLiquidityInCFMM(addr1, 100*1e18, 100*1e18);
        (uint256 reserve0, uint256 reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 100*1e18);
        assertEq(reserve1, 100*1e18);

        uint256 liquidity = DSMath.sqrt(reserve0 * reserve1);

        address gsFactory = vm.addr(100);
        uint16 protocolId = 1;
        address implementation = vm.addr(200);
        bytes32 gsPoolKey = keccak256(abi.encode(address(dsPair), protocolId));

        address poolAddr = DeltaSwapLibrary.predictDeterministicAddress(implementation, gsPoolKey, gsFactory);

        vm.startPrank(address(dsFactory));
        dsPair.setGammaPool(poolAddr);
        vm.stopPrank();

        wbtc.mint(poolAddr, 10*1e18);
        uint256 amountIn = 5*1e18;

        (reserve0, reserve1,) = dsPair.getReserves();
        uint256 amountOut = dsRouter.getAmountOut(amountIn, reserve0, reserve1, 0);

        vm.startPrank(poolAddr);
        wbtc.transfer(address(dsPair), amountIn);
        vm.expectRevert("DeltaSwap: K");
        dsPair.swap(0, amountOut, poolAddr, new bytes(0));

        amountOut = dsRouter.getAmountOut(amountIn, reserve0, reserve1, 1);
        vm.expectRevert("DeltaSwap: K");
        dsPair.swap(0, amountOut, poolAddr, new bytes(0));

        amountOut = dsRouter.getAmountOut(amountIn, reserve0, reserve1, 2);
        vm.expectRevert("DeltaSwap: K");
        dsPair.swap(0, amountOut, poolAddr, new bytes(0));

        amountOut = dsRouter.getAmountOut(amountIn, reserve0, reserve1, 3);
        dsPair.swap(0, amountOut, poolAddr, new bytes(0));
        vm.stopPrank();

        (reserve0, reserve1,) = dsPair.getReserves();
        assertNotEq(reserve0, 100*1e18);
        assertNotEq(reserve1, 100*1e18);

        assertLt(liquidity, DSMath.sqrt(reserve0 * reserve1));
    }

    function testTradeLiquidityEMA() public {
        uint128 reserve0;
        uint128 reserve1;
        uint256 tradeLiquidityEMA;
        uint256 lastTradeLiquidityEMA;
        uint256 tradeLiquiditySum;

        (reserve0, reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 0);
        assertEq(reserve1, 0);
        (tradeLiquidityEMA, lastTradeLiquidityEMA, tradeLiquiditySum) = dsPair.getTradeLiquidityEMA(0);
        assertEq(tradeLiquidityEMA, 0);
        assertEq(lastTradeLiquidityEMA, 0);
        assertEq(tradeLiquiditySum, 0);

        depositLiquidityInCFMM(addr1, 100*1e18, 100*1e18);
        (reserve0, reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 100*1e18);
        assertEq(reserve1, 100*1e18);

        sell_wbtc(addr1, 1*1e18);

        (tradeLiquidityEMA, lastTradeLiquidityEMA, tradeLiquiditySum) = dsPair.getTradeLiquidityEMA(0*1e18);
        assertEq(tradeLiquidityEMA, 1*1e18);
        assertEq(lastTradeLiquidityEMA, 1*1e18);
        assertEq(tradeLiquiditySum, 1e18);

        (tradeLiquidityEMA, lastTradeLiquidityEMA, tradeLiquiditySum) = dsPair.getTradeLiquidityEMA(1*1e18);
        assertEq(tradeLiquidityEMA, 12*1e17);
        assertEq(lastTradeLiquidityEMA, 1*1e18);
        assertEq(tradeLiquiditySum, 2*1e18);

        uint256 tradeLiq = calculateTradeLiquidity(1*1e18);

        (tradeLiquidityEMA, lastTradeLiquidityEMA, tradeLiquiditySum) = dsPair.getTradeLiquidityEMA(tradeLiq);

        uint256 expectedTradeLiquidityEMA = tradeLiquidityEMA;
        sell_wbtc(addr1, 1*1e18);

        (tradeLiquidityEMA, lastTradeLiquidityEMA, tradeLiquiditySum) = dsPair.getTradeLiquidityEMA(0);
        assertEq(lastTradeLiquidityEMA,expectedTradeLiquidityEMA);
        assertEq(tradeLiquidityEMA,expectedTradeLiquidityEMA);
        assertEq(tradeLiquiditySum, 1*1e18 + tradeLiq);

        vm.roll(2);

        (tradeLiquidityEMA, lastTradeLiquidityEMA, tradeLiquiditySum) = dsPair.getTradeLiquidityEMA(0);
        assertEq(lastTradeLiquidityEMA,expectedTradeLiquidityEMA);
        assertEq(tradeLiquidityEMA,lastTradeLiquidityEMA);
        assertEq(tradeLiquiditySum, 0);

        expectedTradeLiquidityEMA = lastTradeLiquidityEMA;

        tradeLiq = calculateTradeLiquidity(1*1e18);

        (tradeLiquidityEMA, lastTradeLiquidityEMA, tradeLiquiditySum) = dsPair.getTradeLiquidityEMA(tradeLiq);
        assertEq(lastTradeLiquidityEMA,expectedTradeLiquidityEMA);
        assertLt(tradeLiquidityEMA,lastTradeLiquidityEMA);
        assertEq(tradeLiquiditySum, tradeLiq);

        expectedTradeLiquidityEMA = tradeLiquidityEMA;

        sell_wbtc(addr1, 1*1e18);

        (tradeLiquidityEMA, lastTradeLiquidityEMA, tradeLiquiditySum) = dsPair.getTradeLiquidityEMA(0);
        assertEq(lastTradeLiquidityEMA,expectedTradeLiquidityEMA);
        assertEq(tradeLiquidityEMA,expectedTradeLiquidityEMA);
        assertEq(tradeLiquiditySum, tradeLiq);

        uint256 prevTradeLiq = tradeLiq;
        tradeLiq = calculateTradeLiquidity(2*1e18);

        (tradeLiquidityEMA, lastTradeLiquidityEMA, tradeLiquiditySum) = dsPair.getTradeLiquidityEMA(tradeLiq);
        assertEq(lastTradeLiquidityEMA,expectedTradeLiquidityEMA);
        assertNotEq(tradeLiquidityEMA,expectedTradeLiquidityEMA);
        assertEq(tradeLiquiditySum, prevTradeLiq + tradeLiq);

        expectedTradeLiquidityEMA = tradeLiquidityEMA;

        sell_wbtc(addr1, 2*1e18);

        (tradeLiquidityEMA, lastTradeLiquidityEMA, tradeLiquiditySum) = dsPair.getTradeLiquidityEMA(0);
        assertEq(lastTradeLiquidityEMA, expectedTradeLiquidityEMA);
        assertEq(tradeLiquidityEMA, expectedTradeLiquidityEMA);
        assertEq(tradeLiquiditySum, prevTradeLiq + tradeLiq);

        expectedTradeLiquidityEMA = lastTradeLiquidityEMA;

        vm.roll(52);

        (tradeLiquidityEMA, lastTradeLiquidityEMA, tradeLiquiditySum) = dsPair.getTradeLiquidityEMA(0);
        assertEq(lastTradeLiquidityEMA, expectedTradeLiquidityEMA);
        assertEq(tradeLiquidityEMA, expectedTradeLiquidityEMA);
        assertEq(tradeLiquiditySum, 0);

        tradeLiq = calculateTradeLiquidity(3*1e18);

        (tradeLiquidityEMA, lastTradeLiquidityEMA, tradeLiquiditySum) = dsPair.getTradeLiquidityEMA(tradeLiq);
        assertEq(lastTradeLiquidityEMA, expectedTradeLiquidityEMA);
        assertNotEq(tradeLiquidityEMA, expectedTradeLiquidityEMA);
        assertEq(tradeLiquiditySum, tradeLiq);

        expectedTradeLiquidityEMA = tradeLiquidityEMA;

        sell_wbtc(addr1, 3*1e18);

        (tradeLiquidityEMA, lastTradeLiquidityEMA, tradeLiquiditySum) = dsPair.getTradeLiquidityEMA(0);
        assertEq(lastTradeLiquidityEMA, expectedTradeLiquidityEMA);
        assertEq(tradeLiquidityEMA, expectedTradeLiquidityEMA);
        assertEq(tradeLiquiditySum, tradeLiq);

        vm.roll(102);

        (tradeLiquidityEMA, lastTradeLiquidityEMA, tradeLiquiditySum) = dsPair.getTradeLiquidityEMA(0);
        assertEq(lastTradeLiquidityEMA, expectedTradeLiquidityEMA);
        assertEq(tradeLiquidityEMA, expectedTradeLiquidityEMA);
        assertEq(tradeLiquiditySum, 0);

        vm.roll(103);

        (tradeLiquidityEMA, lastTradeLiquidityEMA, tradeLiquiditySum) = dsPair.getTradeLiquidityEMA(0);
        assertEq(lastTradeLiquidityEMA, 0);
        assertEq(tradeLiquidityEMA, 0);
        assertEq(tradeLiquiditySum, 0);

        tradeLiq = calculateTradeLiquidity(4*1e18);

        (tradeLiquidityEMA, lastTradeLiquidityEMA, tradeLiquiditySum) = dsPair.getTradeLiquidityEMA(tradeLiq);
        assertEq(lastTradeLiquidityEMA, 0);
        assertEq(tradeLiquidityEMA, tradeLiq);
        assertEq(tradeLiquiditySum, tradeLiq);

        expectedTradeLiquidityEMA = tradeLiquidityEMA;

        sell_wbtc(addr1, 4*1e18);

        (tradeLiquidityEMA, lastTradeLiquidityEMA, tradeLiquiditySum) = dsPair.getTradeLiquidityEMA(0);
        assertEq(lastTradeLiquidityEMA, expectedTradeLiquidityEMA);
        assertEq(tradeLiquidityEMA, expectedTradeLiquidityEMA);
        assertEq(tradeLiquiditySum, tradeLiq);
    }

    function calculateTradeLiquidity(uint256 amount) internal view returns(uint256) {
        (uint256 reserve0, uint256 reserve1,) = dsPair.getReserves();
        return DSMath.calcTradeLiquidity(amount, 0, reserve0, reserve1);
    }

    function testTradeLiquiditySum() public {
        uint128 reserve0;
        uint128 reserve1;
        uint256 tradeLiquiditySum;
        uint256 tradeBlockNum;

        (reserve0, reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 0);
        assertEq(reserve1, 0);
        (tradeLiquiditySum, tradeBlockNum) = dsPair.getLastTradeLiquiditySum(0);
        assertEq(tradeLiquiditySum, 0);
        assertEq(tradeBlockNum, 0);

        depositLiquidityInCFMM(addr1, 100*1e18, 100*1e18);
        (reserve0, reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 100*1e18);
        assertEq(reserve1, 100*1e18);

        uint256 tradeLiq = DSMath.calcTradeLiquidity(1*1e18, 0, reserve0, reserve1);
        sell_wbtc(addr1, 1*1e18);

        (tradeLiquiditySum, tradeBlockNum) = dsPair.getLastTradeLiquiditySum(0);
        assertEq(tradeLiquiditySum, tradeLiq);
        assertEq(tradeBlockNum, 1);

        uint256 prevTradeLiquiditySum = tradeLiquiditySum;

        (tradeLiquiditySum, tradeBlockNum) = dsPair.getLastTradeLiquiditySum(1e18);
        assertEq(tradeLiquiditySum, 2*1e18);
        assertEq(tradeBlockNum, 1);

        (tradeLiquiditySum, tradeBlockNum) = dsPair.getLastTradeLiquiditySum(4*1e18);
        assertEq(tradeLiquiditySum, 5*1e18);
        assertEq(tradeBlockNum, 1);

        (reserve0, reserve1,) = dsPair.getReserves();
        tradeLiq = DSMath.calcTradeLiquidity(1*1e18, 0, reserve0, reserve1);

        sell_wbtc(addr1, 1*1e18);

        (tradeLiquiditySum, tradeBlockNum) = dsPair.getLastTradeLiquiditySum(0*1e18);
        assertEq(tradeBlockNum, 1);
        assertEq(tradeLiquiditySum,tradeLiq + prevTradeLiquiditySum);

        prevTradeLiquiditySum = tradeLiquiditySum;

        (reserve0, reserve1,) = dsPair.getReserves();
        tradeLiq = DSMath.calcTradeLiquidity(1*1e18, 0, reserve0, reserve1);

        sell_wbtc(addr1, 1*1e18);

        (tradeLiquiditySum, tradeBlockNum) = dsPair.getLastTradeLiquiditySum(2*1e18);
        assertEq(tradeBlockNum, 1);
        assertEq(tradeLiquiditySum,tradeLiq + prevTradeLiquiditySum + 2*1e18);

        vm.roll(2);

        (tradeLiquiditySum, tradeBlockNum) = dsPair.getLastTradeLiquiditySum(0);
        assertEq(tradeBlockNum, 1);
        assertEq(tradeLiquiditySum,0);

        (tradeLiquiditySum, tradeBlockNum) = dsPair.getLastTradeLiquiditySum(2*1e18);
        assertEq(tradeBlockNum, 1);
        assertEq(tradeLiquiditySum,2*1e18);

        (reserve0, reserve1,) = dsPair.getReserves();
        tradeLiq = DSMath.calcTradeLiquidity(2*1e18, 0, reserve0, reserve1);

        sell_wbtc(addr1, 2*1e18);

        (tradeLiquiditySum, tradeBlockNum) = dsPair.getLastTradeLiquiditySum(0);
        assertEq(tradeBlockNum, 2);
        assertEq(tradeLiquiditySum,tradeLiq);

        (tradeLiquiditySum, tradeBlockNum) = dsPair.getLastTradeLiquiditySum(tradeLiq);
        assertEq(tradeBlockNum, 2);
        assertEq(tradeLiquiditySum,tradeLiq * 2);

        (reserve0, reserve1,) = dsPair.getReserves();
        tradeLiq = DSMath.calcTradeLiquidity(2*1e18, 0, reserve0, reserve1);

        (tradeLiquiditySum, tradeBlockNum) = dsPair.getLastTradeLiquiditySum(0);
        prevTradeLiquiditySum = tradeLiquiditySum;

        sell_wbtc(addr1, 2*1e18);

        (tradeLiquiditySum, tradeBlockNum) = dsPair.getLastTradeLiquiditySum(0);
        assertEq(tradeBlockNum, 2);
        assertEq(tradeLiquiditySum,prevTradeLiquiditySum + tradeLiq);

        vm.roll(10);

        (tradeLiquiditySum, tradeBlockNum) = dsPair.getLastTradeLiquiditySum(0);
        assertEq(tradeBlockNum, 2);
        assertEq(tradeLiquiditySum,0);

        (reserve0, reserve1,) = dsPair.getReserves();
        tradeLiq = DSMath.calcTradeLiquidity(3*1e18, 0, reserve0, reserve1);

        sell_wbtc(addr1, 3*1e18);

        (tradeLiquiditySum, tradeBlockNum) = dsPair.getLastTradeLiquiditySum(0);
        assertEq(tradeBlockNum, 10);
        assertEq(tradeLiquiditySum, tradeLiq);
    }

    function testLiquidityEMATime() public {
        uint128 reserve0;
        uint128 reserve1;
        uint256 liquidityEMA;
        uint256 lastLiquidityEMABlockNum;

        (reserve0, reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 0);
        assertEq(reserve1, 0);
        (liquidityEMA,lastLiquidityEMABlockNum) = dsPair.getLiquidityEMA();
        assertEq(lastLiquidityEMABlockNum, 0);
        assertEq(liquidityEMA, 0);

        depositLiquidityInCFMM(addr1, 1*1e18, 1*1e18);
        (reserve0, reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 1*1e18);
        assertEq(reserve1, 1*1e18);
        (liquidityEMA,lastLiquidityEMABlockNum) = dsPair.getLiquidityEMA();
        assertEq(lastLiquidityEMABlockNum, 1);
        assertEq(liquidityEMA, 1*1e18);

        depositLiquidityInCFMM(addr1, 1*1e18, 1*1e18);
        (reserve0, reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 2*1e18);
        assertEq(reserve1, 2*1e18);
        (liquidityEMA,lastLiquidityEMABlockNum) = dsPair.getLiquidityEMA();
        assertEq(lastLiquidityEMABlockNum, 1);
        assertEq(liquidityEMA, 1*1e18);

        vm.roll(2);

        depositLiquidityInCFMM(addr1, 1*1e18, 1*1e18);
        (reserve0, reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 3*1e18);
        assertEq(reserve1, 3*1e18);
        (liquidityEMA,lastLiquidityEMABlockNum) = dsPair.getLiquidityEMA();
        assertEq(lastLiquidityEMABlockNum, 2);
        assertEq(liquidityEMA, 12*1e17);

        vm.roll(106);

        depositLiquidityInCFMM(addr1, 3*1e18, 3*1e18);
        (reserve0, reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 6*1e18);
        assertEq(reserve1, 6*1e18);
        (liquidityEMA,lastLiquidityEMABlockNum) = dsPair.getLiquidityEMA();
        assertEq(lastLiquidityEMABlockNum, 106);
        assertEq(liquidityEMA, 6*1e18);
    }

    function testLiquidityEMA() public {
        uint128 reserve0;
        uint128 reserve1;
        uint256 liquidityEMA;
        uint256 lastLiquidityEMABlockNum;

        (reserve0, reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 0);
        assertEq(reserve1, 0);
        (liquidityEMA,lastLiquidityEMABlockNum) = dsPair.getLiquidityEMA();
        assertEq(lastLiquidityEMABlockNum, 0);
        assertEq(liquidityEMA, 0);

        depositLiquidityInCFMM(addr1, 1*1e18, 1*1e18);
        (reserve0, reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 1*1e18);
        assertEq(reserve1, 1*1e18);
        (liquidityEMA,lastLiquidityEMABlockNum) = dsPair.getLiquidityEMA();
        assertEq(lastLiquidityEMABlockNum, 1);
        assertEq(liquidityEMA, 1*1e18);

        depositLiquidityInCFMM(addr1, 1*1e18, 1*1e18);
        (reserve0, reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 2*1e18);
        assertEq(reserve1, 2*1e18);
        (liquidityEMA,lastLiquidityEMABlockNum) = dsPair.getLiquidityEMA();
        assertEq(lastLiquidityEMABlockNum, 1);
        assertEq(liquidityEMA, 1*1e18);

        vm.roll(2);

        depositLiquidityInCFMM(addr1, 1*1e18, 1*1e18);
        (reserve0, reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 3*1e18);
        assertEq(reserve1, 3*1e18);
        (liquidityEMA,lastLiquidityEMABlockNum) = dsPair.getLiquidityEMA();
        assertEq(lastLiquidityEMABlockNum, 2);
        assertEq(liquidityEMA, 12*1e17);

        vm.roll(6);

        depositLiquidityInCFMM(addr1, 3*1e18, 3*1e18);
        (reserve0, reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 6*1e18);
        assertEq(reserve1, 6*1e18);
        (liquidityEMA,lastLiquidityEMABlockNum) = dsPair.getLiquidityEMA();
        assertEq(lastLiquidityEMABlockNum, 6);
        assertEq(liquidityEMA, 168*1e16);

        withdrawLiquidityFromCFMM(addr1, 4*1e18);
        (reserve0, reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 2*1e18);
        assertEq(reserve1, 2*1e18);
        (liquidityEMA,lastLiquidityEMABlockNum) = dsPair.getLiquidityEMA();
        assertEq(lastLiquidityEMABlockNum, 6);
        assertEq(liquidityEMA, 168*1e16);

        depositLiquidityInCFMM(addr1, 2*1e18, 2*1e18);
        (reserve0, reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 4*1e18);
        assertEq(reserve1, 4*1e18);
        (liquidityEMA,lastLiquidityEMABlockNum) = dsPair.getLiquidityEMA();
        assertEq(lastLiquidityEMABlockNum, 6);
        assertEq(liquidityEMA, 168*1e16);

        vm.roll(7);
        (reserve0, reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 4*1e18);
        assertEq(reserve1, 4*1e18);
        (liquidityEMA,lastLiquidityEMABlockNum) = dsPair.getLiquidityEMA();
        assertEq(lastLiquidityEMABlockNum, 6);
        assertEq(liquidityEMA, 168*1e16); // not updated yet

        dsPair.sync();
        (reserve0, reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 4*1e18);
        assertEq(reserve1, 4*1e18);
        (liquidityEMA,lastLiquidityEMABlockNum) = dsPair.getLiquidityEMA();
        assertEq(lastLiquidityEMABlockNum, 7);
        assertEq(liquidityEMA, 1912*1e15);

        vm.roll(10);
        depositLiquidityInCFMM(addr1, 4*1e18, 4*1e18);
        (reserve0, reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 8*1e18);
        assertEq(reserve1, 8*1e18);
        (liquidityEMA,lastLiquidityEMABlockNum) = dsPair.getLiquidityEMA();
        assertEq(lastLiquidityEMABlockNum, 10);
        assertEq(liquidityEMA, 25208*1e14);

        vm.roll(11);

        withdrawLiquidityFromCFMM(addr1, 6*1e18);
        (reserve0, reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 2*1e18);
        assertEq(reserve1, 2*1e18);
        (liquidityEMA,lastLiquidityEMABlockNum) = dsPair.getLiquidityEMA();
        assertEq(lastLiquidityEMABlockNum, 11);
        assertEq(liquidityEMA, 246872*1e13);
    }
}
