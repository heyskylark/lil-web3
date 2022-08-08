// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.13;

import { Vm } from 'forge-std/Vm.sol';
import { DSTest } from 'ds-test/test.sol';
import { stdError } from 'forge-std/Test.sol';
import { ERC20 } from 'solmate/tokens/ERC20.sol';
import { LilJuicebox, JuiceboxToken } from '../LilJuicebox.sol';

contract User {
    receive() external payable {}
}

contract LilJuiceboxTest is DSTest {
    User internal user;
    LilJuicebox internal lilJuicebox;
    JuiceboxToken internal juiceboxToken;
    Vm internal hevm = Vm(HEVM_ADDRESS);

    event StateUpdated(LilJuicebox.State);
    event Contributed(address indexed from, uint256 amount);
    event Refunded(address indexed to, uint256 amount);
    event Withdraw(uint256 amount);
    event Renounced();

    function setUp() public {
        user = new User();
        lilJuicebox = new LilJuicebox('Test Token', 'TEST');
        juiceboxToken = lilJuicebox.juiceboxToken();
    }

    function testContributingSuccesfully() public {
        uint256 startingBalance = address(this).balance;

        assertEq(address(lilJuicebox).balance, 0);
        assertEq(juiceboxToken.balanceOf(address(this)), 0);

        hevm.expectEmit(true, false, false, true);
        emit Contributed(address(this), 1 ether);

        lilJuicebox.contribute{ value: 1 ether }();
        assertEq(address(lilJuicebox).balance, 1 ether);
        assertEq(juiceboxToken.balanceOf(address(this)), 1_000_000 ether);
        assertEq(address(this).balance, startingBalance - 1 ether);
    }

    function testContributeFailsStateClosed() public {
        uint256 startingBalance = address(this).balance;

        assertEq(address(lilJuicebox).balance, 0);
        assertEq(juiceboxToken.balanceOf(address(this)), 0);

        lilJuicebox.updateState(LilJuicebox.State.CLOSED);

        hevm.expectRevert(abi.encodeWithSignature('ContributionsClosed()'));

        lilJuicebox.contribute{ value: 1 ether }();
        assertEq(address(lilJuicebox).balance, 0);
        assertEq(juiceboxToken.balanceOf(address(this)), 0);
        assertEq(address(this).balance, startingBalance);
    }

    function testRefundSuccesfully() public {
        lilJuicebox.contribute{ value: 1 ether }();
        lilJuicebox.updateState(LilJuicebox.State.REFUNDING);

        uint256 preRefundBalance = address(this).balance;
        assertEq(address(lilJuicebox).balance, 1 ether);
        assertEq(juiceboxToken.balanceOf(address(this)), 1_000_000 ether);

        hevm.expectEmit(true, false, false, true);
        emit Refunded(address(this), 1 ether);

        lilJuicebox.refund(1_000_000 ether);

        assertEq(address(lilJuicebox).balance, 0);
        assertEq(juiceboxToken.balanceOf(address(this)), 0);
        assertEq(address(this).balance,  preRefundBalance + 1 ether);
    }

    function testRefundFailsWhenRefundingIsNotOpen() public {
        lilJuicebox.contribute{ value: 1 ether }();

        assertEq(address(lilJuicebox).balance, 1 ether);
        assertEq(juiceboxToken.balanceOf(address(this)), 1_000_000 ether);

        hevm.expectRevert(abi.encodeWithSignature('RefundingClosed()'));

        lilJuicebox.refund(1_000_000 ether);

        assertEq(address(lilJuicebox).balance, 1 ether);
        assertEq(juiceboxToken.balanceOf(address(this)), 1_000_000 ether);
    }

    function testRefundFailsWhenNotEnoughTokens() public {
        lilJuicebox.contribute{ value: 1 ether }();
        lilJuicebox.updateState(LilJuicebox.State.REFUNDING);

        uint256 myBalance = address(this).balance;

        hevm.expectRevert(stdError.arithmeticError);

        lilJuicebox.refund(2_000_000 ether);

        assertEq(address(lilJuicebox).balance, 1 ether);
		assertEq(juiceboxToken.balanceOf(address(this)), 1_000_000 ether);
		assertEq(address(this).balance, myBalance);
    }

    function testWithdrawSuccesfullyAsOwner() public {
        hevm.deal(address(lilJuicebox), 10 ether);

        uint256 myBalance = address(this).balance;

        hevm.expectEmit(false, false, false, true);
        emit Withdraw(10 ether);

        lilJuicebox.withdraw();

        assertEq(address(this).balance, myBalance + 10 ether);
    }

    function testWithdrawFailsAsNonOwner() public {
        hevm.deal(address(lilJuicebox), 10 ether);

        uint256 usersBalance = address(user).balance;

        hevm.prank(address(user));
        hevm.expectRevert(abi.encodeWithSignature('Unauthorized()'));
        lilJuicebox.withdraw();

        assertEq(address(user).balance, usersBalance);
    }

    function testRenounceAsOwner() public {
        assertEq(lilJuicebox.owner(), address(this));

        hevm.expectEmit(false, false, false, false);
        emit Renounced();

        lilJuicebox.renounce();

        assertEq(lilJuicebox.owner(), address(0));
    }

    function testRenounceFailsAsNonOwner() public {
        assertEq(lilJuicebox.owner(), address(this));

        hevm.prank(address(user));
        hevm.expectRevert(abi.encodeWithSignature('Unauthorized()'));

        lilJuicebox.renounce();

        assertEq(lilJuicebox.owner(), address(this));
    }

    function testChangeStateToClosedAsOwner() public {
        assertEq(uint256(lilJuicebox.getState()), uint256(LilJuicebox.State.OPEN));

        hevm.expectEmit(false, false, false, true);
        emit StateUpdated(LilJuicebox.State.CLOSED);

        lilJuicebox.updateState(LilJuicebox.State.CLOSED);

        assertEq(uint256(lilJuicebox.getState()), uint256(LilJuicebox.State.CLOSED));
    }

    function testChangeStateToRefundingAsOwner() public {
        assertEq(uint256(lilJuicebox.getState()), uint256(LilJuicebox.State.OPEN));

        hevm.expectEmit(false, false, false, true);
        emit StateUpdated(LilJuicebox.State.REFUNDING);

        lilJuicebox.updateState(LilJuicebox.State.REFUNDING);

        assertEq(uint256(lilJuicebox.getState()), uint256(LilJuicebox.State.REFUNDING));
    }

    function testChangeStateFailsAsNonOwner() public {
        assertEq(uint256(lilJuicebox.getState()), uint256(LilJuicebox.State.OPEN));

        hevm.prank(address(user));
        hevm.expectRevert(abi.encodeWithSignature('Unauthorized()'));

        lilJuicebox.updateState(LilJuicebox.State.REFUNDING);

        assertEq(uint256(lilJuicebox.getState()), uint256(LilJuicebox.State.OPEN));
    }

    receive() external payable {}
}
