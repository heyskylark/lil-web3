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

    modifier isOwner() {
        if (msg.sender != owner) revert Unauthorized();

        _;
    }

    function mint(address to, uint256 amount) public payable isOwner() {
        _mint(to, amount);
    }

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

    error ContributionsClosed();

    error RefundingClosed();

    error ExceededContributionAmount();

    /// EVENTS ///
    event StateUpdated(State state);

    event Contributed(address indexed from, uint256 amount);

    event Refunded(address indexed to, uint256 amount);

    event Withdraw(uint256 amount);

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

    modifier isOwner() {
        if (msg.sender != owner) revert Unauthorized();

        _;
    }

    function contribute() public payable {
        if (getState != State.OPEN) revert ContributionsClosed();

        emit Contributed(msg.sender, msg.value);

        uint256 tokenAmount = _ethToToken(msg.value);
        juiceboxToken.mint(msg.sender, tokenAmount);
    }

    function refund(uint256 amount) public {
        if (getState != State.REFUNDING) revert RefundingClosed();

        uint256 refundETHAmount = _tokenToEth(amount);

        emit Refunded(msg.sender, refundETHAmount);

        juiceboxToken.burn(msg.sender, amount);
        SafeTransferLib.safeTransferETH(msg.sender, refundETHAmount);
    }

    function withdraw() public isOwner() {
        uint256 balance = address(this).balance;

        emit Withdraw(balance);
        SafeTransferLib.safeTransferETH(msg.sender, balance);
    }

    function updateState(State state) public isOwner() {
        emit StateUpdated(state);
        getState = state;
    }

    function renounce() public isOwner() {
        emit Renounced();
        owner = address(0);
    }

    function _tokenToEth(uint256 amount) private pure returns (uint256) {
        uint256 ethAmount;

        assembly {
            ethAmount := div(amount, TOKEN_ETH_RATIO)
        }

        return ethAmount;
    }

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
