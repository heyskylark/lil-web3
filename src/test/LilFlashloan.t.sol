// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.13;

import { Vm } from 'forge-std/Vm.sol';
import { DSTest } from 'ds-test/test.sol';
import { stdError } from 'forge-std/Test.sol';
import { stdError } from 'forge-std/Test.sol';
import { ERC20 } from 'solmate/tokens/ERC20.sol';
import { LilFlashloan, ValidFlashloan, InvalidFlashloan, IERC3156FlashLender, IERC3156FlashBorrower } from '../LilFlashloan.sol';

contract User {}

contract TestToken is ERC20('Test ERC20', 'TEST', 18) {
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract LilFlashloanTest is DSTest {
    Vm internal hevm;
    User internal user;
    TestToken internal testToken;
    LilFlashloan internal lilFlashloan;
    ValidFlashloan internal validFlashloan;
    InvalidFlashloan internal invalidFlashloan;

    event FeeSet(ERC20 indexed token, uint256 amount);
    event Withdraw(ERC20 indexed token, uint256 amount);
    event Flashloaned(IERC3156FlashBorrower indexed callback, ERC20 indexed token, uint256 amount);

    function setUp() public {
        user = new User();
        testToken = new TestToken();
        lilFlashloan = new LilFlashloan();
        validFlashloan = new ValidFlashloan(lilFlashloan);
        invalidFlashloan = new InvalidFlashloan(lilFlashloan);
        hevm = Vm(HEVM_ADDRESS);
    }

    function testFlashloanWithValidBorrow() public {
        assertEq(lilFlashloan.fees(testToken), 0);

        testToken.mint(address(lilFlashloan), 1_000_000 ether);
        testToken.mint(address(validFlashloan), 50_000 ether);

        hevm.expectEmit(true, false, false, true);
        emit FeeSet(testToken, 500);
        lilFlashloan.setFee(testToken, 5_00); // 5% fee

        uint256 initialBalance = testToken.balanceOf(address(lilFlashloan));
        uint256 borrowBalance = testToken.balanceOf(address(validFlashloan));

        assertEq(initialBalance, 1_000_000 ether);
        assertEq(borrowBalance, 50_000 ether);
        assertEq(lilFlashloan.fees(testToken), 500);

        uint256 fee = lilFlashloan.flashFee(testToken, 1_000_000 ether);

        hevm.expectEmit(true, true, false, true);
        emit Flashloaned(validFlashloan, testToken, 1_000_000 ether);
        validFlashloan.execute(testToken, 1_000_000 ether);

        assertEq(fee, 50_000 ether);
        assertEq(testToken.balanceOf(address(lilFlashloan)), initialBalance + fee);
        assertEq(testToken.balanceOf(address(validFlashloan)), borrowBalance - fee);
    }

    function testFlashloanFailsWithValidBorrowWithInsufficientFunds() public {
        assertEq(lilFlashloan.fees(testToken), 0);

        testToken.mint(address(lilFlashloan), 1_000_000 ether);

        hevm.expectEmit(true, false, false, true);
        emit FeeSet(testToken, 500);
        lilFlashloan.setFee(testToken, 5_00); // 5% fee

        uint256 initialBalance = testToken.balanceOf(address(lilFlashloan));
        uint256 borrowBalance = testToken.balanceOf(address(validFlashloan));

        assertEq(initialBalance, 1_000_000 ether);
        assertEq(borrowBalance, 0 ether);
        assertEq(lilFlashloan.fees(testToken), 500);

        hevm.expectRevert(stdError.arithmeticError);
        validFlashloan.execute(testToken, 1_000_000 ether);

        assertEq(testToken.balanceOf(address(lilFlashloan)), initialBalance);
        assertEq(testToken.balanceOf(address(validFlashloan)), borrowBalance);
    }

    function testFlashloanWithInvalidBorrow() public {
        assertEq(lilFlashloan.fees(testToken), 0);

        testToken.mint(address(lilFlashloan), 1_000_000 ether);
        lilFlashloan.setFee(testToken, 5_00); // 5% fee

        uint256 initialBalance = testToken.balanceOf(address(lilFlashloan));
        uint256 borrowBalance = testToken.balanceOf(address(invalidFlashloan));

        assertEq(initialBalance, 1_000_000 ether);
        assertEq(borrowBalance, 0 ether);
        assertEq(lilFlashloan.fees(testToken), 500);

        hevm.expectRevert(abi.encodeWithSignature('FundsNotReturned()'));
        invalidFlashloan.execute(testToken, 1_000_000 ether);

        assertEq(testToken.balanceOf(address(lilFlashloan)), initialBalance);
        assertEq(testToken.balanceOf(address(invalidFlashloan)), borrowBalance);
    }

    function testFlashFeeWhenNoFeePresent() public {
        uint256 fee = lilFlashloan.flashFee(testToken, 1_000_000);
        assertEq(fee, 0);
    }

    function testFlashFeeWhenFeePresent() public {
        hevm.expectEmit(true, false, false, true);
        emit FeeSet(testToken, 500);
        lilFlashloan.setFee(testToken, 5_00); // 5% fee

        uint256 fee = lilFlashloan.flashFee(testToken, 1_000_000);
        assertEq(fee, 50_000);
    }

    function testSetFeeWithInvalidPercentage() public {
        hevm.expectRevert(abi.encodeWithSignature('InvalidFeeAmount()'));
        lilFlashloan.setFee(testToken, 200_00); // 200% fee
    }

    function testNonOwnerCannotSetFee() public {
        hevm.prank(address(user));
        hevm.expectRevert(abi.encodeWithSignature('Unauthorized()'));
        lilFlashloan.setFee(testToken, 5_00); // 5% fee
    }

    function testWithdrawAsOwner() public {
        testToken.mint(address(lilFlashloan), 1_000_000 ether);

        uint256 initLiquidity = lilFlashloan.maxFlashLoan(testToken);
        assertEq(initLiquidity, 1_000_000 ether);

        uint256 withdrawAmount = 500_000 ether;
        hevm.expectEmit(true, false, false, true);
        emit Withdraw(testToken, withdrawAmount);
        lilFlashloan.withdraw(testToken, withdrawAmount);

        assertEq(lilFlashloan.maxFlashLoan(testToken), initLiquidity - withdrawAmount);
    }

    function testWithdrawAsNonOwner() public {
        testToken.mint(address(lilFlashloan), 1_000_000 ether);

        uint256 initLiquidity = lilFlashloan.maxFlashLoan(testToken);
        assertEq(initLiquidity, 1_000_000 ether);

        hevm.prank(address(user));
        hevm.expectRevert(abi.encodeWithSignature('Unauthorized()'));
        lilFlashloan.withdraw(testToken, 500_000 ether);

        assertEq(lilFlashloan.maxFlashLoan(testToken), initLiquidity);
    }
}
