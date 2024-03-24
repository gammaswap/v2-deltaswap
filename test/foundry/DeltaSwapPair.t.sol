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

    function buy_wbtc(address addr, uint256 amount) public {
        vm.startPrank(addr);
        buyTokenOut(amount, address(usdc), address(wbtc), msg.sender); // quote: 1 wbtc = 1 USDC
        vm.stopPrank();
    }

    function testCalcTradingFee(uint112 tradeLiquidity, uint112 lastLiquidityTradedEMA, uint112 lastLiquidityEMA) public {
        uint256 fee = dsPair.calcTradingFee(tradeLiquidity, lastLiquidityTradedEMA, lastLiquidityEMA);
        if(DSMath.max(tradeLiquidity, lastLiquidityTradedEMA) >= uint256(lastLiquidityEMA) * dsFactory.dsFeeThreshold() / 100000) {// if trade >= 2% of liquidity, charge 0.3% fee => 1% of liquidity value, ~4.04% px change and 2.3% slippage
            assertEq(fee,dsFactory.dsFee());
        } else {
            assertEq(fee,0);
        }
    }

    function testMultiDayStream() public {
        dsFactory.setDSFeeThreshold(0);
        depositLiquidityInCFMM(addr1, 100*1e18, 100*1e18);
        (uint256 lpReserve0, uint256 lpReserve1,) = dsPair.getLPReserves();
        (uint256 reserve0, uint256 reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 100*1e18);
        assertEq(reserve1, 100*1e18);

        uint256 liquidity = DSMath.sqrt(reserve0 * reserve1);

        sell_wbtc(addr1, 1e18);
        buy_wbtc(addr1, 1e18 - 2970385258968089); // gets price back to 1 at higher liquidity

        (uint256 _lpReserve0, uint256 _lpReserve1,) = dsPair.getLPReserves();
        (uint256 _reserve0, uint256 _reserve1,) = dsPair.getReserves();
        uint256 _liquidity = DSMath.sqrt(_reserve0 * _reserve1);
        assertEq(reserve1*_reserve0,reserve0*_reserve1); // price stays the same

        assertGt(_reserve0, reserve0);
        assertGt(_reserve1, reserve1);
        assertGt(_liquidity, liquidity);
        assertEq(_lpReserve0/10, lpReserve0/10); // rounding error at the last decimal
        assertEq(_lpReserve1/10, lpReserve1/10); // rounding error at the last decimal

        vm.warp(12*60*60 + 1);

        /*(_lpReserve0, _lpReserve1,) = dsPair.getLPReserves();
        (reserve0, reserve1,) = dsPair.getReserves();
        assertEq(_reserve0, reserve0);
        assertEq(_reserve1, reserve1);

        assertEq(_lpReserve0/10 - lpReserve0/10, 297038525896808/2);
        assertEq(_lpReserve1/10 - lpReserve1/10, 297038525896808/2);

        console.log("px1a:",(_reserve1 * 1e18 / _reserve0));
        console.log("px1b:",(_lpReserve1 * 1e18 / _lpReserve0));/**/

        //IMPORTANT
        sell_wbtc(addr1, 1e18);
        buy_wbtc(addr1, 1e18 - 2970386129930623); // gets price back to 1 at higher liquidity

        (_lpReserve0, _lpReserve1,) = dsPair.getLPReserves();
        (_reserve0, _reserve1,) = dsPair.getReserves();
        _liquidity = DSMath.sqrt(_reserve0 * _reserve1);

        console.log("px2a:",(_reserve1 * 1e18 / _reserve0));
        console.log("px2b:",(_lpReserve1 * 1e18 / _lpReserve0));
        assertEq(reserve1*1e18/reserve0,_reserve1*1e18/_reserve0); // price stays the same

        vm.warp(24*60*60 + 1);

        //IMPORTANT
        (_lpReserve0, _lpReserve1,) = dsPair.getLPReserves();
        //assertGt(_reserve0, reserve0);
        //assertGt(_reserve1, reserve1);

        console.log(_lpReserve0 - lpReserve0 - 2970385258968089);

        //assertEq(_lpReserve0, lpReserve0);
        //assertEq(_lpReserve1, lpReserve1);
        //assertGt(_lpReserve0/10 - lpReserve0/10, 297038525896808 + 297038525896808/2);
        //assertGt(_lpReserve1/10 - lpReserve1/10, 297038525896808 + 297038525896808/2);
    }

    function testMintFeesEarned() public {
        dsFactory.setDSFeeThreshold(0);
        depositLiquidityInCFMM(addr1, 100*1e18, 100*1e18);
        (uint256 lpReserve0, uint256 lpReserve1,) = dsPair.getLPReserves();
        (uint256 reserve0, uint256 reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 100*1e18);
        assertEq(reserve1, 100*1e18);

        uint256 liquidity = DSMath.sqrt(reserve0 * reserve1);

        sell_wbtc(addr1, 1e18);
        buy_wbtc(addr1, 1e18 - 2970385258968089); // gets price back to 1 at higher liquidity

        (uint256 _lpReserve0, uint256 _lpReserve1,) = dsPair.getLPReserves();
        (uint256 _reserve0, uint256 _reserve1,) = dsPair.getReserves();
        uint256 _liquidity = DSMath.sqrt(_reserve0 * _reserve1);
        assertEq(reserve1*_reserve0,reserve0*_reserve1); // price stays the same

        assertGt(_reserve0, reserve0);
        assertGt(_reserve1, reserve1);
        assertGt(_liquidity, liquidity);
        assertEq(_lpReserve0/10, lpReserve0/10); // rounding error at the last decimal
        assertEq(_lpReserve1/10, lpReserve1/10); // rounding error at the last decimal

        vm.warp(12*60*60 + 1);

        (_lpReserve0, _lpReserve1,) = dsPair.getLPReserves();
        (reserve0, reserve1,) = dsPair.getReserves();
        assertEq(_reserve0, reserve0);
        assertEq(_reserve1, reserve1);

        assertEq(_lpReserve0/10 - lpReserve0/10, 297038525896808/2);
        assertEq(_lpReserve1/10 - lpReserve1/10, 297038525896808/2);

        vm.warp(24*60*60 + 1);

        (_lpReserve0, _lpReserve1,) = dsPair.getLPReserves();
        (reserve0, reserve1,) = dsPair.getReserves();
        assertEq(_reserve0, reserve0);
        assertEq(_reserve1, reserve1);

        assertEq(_lpReserve0/10 - lpReserve0/10, 297038525896808);
        assertEq(_lpReserve1/10 - lpReserve1/10, 297038525896808);

        dsPair.sync();

        (_lpReserve0, _lpReserve1,) = dsPair.getLPReserves();
        assertEq(_lpReserve0, reserve0);
        assertEq(_lpReserve1, reserve1);

        depositLiquidityInCFMM(addr2, 100*1e18, 100*1e18);
        assertGt(dsPair.balanceOf(addr1) - dsPair.balanceOf(addr2), 297038525896808);

        uint256 amount = 1_000_000 * 1e18;
        address addr3 = vm.addr(6666);
        usdc.mint(addr3, amount);
        wbtc.mint(addr3, amount);
        address[] memory _tokens = new address[](2);
        _tokens[0] = address(usdc);
        _tokens[1] = address(wbtc);
        approveRouterForAddress(addr3, _tokens);

        vm.warp(48*60*60 + 1);
        depositLiquidityInCFMM(addr3, 100*1e18, 100*1e18);
        assertEq(dsPair.balanceOf(addr2), dsPair.balanceOf(addr3));
    }

    function testMintFeesUnearned() public {
        dsFactory.setDSFeeThreshold(0);
        depositLiquidityInCFMM(addr1, 100*1e18, 100*1e18);
        (uint256 lpReserve0, uint256 lpReserve1,) = dsPair.getLPReserves();
        (uint256 reserve0, uint256 reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 100*1e18);
        assertEq(reserve1, 100*1e18);

        uint256 liquidity = DSMath.sqrt(reserve0 * reserve1);

        sell_wbtc(addr1, 1e18);
        buy_wbtc(addr1, 1e18 - 2970385258968089); // gets price back to 1 at higher liquidity

        (uint256 _lpReserve0, uint256 _lpReserve1,) = dsPair.getLPReserves();
        (uint256 _reserve0, uint256 _reserve1,) = dsPair.getReserves();
        uint256 _liquidity = DSMath.sqrt(_reserve0 * _reserve1);
        assertEq(reserve1*_reserve0,reserve0*_reserve1); // price stays the same

        assertGt(_reserve0, reserve0);
        assertGt(_reserve1, reserve1);
        assertGt(_liquidity, liquidity);
        assertEq(_lpReserve0/10, lpReserve0/10); // rounding error at the last decimal
        assertEq(_lpReserve1/10, lpReserve1/10); // rounding error at the last decimal

        depositLiquidityInCFMM(addr2, 100*1e18, 100*1e18);
        assertEq(dsPair.balanceOf(addr1) + 1000 - dsPair.balanceOf(addr2), 2); // +1000 because of first liquidity, 2 because of rounding of second mint (less than should have)
    }

    function testTradingFeesHalfPctMinus1() public {
        depositLiquidityInCFMM(addr1, 100*1e18, 100*1e18);
        (uint256 reserve0, uint256 reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 100*1e18);
        assertEq(reserve1, 100*1e18);

        uint256 liquidity = DSMath.sqrt(reserve0 * reserve1);

        sell_wbtc(addr1, 1e18 - 1);

        (reserve0, reserve1,) = dsPair.getReserves();
        assertNotEq(reserve0, 100*1e18);
        assertNotEq(reserve1, 100*1e18);

        assertEq(liquidity, DSMath.sqrt(reserve0 * reserve1));
    }

    function testTradingFees1pct() public {
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
        assertEq(0, liqDiff);
    }

    function testTradingFees2pct() public {
        depositLiquidityInCFMM(addr1, 100*1e18, 100*1e18);
        (uint256 reserve0, uint256 reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 100*1e18);
        assertEq(reserve1, 100*1e18);

        uint256 liquidity = DSMath.sqrt(reserve0 * reserve1);

        sell_wbtc(addr1, 4*1e18);

        (reserve0, reserve1,) = dsPair.getReserves();
        assertNotEq(reserve0, 100*1e18);
        assertNotEq(reserve1, 100*1e18);

        assertLt(liquidity, DSMath.sqrt(reserve0 * reserve1));
    }

    function testTradingFees2pctMinus1() public {
        depositLiquidityInCFMM(addr1, 100*1e18, 100*1e18);
        (uint256 reserve0, uint256 reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 100*1e18);
        assertEq(reserve1, 100*1e18);

        uint256 liquidity = DSMath.sqrt(reserve0 * reserve1);

        sell_wbtc(addr1, 4*1e18 - 1);

        (reserve0, reserve1,) = dsPair.getReserves();
        assertNotEq(reserve0, 100*1e18);
        assertNotEq(reserve1, 100*1e18);

        assertEq(liquidity, DSMath.sqrt(reserve0 * reserve1));
    }

    function testTradingFeesThreshold() public {
        vm.startPrank(address(dsFactory.feeToSetter()));
        dsFactory.setDSFeeThreshold(2100);
        vm.stopPrank();

        assertEq(dsFactory.dsFeeThreshold(), 2100);

        depositLiquidityInCFMM(addr1, 100*1e18, 100*1e18);
        (uint256 reserve0, uint256 reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 100*1e18);
        assertEq(reserve1, 100*1e18);

        uint256 liquidity = DSMath.sqrt(reserve0 * reserve1);

        sell_wbtc(addr1, 4*1e18);

        (reserve0, reserve1,) = dsPair.getReserves();
        assertNotEq(reserve0, 100*1e18);
        assertNotEq(reserve1, 100*1e18);

        assertEq(liquidity, DSMath.sqrt(reserve0 * reserve1));
    }

    function testProtRevenueShare100Pct() public {
        vm.startPrank(address(dsFactory.feeToSetter()));
        dsFactory.setFeeTo(dsFactory.feeToSetter());
        dsFactory.setFeeNum(0); // feeNum = 0 => fee share is 100%
        vm.stopPrank();

        depositLiquidityInCFMM(addr1, 100*1e18, 100*1e18);

        (uint256 reserve0, uint256 reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 100*1e18);
        assertEq(reserve1, 100*1e18);

        uint256 liquidity = DSMath.sqrt(reserve0 * reserve1);
        uint256 totSupply = dsPair.totalSupply();

        assertEq(dsFactory.feeTo(), dsFactory.feeToSetter());
        assertEq(dsFactory.feeNum(), 0);
        sell_wbtc(addr1, 4*1e18);

        vm.warp(24*60*60 + 1);
        vm.startPrank(addr1);
        dsPair.transfer(address(dsPair), 1000);
        dsPair.burn(addr1);
        vm.stopPrank();

        (reserve0, reserve1,) = dsPair.getReserves();
        assertNotEq(reserve0, 100*1e18);
        assertNotEq(reserve1, 100*1e18);

        (reserve0, reserve1,) = dsPair.getLPReserves();
        uint256 liquidity1 = DSMath.sqrt(reserve0 * reserve1);
        uint256 totSupply1 = dsPair.totalSupply();
        assertEq(liquidity1 * totSupply / totSupply1, liquidity);
        assertGt(liquidity1, liquidity);
        assertGt(totSupply1, totSupply);
    }

    function testProtRevenueShare25Pct() public {
        vm.startPrank(address(dsFactory.feeToSetter()));
        dsFactory.setFeeTo(dsFactory.feeToSetter());
        dsFactory.setFeeNum(3000); // feeNum = 3000 => fee share is 25%
        vm.stopPrank();

        depositLiquidityInCFMM(addr1, 100*1e18, 100*1e18);

        (uint256 reserve0, uint256 reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 100*1e18);
        assertEq(reserve1, 100*1e18);

        uint256 liquidity = DSMath.sqrt(reserve0 * reserve1);
        uint256 totSupply = dsPair.totalSupply();

        assertEq(dsFactory.feeTo(), dsFactory.feeToSetter());
        assertEq(dsFactory.feeNum(), 3000);
        sell_wbtc(addr1, 4*1e18);

        vm.warp(24*60*60 + 1);
        vm.startPrank(addr1);
        dsPair.transfer(address(dsPair), 1000);
        dsPair.burn(addr1);
        vm.stopPrank();

        (reserve0, reserve1,) = dsPair.getReserves();
        assertNotEq(reserve0, 100*1e18);
        assertNotEq(reserve1, 100*1e18);

        (reserve0, reserve1,) = dsPair.getLPReserves();
        uint256 liquidity1 = DSMath.sqrt(reserve0 * reserve1);
        uint256 totSupply1 = dsPair.totalSupply();
        assertGt(liquidity1 * totSupply / totSupply1, liquidity);
        assertGt(liquidity1, liquidity);
        assertGt(totSupply1, totSupply);

        uint256 num = 5769730077595450;
        assertEq(num, liquidity1 - liquidity);
        num = num / 4;
        assertApproxEqRel(num,totSupply1 - totSupply,5*1e13);
    }

    function testProtRevenueShare33Pct() public {
        vm.startPrank(address(dsFactory.feeToSetter()));
        dsFactory.setFeeTo(dsFactory.feeToSetter());
        dsFactory.setFeeNum(2000); // feeNum = 2000 => fee share is 33.33%
        vm.stopPrank();

        depositLiquidityInCFMM(addr1, 100*1e18, 100*1e18);

        (uint256 reserve0, uint256 reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 100*1e18);
        assertEq(reserve1, 100*1e18);

        uint256 liquidity = DSMath.sqrt(reserve0 * reserve1);
        uint256 totSupply = dsPair.totalSupply();

        assertEq(dsFactory.feeTo(), dsFactory.feeToSetter());
        assertEq(dsFactory.feeNum(), 2000);
        sell_wbtc(addr1, 4*1e18);

        vm.warp(24*60*60 + 1);
        vm.startPrank(addr1);
        dsPair.transfer(address(dsPair), 1000);
        dsPair.burn(addr1);
        vm.stopPrank();

        (reserve0, reserve1,) = dsPair.getReserves();
        assertNotEq(reserve0, 100*1e18);
        assertNotEq(reserve1, 100*1e18);

        (reserve0, reserve1,) = dsPair.getLPReserves();
        uint256 liquidity1 = DSMath.sqrt(reserve0 * reserve1);
        uint256 totSupply1 = dsPair.totalSupply();
        assertGt(liquidity1 * totSupply / totSupply1, liquidity);
        assertGt(liquidity1, liquidity);
        assertGt(totSupply1, totSupply);

        uint256 num = 5769730077595450;
        assertEq(num, liquidity1 - liquidity);
        num = num / 3;
        assertApproxEqRel(num,totSupply1 - totSupply,4*1e13);
    }

    function testProtRevenueShare50Pct() public {
        vm.startPrank(address(dsFactory.feeToSetter()));
        dsFactory.setFeeTo(dsFactory.feeToSetter());
        dsFactory.setFeeNum(1000); // feeNum = 1000 => fee share is 50%
        vm.stopPrank();

        depositLiquidityInCFMM(addr1, 100*1e18, 100*1e18);

        (uint256 reserve0, uint256 reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 100*1e18);
        assertEq(reserve1, 100*1e18);

        uint256 liquidity = DSMath.sqrt(reserve0 * reserve1);
        uint256 totSupply = dsPair.totalSupply();

        assertEq(dsFactory.feeTo(), dsFactory.feeToSetter());
        assertEq(dsFactory.feeNum(), 1000);
        sell_wbtc(addr1, 4*1e18);

        vm.warp(24*60*60 + 1);
        vm.startPrank(addr1);
        dsPair.transfer(address(dsPair), 1000);
        dsPair.burn(addr1);
        vm.stopPrank();

        (reserve0, reserve1,) = dsPair.getReserves();
        assertNotEq(reserve0, 100*1e18);
        assertNotEq(reserve1, 100*1e18);

        (reserve0, reserve1,) = dsPair.getLPReserves();
        uint256 liquidity1 = DSMath.sqrt(reserve0 * reserve1);
        uint256 totSupply1 = dsPair.totalSupply();
        assertGt(liquidity1 * totSupply / totSupply1, liquidity);
        assertGt(liquidity1, liquidity);
        assertGt(totSupply1, totSupply);

        uint256 num = 5769730077595450;
        assertEq(num, liquidity1 - liquidity);
        num = num / 2;
        assertApproxEqRel(num,totSupply1 - totSupply,3*1e13);
    }

    // Maybe the difference is a rounding error?
    function testProtRevenueShare60Pct() public {
        vm.startPrank(address(dsFactory.feeToSetter()));
        dsFactory.setFeeTo(dsFactory.feeToSetter());
        dsFactory.setFeeNum(666); // feeNum = 666 => fee share is 60%
        vm.stopPrank();

        depositLiquidityInCFMM(addr1, 100*1e18, 100*1e18);

        (uint256 reserve0, uint256 reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 100*1e18);
        assertEq(reserve1, 100*1e18);

        uint256 liquidity = DSMath.sqrt(reserve0 * reserve1);
        uint256 totSupply = dsPair.totalSupply();

        assertEq(dsFactory.feeTo(), dsFactory.feeToSetter());
        assertEq(dsFactory.feeNum(), 666);
        sell_wbtc(addr1, 4*1e18);

        vm.warp(24*60*60 + 1);
        vm.startPrank(addr1);
        dsPair.transfer(address(dsPair), 1000);
        dsPair.burn(addr1);
        vm.stopPrank();

        (reserve0, reserve1,) = dsPair.getReserves();
        assertNotEq(reserve0, 100*1e18);
        assertNotEq(reserve1, 100*1e18);

        (reserve0, reserve1,) = dsPair.getLPReserves();
        uint256 liquidity1 = DSMath.sqrt(reserve0 * reserve1);
        uint256 totSupply1 = dsPair.totalSupply();
        assertGt(liquidity1 * totSupply / totSupply1, liquidity);
        assertGt(liquidity1, liquidity);
        assertGt(totSupply1, totSupply);

        uint256 num = 5769730077595450;
        assertEq(num, liquidity1 - liquidity);
        num = num * 6 / 10;
        assertApproxEqRel(num,totSupply1 - totSupply,38*1e13);
    }

    function testProtRevenueShare75Pct() public {
        vm.startPrank(address(dsFactory.feeToSetter()));
        dsFactory.setFeeTo(dsFactory.feeToSetter());
        dsFactory.setFeeNum(333); // feeNum = 333 => fee share is 75%
        vm.stopPrank();

        depositLiquidityInCFMM(addr1, 100*1e18, 100*1e18);

        (uint256 reserve0, uint256 reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 100*1e18);
        assertEq(reserve1, 100*1e18);

        uint256 liquidity = DSMath.sqrt(reserve0 * reserve1);
        uint256 totSupply = dsPair.totalSupply();

        assertEq(dsFactory.feeTo(), dsFactory.feeToSetter());
        assertEq(dsFactory.feeNum(), 333);
        sell_wbtc(addr1, 4*1e18);

        vm.warp(24*60*60 + 1);
        vm.startPrank(addr1);
        dsPair.transfer(address(dsPair), 1000);
        dsPair.burn(addr1);
        vm.stopPrank();

        (reserve0, reserve1,) = dsPair.getReserves();
        assertNotEq(reserve0, 100*1e18);
        assertNotEq(reserve1, 100*1e18);

        (reserve0, reserve1,) = dsPair.getLPReserves();
        uint256 liquidity1 = DSMath.sqrt(reserve0 * reserve1);
        uint256 totSupply1 = dsPair.totalSupply();
        assertGt(liquidity1 * totSupply / totSupply1, liquidity);
        assertGt(liquidity1, liquidity);
        assertGt(totSupply1, totSupply);

        uint256 num = 5769730077595450;
        assertEq(num, liquidity1 - liquidity);
        num = num * 3 / 4;
        assertApproxEqRel(num,totSupply1 - totSupply,25*1e13);
    }

    // Maybe the difference is a rounding error?
    function testProtRevenueShare80Pct() public {
        vm.startPrank(address(dsFactory.feeToSetter()));
        dsFactory.setFeeTo(dsFactory.feeToSetter());
        dsFactory.setFeeNum(250); // feeNum = 250 => fee share is 80%
        vm.stopPrank();

        depositLiquidityInCFMM(addr1, 100*1e18, 100*1e18);

        (uint256 reserve0, uint256 reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 100*1e18);
        assertEq(reserve1, 100*1e18);

        uint256 liquidity = DSMath.sqrt(reserve0 * reserve1);
        uint256 totSupply = dsPair.totalSupply();

        assertEq(dsFactory.feeTo(), dsFactory.feeToSetter());
        assertEq(dsFactory.feeNum(), 250);
        sell_wbtc(addr1, 4*1e18);

        vm.warp(24*60*60 + 1);
        vm.startPrank(addr1);
        dsPair.transfer(address(dsPair), 1000);
        dsPair.burn(addr1);
        vm.stopPrank();

        (reserve0, reserve1,) = dsPair.getReserves();
        assertNotEq(reserve0, 100*1e18);
        assertNotEq(reserve1, 100*1e18);

        (reserve0, reserve1,) = dsPair.getLPReserves();
        uint256 liquidity1 = DSMath.sqrt(reserve0 * reserve1);
        uint256 totSupply1 = dsPair.totalSupply();
        assertGt(liquidity1 * totSupply / totSupply1, liquidity);
        assertGt(liquidity1, liquidity);
        assertGt(totSupply1, totSupply);

        uint256 num = 5769730077595450;
        assertEq(num, liquidity1 - liquidity);
        num = num * 4 / 5;
        assertApproxEqRel(num,totSupply1 - totSupply,3*1e13);
    }

    function testTradingDSFees() public {
        vm.startPrank(address(dsFactory.feeToSetter()));
        dsFactory.setDSFee(10000); // fee is 10%
        vm.stopPrank();

        assertEq(dsFactory.dsFee(), 10000);

        depositLiquidityInCFMM(addr1, 100*1e18, 100*1e18);
        (uint256 reserve0, uint256 reserve1,) = dsPair.getReserves();
        assertEq(reserve0, 100*1e18);
        assertEq(reserve1, 100*1e18);

        uint256 liquidity = DSMath.sqrt(reserve0 * reserve1);

        uint256 tradeQty = 4*1e18;
        sell_wbtc(addr1, tradeQty);

        (reserve0, reserve1,) = dsPair.getReserves();
        assertNotEq(reserve0, 100*1e18);
        assertNotEq(reserve1, 100*1e18);

        assertLt(liquidity, DSMath.sqrt(reserve0 * reserve1));

        uint256 feeChargeLo = (tradeQty/2) * 9 / 100; // 9 because fee growth is less than 10% actually
        uint256 feeChargeHi = (tradeQty/2) * 10 / 100; // 10 because fee growth is less than 10% actually
        uint256 liqDiff = DSMath.sqrt(reserve0 * reserve1) - liquidity;
        assertGe(liqDiff, feeChargeLo);
        assertLt(liqDiff, feeChargeHi);
    }

    function testDSFeesThresholdForbidden() public {
        uint16 dsFeeThreshold = dsFactory.dsFeeThreshold();
        assertNotEq(dsFeeThreshold, 21);

        vm.startPrank(addr1);
        vm.expectRevert("DeltaSwap: FORBIDDEN");
        dsFactory.setDSFeeThreshold(21);
        vm.stopPrank();

        assertEq(dsFactory.dsFeeThreshold(), dsFeeThreshold);
    }

    function testDSFees() public {
        assertEq(dsFactory.dsFee(), 300);

        vm.startPrank(address(dsFactory.feeToSetter()));
        dsFactory.setDSFee(50);
        vm.stopPrank();

        assertEq(dsFactory.dsFee(), 50);
    }

    function testDSFeesForbidden() public {
        uint16 dsFee = dsFactory.dsFee();
        assertNotEq(dsFee, 50);

        vm.startPrank(addr1);
        vm.expectRevert("DeltaSwap: FORBIDDEN");
        dsFactory.setDSFee(50);
        vm.stopPrank();

        assertEq(dsFactory.dsFee(), dsFee);
    }

    function testSetGammaPoolSetter() public {
        assertEq(dsFactory.gammaPoolSetter(), owner);

        dsFactory.setGammaPoolSetter(addr1);

        assertEq(dsFactory.gammaPoolSetter(), addr1);

        vm.startPrank(addr1);
        dsFactory.setGammaPoolSetter(addr2);
        assertEq(dsFactory.gammaPoolSetter(), addr2);
        vm.stopPrank();
    }

    function testSetGammaPoolSetterRevert() public {
        assertEq(dsFactory.gammaPoolSetter(), owner);

        vm.startPrank(addr1);

        vm.expectRevert("DeltaSwap: FORBIDDEN");
        dsFactory.setGammaPoolSetter(addr1);

        assertEq(dsFactory.gammaPoolSetter(), owner);
        vm.stopPrank();
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

    function testSetGammaPoolError() public {
        address gsFactory = vm.addr(100);
        uint16 protocolId = 1;
        address implementation = vm.addr(200);
        bytes32 gsPoolKey = keccak256(abi.encode(address(dsPair), protocolId));
        address poolAddr = DeltaSwapLibrary.predictDeterministicAddress(implementation, gsPoolKey, gsFactory);
        vm.expectRevert("DeltaSwap: FORBIDDEN");
        dsPair.setGammaPool(poolAddr);
    }

    function testSetGSFee() public {
        assertEq(dsFactory.gsFee(), 300);

        vm.startPrank(address(dsFactory.feeToSetter()));
        dsFactory.setGSFee(5);
        vm.stopPrank();

        assertEq(dsFactory.gsFee(), 5);
    }

    function testSetGSFeeError() public {
        uint256 gsFee = dsFactory.gsFee();
        assertNotEq(gsFee, 5);

        vm.startPrank(addr1);
        vm.expectRevert("DeltaSwap: FORBIDDEN");
        dsFactory.setGSFee(5);
        vm.stopPrank();

        assertEq(dsFactory.gsFee(), gsFee);
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

        amountOut = dsRouter.getAmountOut(amountIn, reserve0, reserve1, 100);
        vm.expectRevert("DeltaSwap: K");
        dsPair.swap(0, amountOut, poolAddr, new bytes(0));

        amountOut = dsRouter.getAmountOut(amountIn, reserve0, reserve1, 200);
        vm.expectRevert("DeltaSwap: K");
        dsPair.swap(0, amountOut, poolAddr, new bytes(0));

        amountOut = dsRouter.getAmountOut(amountIn, reserve0, reserve1, 300);
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
        assertEq(tradeLiquidityEMA, 1*1e18/2);
        assertEq(lastTradeLiquidityEMA, 1*1e18/2);
        assertEq(tradeLiquiditySum, 1e18/2);

        (tradeLiquidityEMA, lastTradeLiquidityEMA, tradeLiquiditySum) = dsPair.getTradeLiquidityEMA(1*1e18);
        assertEq(tradeLiquidityEMA, 7*1e17);
        assertEq(lastTradeLiquidityEMA, 1*1e18/2);
        assertEq(tradeLiquiditySum, 3*1e18/2);

        uint256 tradeLiq = calculateTradeLiquidity(1*1e18);

        (tradeLiquidityEMA, lastTradeLiquidityEMA, tradeLiquiditySum) = dsPair.getTradeLiquidityEMA(tradeLiq);

        uint256 expectedTradeLiquidityEMA = tradeLiquidityEMA;
        sell_wbtc(addr1, 1*1e18);

        (tradeLiquidityEMA, lastTradeLiquidityEMA, tradeLiquiditySum) = dsPair.getTradeLiquidityEMA(0);
        assertEq(lastTradeLiquidityEMA,expectedTradeLiquidityEMA);
        assertEq(tradeLiquidityEMA,expectedTradeLiquidityEMA);
        assertEq(tradeLiquiditySum, 1*1e18/2 + tradeLiq);

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
        assertEq(tradeLiquiditySum, 3*1e18/2);
        assertEq(tradeBlockNum, 1);

        (tradeLiquiditySum, tradeBlockNum) = dsPair.getLastTradeLiquiditySum(4*1e18);
        assertEq(tradeLiquiditySum, 45*1e17);
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
