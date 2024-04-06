// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/proxy/beacon/IBeacon.sol';
import '@openzeppelin/contracts/proxy/Proxy.sol';
import '@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol';

/// @dev This contract implements a proxy that gets the implementation address for each call from a beacon
contract DeltaSwapV2Proxy is Proxy {
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
    function _implementation() internal view virtual override returns (address) {
        return IBeacon(_beacon).implementation();
    }
}