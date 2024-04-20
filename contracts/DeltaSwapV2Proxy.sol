// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import './interfaces/IDSBeacon.sol';

/// @dev This contract implements a proxy that gets the implementation address for each call from a beacon
contract DeltaSwapV2Proxy {
    // An immutable address for the beacon to avoid unnecessary SLOADs before each delegate call.
    address private immutable _beacon;

    bytes32 internal constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /// @dev Initializes the proxy with `beacon`.
    constructor() {
        address _factory = msg.sender;
        assembly {
            sstore(BEACON_SLOT, _factory) // store beacon address
        }
        _beacon = _factory;
    }

    /// @dev Returns the current implementation address of the associated beacon.
    function _implementation() internal view virtual returns (address) {
        return IDSBeacon(_beacon).implementation();
    }

    /// @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if no other
    fallback() external payable virtual {
        address implementation = _implementation();
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}