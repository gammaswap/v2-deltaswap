// SPDX-License-Identifier: GPL-v3
pragma solidity =0.8.21;

import './interfaces/IDeltaSwapERC20.sol';
import "./storage/AppStorage.sol";

contract DeltaSwapERC20 is AppStorage, IDeltaSwapERC20 {
    string public constant override name = 'DeltaSwap V2';
    string public constant override symbol = 'DS-V2';
    uint8 public constant override decimals = 18;

    bytes32 public constant override PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    constructor() {
    }

    function _initializeDomainSeparator() internal {
        require(s.DOMAIN_SEPARATOR == bytes32(0), 'DeltaSwap: DOMAIN_SEPARATOR_INITIALIZED');
        uint256 chainId;
        assembly {
            chainId := chainid()
        }

        s.DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                keccak256(bytes(name)),
                keccak256(bytes('1')),
                chainId,
                address(this)
            )
        );
    }

    function DOMAIN_SEPARATOR() external override view returns (bytes32) {
        return s.DOMAIN_SEPARATOR;
    }

    function totalSupply() external override view returns (uint256) {
        return s.totalSupply;
    }

    function balanceOf(address owner) external override view returns (uint256) {
        return s.balanceOf[owner];
    }

    function allowance(address owner, address spender) external override view returns (uint256) {
        return s.allowance[owner][spender];
    }

    function nonces(address owner) external override view returns (uint256) {
        return s.nonces[owner];
    }

    function _mint(address to, uint256 value) internal {
        s.totalSupply = s.totalSupply + value;
        s.balanceOf[to] = s.balanceOf[to] + value;
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) internal {
        s.balanceOf[from] = s.balanceOf[from]- value;
        s.totalSupply = s.totalSupply - value;
        emit Transfer(from, address(0), value);
    }

    function _approve(address owner, address spender, uint256 value) private {
        s.allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(address from, address to, uint256 value) private {
        s.balanceOf[from] = s.balanceOf[from] - value;
        s.balanceOf[to] = s.balanceOf[to] + value;
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint256 value) external override returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external override returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external override returns (bool) {
        if (s.allowance[from][msg.sender] != type(uint256).max) {
            s.allowance[from][msg.sender] -= value;
        }
        _transfer(from, to, value);
        return true;
    }

    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 _v, bytes32 _r, bytes32 _s) external override {
        require(deadline >= block.timestamp, 'DeltaSwap: EXPIRED');
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                s.DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, s.nonces[owner]++, deadline))
            )
        );
        address recoveredAddress = ecrecover(digest, _v, _r, _s);
        require(recoveredAddress != address(0) && recoveredAddress == owner, 'DeltaSwap: INVALID_SIGNATURE');
        _approve(owner, spender, value);
    }
}