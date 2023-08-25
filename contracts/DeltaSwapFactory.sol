// SPDX-License-Identifier: GPL-v3
pragma solidity =0.8.17;

import './libraries/DeltaSwapLibrary.sol';
import './interfaces/IDeltaSwapFactory.sol';
import './DeltaSwapPair.sol';

contract DeltaSwapFactory is IDeltaSwapFactory {
    address public override feeTo;
    address public override feeToSetter;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external override view returns (uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, 'DeltaSwap: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'DeltaSwap: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'DeltaSwap: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(DeltaSwapPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IDeltaSwapPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, 'DeltaSwap: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, 'DeltaSwap: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }

    function setGammaPool(address tokenA, address tokenB, address gsFactory, address implementation, uint16 protocolId) external override {
        require(msg.sender == feeToSetter, 'DeltaSwap: FORBIDDEN');
        address pair = getPair[tokenA][tokenB];
        address gammaPool = DeltaSwapLibrary.predictDeterministicAddress(implementation, keccak256(abi.encode(pair, protocolId)), gsFactory);
        IDeltaSwapPair(pair).setGammaPool(gammaPool);
        emit GammaPoolSet(tokenA, tokenB, pair, gammaPool);
    }
}