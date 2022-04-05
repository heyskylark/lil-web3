
// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface Hevm {
    // Sets the *next* call's msg.sender to be the input address
	function prank(address) external;

    // Expects an error on next call
	function expectRevert(bytes calldata) external;
}
