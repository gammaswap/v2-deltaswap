// SPDX-License-Identifier: GPL-v3
pragma solidity >=0.5.0;

interface IDeltaSwapFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);
    event GammaPoolSet(address indexed token0, address indexed token1, address pair, address gammaPool);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function gammaPoolSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint256) external view returns (address pair);
    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;

    function setGSFee(address tokenA, address tokenB, uint8 fee) external;
    function setDSFee(address tokenA, address tokenB, uint8 fee) external;
    function setDSFeeThreshold(address tokenA, address tokenB, uint8 feeThreshold) external;

    function setGammaPoolSetter(address) external;
    function setGammaPool(address tokenA, address tokenB, address gsFactory, address implementation, uint16 protocolId) external;
}