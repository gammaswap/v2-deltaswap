// SPDX-License-Identifier: GPL-v3
pragma solidity =0.8.21;

import '@gammaswap/v1-core/contracts/libraries/AddressCalculator.sol';
import './interfaces/IDSBeacon.sol';
import './interfaces/IDeltaSwapV2Factory.sol';
import './libraries/DeltaSwapV2Library.sol';
import './utils/DSProxy.sol';
import "./utils/DSOwnable2Step.sol";
import './DeltaSwapV2Pair.sol';

/// @title DeltaSwapV2Factory contract
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Factory contract to create DeltaSwapV2Pairs.
/// @dev All DeltaSwapV2Pair contracts are unique by token pair
contract DeltaSwapV2Factory is IDeltaSwapV2Factory, IDSBeacon, DSOwnable2Step {
    address private _implementation;

    /// @dev Emitted when the implementation returned by the beacon is changed.
    event Upgraded(address indexed implementation);

    address public override feeTo;
    uint16 public override feeNum = 5000; // GammaPool swap fee
    address public override feeToSetter;
    address public override gammaPoolSetter;
    address public override gsFactory;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    uint16 public override gsProtocolId = 3;

    constructor(address _feeToSetter, address _gammaPoolSetter, address _gsFactory) DSOwnable(msg.sender) {
        feeToSetter = _feeToSetter;
        gammaPoolSetter = _gammaPoolSetter;
        gsFactory = _gsFactory;
        _implementation = address(new DeltaSwapV2Pair(address(this)));
    }

    function allPairsLength() external override view returns (uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, 'DeltaSwapV2: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'DeltaSwapV2: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'DeltaSwapV2: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(DSProxy).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IDeltaSwapV2Pair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);

        _setGammaPool(pair);
    }

    /// @dev Returns the current implementation address.
    function implementation() public view virtual returns (address) {
        return _implementation;
    }

    /// @dev Upgrades the beacon to a new implementation.
    function upgradeTo(address newImplementation) public virtual onlyOwner {
        _setImplementation(newImplementation);
    }

    /// @dev Sets the implementation contract address for this beacon
    function _setImplementation(address newImplementation) private {
        require(newImplementation.code.length > 0, 'DeltaSwapV2: INVALID_IMPLEMENTATION');
        _implementation = newImplementation;
        emit Upgraded(newImplementation);
    }

    function setFeeNum(uint16 _feeNum) external override {
        require(msg.sender == feeToSetter, 'DeltaSwapV2: FORBIDDEN');
        feeNum = _feeNum;
    }

    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, 'DeltaSwapV2: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, 'DeltaSwapV2: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }

    function setFeeParameters(address pair, uint24 gsFee, uint24 dsFee, uint24 dsFeeThreshold, uint24 yieldPeriod) external override {
        require(msg.sender == feeToSetter, 'DeltaSwapV2: FORBIDDEN');
        IDeltaSwapV2Pair(pair).setFeeParameters(gsFee, dsFee, dsFeeThreshold, yieldPeriod);
    }

    function feeInfo() external override view returns (address,uint16) {
        return(feeTo, feeNum);
    }

    function setGSProtocolId(uint16 protocolId) external override {
        require(msg.sender == gammaPoolSetter, 'DeltaSwapV2: FORBIDDEN');
        gsProtocolId = protocolId;
    }

    function setGSFactory(address factory) external override {
        require(msg.sender == gammaPoolSetter, 'DeltaSwapV2: FORBIDDEN');
        gsFactory = factory;
    }

    function setGammaPoolSetter(address _gammaPoolSetter) external override {
        require(msg.sender == gammaPoolSetter, 'DeltaSwapV2: FORBIDDEN');
        gammaPoolSetter = _gammaPoolSetter;
    }

    function updateGammaPool(address tokenA, address tokenB) external override {
        require(msg.sender == gammaPoolSetter, 'DeltaSwapV2: FORBIDDEN');
        _setGammaPool(getPair[tokenA][tokenB]);
    }

    function _setGammaPool(address pair) internal {
        address gammaPool = AddressCalculator.calcAddress(gsFactory, gsProtocolId, keccak256(abi.encode(pair, gsProtocolId)));
        IDeltaSwapV2Pair(pair).setGammaPool(gammaPool);
        emit GammaPoolSet(pair, gammaPool);
    }
}