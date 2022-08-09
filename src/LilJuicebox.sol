// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.13;

import { DSTest } from 'ds-test/test.sol';
import { ERC20 } from 'solmate/tokens/ERC20.sol';
import { SafeTransferLib } from 'solmate/utils/SafeTransferLib.sol';

contract JuiceboxToken is ERC20 {
    /// ERRORS ///
    
    /// @notice Thrown when the caller is not aloud to call a function
    error Unauthorized();

    /// @notice The owner of this campaign token
    address public immutable owner;

    constructor(string memory name, string memory symbol) payable ERC20(name, symbol, 18) {
        owner = msg.sender;
    }

    /// @notice A modifier that checks if the caller owns this contract
    modifier isOwner() {
        if (msg.sender != owner) revert Unauthorized();

        _;
    }

    /// @notice A wrapper mint function that can only be called by the LilJuicebox contract
    function mint(address to, uint256 amount) public payable isOwner() {
        _mint(to, amount);
    }

    /// @notice A wrapper burn function that can only be called by the LilJuicebox contract
    function burn(address from, uint256 amount) public payable isOwner() {
        _burn(from, amount);
    }
}

/// @title Lil Juicebox
/// @author Skylark
/// @notice A simple version of Juicebox crowd sourcing
contract LilJuicebox {
    /// ERRORS ///
    
    /// @notice Thrown when the caller is not aloud to call a function
    error Unauthorized();

    /// @notice Thrown when contributions are closed
    error ContributionsClosed();

    /// @notice Thrown when refudning is closed
    error RefundingClosed();

    /// EVENTS ///

    /// @notice Emited when the state is updated
    event StateUpdated(State state);

    /// @notice Emited when a user contirbutes
    event Contributed(address indexed from, uint256 amount);

    /// @notice Emited when a user refunds their contribution
    event Refunded(address indexed to, uint256 amount);

    /// @notice Emited when the owner withdraws contributed funds
    event Withdraw(uint256 amount);

    /// @notice Emited when the owner renounces ownership
    event Renounced();

    /// @notice Enum used to track the contribution state of the contract
    enum State {
        CLOSED,
        OPEN,
        REFUNDING
    }

    /// @notice The address that owns this contract
    address public owner;

    /// @notice The state of the contract
    State public getState;

    /// @notice This token is given in exchange for ETH contributions
    JuiceboxToken public immutable juiceboxToken;

    /// @notice The ratio of ERC20 Juicebox token per ETH
	uint256 public constant TOKEN_ETH_RATIO = 1_000_000;

    constructor(string memory name, string memory symbol) {
        owner = msg.sender;
        getState = State.OPEN;
        juiceboxToken = new JuiceboxToken(name, symbol);
    }

    /// @notice A modifier that checks if the caller owns this contract
    modifier isOwner() {
        if (msg.sender != owner) revert Unauthorized();

        _;
    }

    /// @notice Used to contribute ETH for Juicebox tokens
    function contribute() public payable {
        if (getState != State.OPEN) revert ContributionsClosed();

        emit Contributed(msg.sender, msg.value);

        uint256 tokenAmount = _ethToToken(msg.value);
        juiceboxToken.mint(msg.sender, tokenAmount);
    }

    /// @notice Used to get contribution refund when contributions are opened
    /// @param amount the amount to refund
    function refund(uint256 amount) public {
        if (getState != State.REFUNDING) revert RefundingClosed();

        uint256 refundETHAmount = _tokenToEth(amount);

        emit Refunded(msg.sender, refundETHAmount);

        juiceboxToken.burn(msg.sender, amount);
        SafeTransferLib.safeTransferETH(msg.sender, refundETHAmount);
    }

    /// @notice The owner withdraws all funds when called
    function withdraw() public isOwner() {
        uint256 balance = address(this).balance;

        emit Withdraw(balance);
        SafeTransferLib.safeTransferETH(msg.sender, balance);
    }

    /// @notice Changes the contract state between (OPEN, CLOSED, and REFUNDING)
    /// @param state The State to change this contract to
    function updateState(State state) public isOwner() {
        emit StateUpdated(state);
        getState = state;
    }

    /// @notice Allows the owner to renounce ownership over the contract, making any changes to the contract after impossible
    function renounce() public isOwner() {
        emit Renounced();
        owner = address(0);
    }

    /// @notice A helper function that converts the amount of Juicebox tokens given to the equivalent ETH
    function _tokenToEth(uint256 amount) private pure returns (uint256) {
        uint256 ethAmount;

        assembly {
            ethAmount := div(amount, TOKEN_ETH_RATIO)
        }

        return ethAmount;
    }

    /// @notice A helper function that converts ETH to the equivalent Juicebox tokens
    function _ethToToken(uint256 amount) private pure returns (uint256) {
        uint256 tokenAmount;

        assembly {
            tokenAmount := mul(amount, TOKEN_ETH_RATIO)
        }

        return tokenAmount;
    }

    /// @dev This function ensures this contract can receive ETH
	receive() external payable {}
}
