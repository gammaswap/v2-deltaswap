// SPDX-License-Identifier: GPL-v3
pragma solidity >=0.5.0;

interface IDeltaSwapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);
    event GammaPoolSet(address indexed pair, address gammaPool);

    function feeTo() external view returns (address);
    function feeNum() external view returns (uint16);
    function feeToSetter() external view returns (address);
    function gammaPoolSetter() external view returns (address);
    function gsFactory() external view returns(address);
    function gsProtocolId() external view returns(uint16);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint256) external view returns (address pair);
    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeNum(uint16) external;
    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
    function feeInfo() external view returns (address,uint16);

    function setGSFactory(address factory) external;
    function setGSProtocolId(uint16 protocolId) external;
    function setFeeParameters(address pair, uint24 gsFee, uint24 dsFee, uint24 dsFeeThreshold, uint24 yieldPeriod) external;
    function setGammaPoolSetter(address) external;
    function updateGammaPool(address tokenA, address tokenB) external;
}