// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.13;

import '../LilENS.sol';
import 'ds-test/test.sol';
import { Vm } from 'forge-std/Vm.sol';

contract User {}

contract LilENSTest is DSTest {
    Vm internal hevm;
    User internal user;
    LilENS internal lilENS;

    function setUp() public {
        user = new User();
        lilENS = new LilENS();
        hevm = Vm(HEVM_ADDRESS);
    }

    function testCanRegister() public {
        assertEq(lilENS.lookup('test-name'), address(0));

        lilENS.register('test-name');

		assertEq(lilENS.lookup('test-name'), address(this));
    }

    function testCannotRegisterOwnedName() public {
        lilENS.register('test-name');
        assertEq(lilENS.lookup('test-name'), address(this));

        hevm.prank(address(user));
        hevm.expectRevert(abi.encodeWithSignature('NameRegistered()'));
        lilENS.register('test-name');

        assertEq(lilENS.lookup('test-name'), address(this));
    }

    function testCanTransferOwnership() public {
        lilENS.register('test-name');
        assertEq(lilENS.lookup('test-name'), address(this));

        lilENS.setOwner('test-name', address(user));
        assertEq(lilENS.lookup('test-name'), address(user));
    }

    function testNonOwnerCannotTransferOwnership() public {
        lilENS.register('test-name');
        assertEq(lilENS.lookup('test-name'), address(this));

        hevm.prank(address(user));
        hevm.expectRevert(abi.encodeWithSignature('Unauthorized()'));
        lilENS.setOwner('test-name', address(user));

        assertEq(lilENS.lookup('test-name'), address(this));
    }
}
