// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import './DSOwnable.sol';

/// @dev Ownable2Step contract from OpenZeppelin Contracts v5.0.0
abstract contract DSOwnable2Step is DSOwnable {
    address private _pendingOwner;

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    /// @dev Returns the address of the pending owner.
    function pendingOwner() public view virtual returns (address) {
        return _pendingOwner;
    }

    /// @dev Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one.
    /// @dev Can only be called by the current owner.
    function transferOwnership(address newOwner) public virtual override onlyOwner {
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner(), newOwner);
    }

    /// @dev Transfers ownership of the contract to a new account (`newOwner`) and deletes any pending owner.
    /// @dev Internal function without access restriction.
    function _transferOwnership(address newOwner) internal virtual override {
        delete _pendingOwner;
        super._transferOwnership(newOwner);
    }

    /// @dev The new owner accepts the ownership transfer.
    function acceptOwnership() public virtual {
        address sender = msg.sender;
        if (pendingOwner() != sender) {
            revert OwnableUnauthorizedAccount(sender);
        }
        _transferOwnership(sender);
    }
}
