// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @dev Ownable contract from OpenZeppelin Contracts v5.0.0
abstract contract DSOwnable {
    address private _owner;

    /// @dev The caller account is not authorized to perform an operation.
    error OwnableUnauthorizedAccount(address account);

    /// @dev The owner is not a valid owner account. (eg. `address(0)`)
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @dev Initializes the contract setting the address provided by the deployer as the initial owner.
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /// @dev Throws if called by any account other than the owner.
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /// @dev Returns the address of the current owner.
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /// @dev Throws if the sender is not the owner.
    function _checkOwner() internal view virtual {
        address sender = msg.sender;
        if (owner() != sender) {
            revert OwnableUnauthorizedAccount(sender);
        }
    }

    /// @dev Leaves the contract without owner. It will not be possible to call `onlyOwner` functions.
    /// @dev Can only be called by the current owner.
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /// @dev Transfers ownership of the contract to a new account (`newOwner`).
    /// @dev Can only be called by the current owner.
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /// @dev Transfers ownership of the contract to a new account (`newOwner`).
    /// @dev Internal function without access restriction.
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
