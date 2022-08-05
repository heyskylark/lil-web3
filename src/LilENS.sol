// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.13;

/// @title lil ens
/// @author Skylark
/// @notice An all in one compact registry and resolver.
contract LilENS {
    /// ERRORS ///

    /// @notice Thrown when trying to transfer a name that is owned by someone else
    error Unauthorized();

    /// @notice Thrown when trying to register a name that is already owned
    error NameRegistered();

    /// EVENTS ///

    /// @notice Event that is emitted when a name is transfered from one owner to another
    /// @param name The ENS that was transfered
    /// @param owner The address the ENS was transfered to
    event Transfer(string name, address owner);

    /// @notice Stores the hashed registered names and their addresses
	/// @dev Public automatically generates a getter for us
    mapping(string => address) public lookup;

    /// @notice A modifier that validates if the current msg.sender is the name's owner
    /// @param name The name to check ownership
    modifier owner(string memory name) {
        if (lookup[name] != msg.sender) revert Unauthorized();

        _;
    }

    /// @notice Registers a hashed name and points it to your address
	/// @param name The name to register
    function register(string memory name) public payable {
        // Check if name is already taken, throw error
        if (lookup[name] != address(0)) revert NameRegistered();

        lookup[name] = msg.sender;
    }

    /// @notice Takes a hashed names and transfers ownership to the given address
	/// @param name The name to transfer
    /// @param addr The address of the new owner
    function setOwner(string memory name, address addr) public payable owner(name) {
        lookup[name] = addr;

        emit Transfer(name, addr);
    }
}
