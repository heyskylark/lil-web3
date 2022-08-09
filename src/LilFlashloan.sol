// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.13;

import { ERC20 } from 'solmate/tokens/ERC20.sol';

interface IERC3156FlashLender {
    /// @notice A callback function that is called by executing a flashloan
    function onFlashLoan(
        ERC20 token,
        uint256 amount,
        bytes calldata data
    ) external;
}

/// @title Lil Flashloan
/// @author Skylark
/// @notice A simplified version showing the basic functionality of a Flash Loan
contract LilFlashloan {
    /// ERRORS ///

    /// @notice Thrown when the caller is not aloud to call a function
    error Unauthorized();

    /// @notice Thrown when an invalid fee percentage is given
    error InvalidFeeAmount();

    /// @notice Thrown when a flashloan callback does not return the funds
    error FundsNotReturned();

    /// EVENTS ///
    
    /// @notice Emited when a fee is set for an ERC20 token
    event FeeSet(ERC20 indexed token, uint256 amount);

    /// @notice Emited when the owner withdraws liquidity
    event Withdraw(ERC20 indexed token, uint256 amount);

    event Flashloaned(IERC3156FlashLender indexed callback, ERC20 indexed token, uint256 amount);

    /// @notice Address pointing to the owner of the flash loan
    address private immutable owner;

    /// @notice A mapping of each tokens fee percentage multiplied by 100 to avoid decimals
    mapping(ERC20 => uint256) fees;

    /// @notice A modifier that checks if the caller owns this contract
    modifier isOwner() {
        if (msg.sender != owner) revert Unauthorized();

        _;
    }
    
    constructor() {
        owner = msg.sender;
    }

    /// @notice Used to execute a flashloan
    /// @param callback the callback function executed with the flashloan
    /// @param token the ERC20 token type that will be sent for the flashloan
    /// @param amount the amount of ERC20 tokens setn for the flashloan
    function execute(
        IERC3156FlashLender callback,
        ERC20 token,
        uint256 amount,
        bytes calldata data
    ) public {
        uint256 initialBalance = token.balanceOf(address(this));

        emit Flashloaned(callback, token, amount);

        token.transfer(address(callback), amount);
        callback.onFlashLoan(token, amount, data);

        if (initialBalance + getFee(token, amount) < token.balanceOf(address(this))) revert FundsNotReturned();
    }

    /// @notice Used to get the fee percent for a given token
    /// @param token the token to get the flash loan fee for
    /// @param amount the number of tokens that will be flash loaned
    /// @return uint256 a fee percentage, 0 if the fee doesn't exist
    function getFee(ERC20 token, uint256 amount) public view returns (uint256) {
        uint256 fee = fees[token];
        if (fee == 0) return 0;

        return amount * fee / 10_000;
    }

    /// @notice Used to set fees for a specific token.
    /// @param token the ERC20 token to set flash loan fees for
    /// @param fee the fee percent, a percent value multiplied by 100
    function setFee(ERC20 token, uint256 fee) isOwner() public {
        if (fee > 100_00) revert InvalidFeeAmount();

        emit FeeSet(token, fee);

        fees[token] = fee;
    }

    /// @notice Owner can withdraw all token liquidity from this contract
    /// @param token the token to withdraw
    /// @param amount the amount of tokens to withdraw
    function withdraw(ERC20 token, uint256 amount) isOwner() public {
        emit Withdraw(token, amount);

        token.transfer(msg.sender, amount);
    }
}