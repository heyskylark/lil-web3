// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.13;

import { ERC20 } from 'solmate/tokens/ERC20.sol';

interface IERC3156FlashBorrower {
    /**
     * @dev Receive a flash loan.
     * @param initiator The initiator of the loan.
     * @param token The loan currency.
     * @param amount The amount of tokens lent.
     * @param fee The additional amount of tokens to repay.
     * @param data Arbitrary data structure, intended to contain user-defined parameters.
     * @return The keccak256 hash of "ERC3156FlashBorrower.onFlashLoan"
     */
    function onFlashLoan(
        address initiator,
        ERC20 token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32);
}

interface IERC3156FlashLender {
    /**
     * @dev The amount of currency available to be lent.
     * @param token The loan currency.
     * @return The amount of `token` that can be borrowed.
     */
    function maxFlashLoan(
        ERC20 token
    ) external view returns (uint256);

    /**
     * @dev The fee to be charged for a given loan.
     * @param token The loan currency.
     * @param amount The amount of tokens lent.
     * @return The amount of `token` to be charged for the loan, on top of the returned principal.
     */
    function flashFee(
        ERC20 token,
        uint256 amount
    ) external view returns (uint256);

    /**
     * @dev Initiate a flash loan.
     * @param receiver The receiver of the tokens in the loan, and the receiver of the callback.
     * @param token The loan currency.
     * @param amount The amount of tokens lent.
     * @param data Arbitrary data structure, intended to contain user-defined parameters.
     */
    function flashLoan(
        IERC3156FlashBorrower receiver,
        ERC20 token,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);
}

contract ValidFlashloan is IERC3156FlashBorrower {
    /// ERRORS ///
    error UntrustedLender();

    error UntrustedInitiator();

    IERC3156FlashLender internal _lender;

    constructor(IERC3156FlashLender lender) {
        _lender = lender;
    }

    function onFlashLoan(
        address initiator,
        ERC20 token,
        uint256 amount,
        uint256 fee,
        bytes calldata
    ) external override returns (bytes32) {
        if (msg.sender != address(_lender)) revert UntrustedLender();
        if (initiator != address(this)) revert UntrustedInitiator();

        token.transfer(address(_lender), amount + fee);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function execute(ERC20 token, uint256 amount) public {
        _lender.flashLoan(this, token, amount, abi.encode(""));
    }
}

contract InvalidFlashloan is IERC3156FlashBorrower {
    /// ERRORS ///
    error UntrustedLender();

    error UntrustedInitiator();

    IERC3156FlashLender internal _lender;

    constructor(IERC3156FlashLender lender) {
        _lender = lender;
    }

    function onFlashLoan(
        address initiator,
        ERC20,
        uint256,
        uint256,
        bytes calldata
    ) external override view returns (bytes32) {
        if (msg.sender != address(_lender)) revert UntrustedLender();
        if (initiator != address(this)) revert UntrustedInitiator();

        // Do stuff and don't return the money 👮‍♂️...

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function execute(ERC20 token, uint256 amount) public {
        _lender.flashLoan(this, token, amount, abi.encode(""));
    }
}

/// @title Lil Flashloan
/// @author Skylark
/// @notice A simplified version showing the basic functionality of a Flash Loan
contract LilFlashloan is IERC3156FlashLender {
    /// ERRORS ///

    /// @notice Thrown when the caller is not aloud to call a function
    error Unauthorized();

    /// @notice Thrown when an invalid fee percentage is given
    error InvalidFeeAmount();

    /// @notice Thrown when a flashloan callback does not return the funds
    error FundsNotReturned();

    /// @notice Thrown when the flashloan callback fails
    error FlashloanCallbackFailed();

    /// EVENTS ///
    
    /// @notice Emited when a fee is set for an ERC20 token
    event FeeSet(ERC20 indexed token, uint256 amount);

    /// @notice Emited when the owner withdraws liquidity
    event Withdraw(ERC20 indexed token, uint256 amount);

    event Flashloaned(IERC3156FlashBorrower indexed callback, ERC20 indexed token, uint256 amount);

    /// @notice Constant representing a succesfully flashloan callback response
    bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    /// @notice Address pointing to the owner of the flash loan
    address private immutable owner;

    /// @notice A mapping of each tokens fee percentage multiplied by 100 (ie. 1 == 0.01%)
    mapping(ERC20 => uint256) public fees;

    /// @notice A modifier that checks if the caller owns this contract
    modifier isOwner() {
        if (msg.sender != owner) revert Unauthorized();

        _;
    }
    
    /// @notice Simply sets the contract creator to owner
    constructor() {
        owner = msg.sender;
    }

    /// @notice Used to execute a flashloan
    /// @param receiver the reciever that will execute the callback function with the flashloan
    /// @param token the ERC20 token type that will be sent for the flashloan
    /// @param amount the amount of ERC20 tokens setn for the flashloan
    function flashLoan(
        IERC3156FlashBorrower receiver,
        ERC20 token,
        uint256 amount,
        bytes calldata data
    ) external override returns(bool) {
        uint256 initialBalance = token.balanceOf(address(this));

        emit Flashloaned(receiver, token, amount);

        uint256 fee = _flashFee(token, amount);
        token.transfer(address(receiver), amount);

        if (receiver.onFlashLoan(address(receiver), token, amount, fee, data) != CALLBACK_SUCCESS) revert FlashloanCallbackFailed();
        if (token.balanceOf(address(this)) < initialBalance + fee) revert FundsNotReturned();

        return true;
    }

    /// @notice Internal function used to get the fee percent for a given token
    /// @param token the token to get the flash loan fee for
    /// @param amount the number of tokens that will be flash loaned
    /// @return uint256 a fee percentage, 0 if the fee doesn't exist
    function _flashFee(ERC20 token, uint256 amount) internal view returns (uint256) {
        uint256 fee = fees[token];
        if (fee == 0) return fee;

        return amount * fee / 10_000;
    }

    /// @notice Used to get the fee percent for a given token
    /// @param token the token to get the flash loan fee for
    /// @param amount the number of tokens that will be flash loaned
    /// @return uint256 a fee percentage, 0 if the fee doesn't exist
    function flashFee(ERC20 token, uint256 amount) external override view returns (uint256) {
        return _flashFee(token, amount);
    }

    /// @notice Used to set fees for a specific token.
    /// @param token the ERC20 token to set flash loan fees for
    /// @param fee the fee percent, a percent value multiplied by 100 (1 == 0.01%)
    function setFee(ERC20 token, uint256 fee) isOwner() public {
        if (fee > 100_00) revert InvalidFeeAmount();

        emit FeeSet(token, fee);

        fees[token] = fee;
    }

    /// @notice Used to fetch the max flash loan the caller can recieve
    /// @param token the ERC20 token to get flashloan liquidity amount for
    /// @return uint256 amount available for flashloan
    function maxFlashLoan(ERC20 token) external override view returns (uint256) {
        return token.balanceOf(address(this));
    }

    /// @notice Owner can withdraw all token liquidity from this contract
    /// @param token the token to withdraw
    /// @param amount the amount of tokens to withdraw
    function withdraw(ERC20 token, uint256 amount) isOwner() public {
        emit Withdraw(token, amount);

        token.transfer(msg.sender, amount);
    }
}
