// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.13;

import { Vm } from 'forge-std/Vm.sol';
import { DSTest } from 'ds-test/test.sol';
import { ERC721 } from 'solmate/tokens/ERC721.sol';
import { stdError } from 'forge-std/Test.sol';
import { LilFractional, FractionalToken } from '../LilFractional.sol';

contract User {}

contract TestNFT is ERC721('Test ERC721', 'TEST') {
    uint256 public tokenId = 1;

    function tokenURI(uint256) public pure override returns (string memory) {
        return 'test';
    }

    function mint() public payable returns (uint256) {
        _mint(msg.sender, tokenId);

        return tokenId++;
    }
}

contract LilFractionalTest is DSTest {
    uint256 nftId;
    User internal user;
    LilFractional internal lilFractional;
    TestNFT internal nft;
    Vm internal hevm = Vm(HEVM_ADDRESS);

    event VaultCreated(uint256 vaultId);
    event VaultDestroyed(uint256 vaultId);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function setUp() public {
        user = new User();
        lilFractional = new LilFractional();
        nft = new TestNFT();

        // Give lil fractional approval to test's NFT
        nft.setApprovalForAll(address(lilFractional), true);

        // Give lil franctonal access to User's NFT
		hevm.prank(address(user));
		nft.setApprovalForAll(address(lilFractional), true);

        nftId = nft.mint();
    }

    function testFractionalizeValidNFT() public {
        (ERC721 zeroContract, , , ) = lilFractional.getVault(1);
        assertEq(address(zeroContract), address(0));
        assertEq(nft.ownerOf(nftId), address(this));
        
        hevm.expectEmit(true, true, false, true);
		emit Transfer(address(0), address(this), 20 ether);

        hevm.expectEmit(false, false, false, true);
        emit VaultCreated(1);

        uint256 vaultId = lilFractional.split(nft, nftId, 20 ether, 'Test Fractional', 'TFRAC');

        (
            ERC721 nftContract,
            uint256 nftTokenId,
            uint256 fractionalSupply,
            FractionalToken tokenContract
        ) = lilFractional.getVault(vaultId);

        assertEq(address(nftContract), address(nft));
        assertEq(nftTokenId,nftId);
        assertEq(fractionalSupply, 20 ether);
        assertEq(tokenContract.balanceOf(address(this)), 20 ether);
        assertEq(nft.ownerOf(nftId), address(lilFractional));
    }

    function testNonOwnerCannotFractionalizeToken() public {
        (ERC721 zeroContract1, , , ) = lilFractional.getVault(1);
        assertEq(address(zeroContract1), address(0));
        assertEq(nft.ownerOf(nftId), address(this));

        hevm.prank(address(user));
        hevm.expectRevert("WRONG_FROM");

        lilFractional.split(nft, nftId, 20 ether, 'Test Fractional', 'TFRAC');

        (ERC721 zeroContract2, , , ) = lilFractional.getVault(1);
        assertEq(address(zeroContract2), address(0));
        assertEq(nft.ownerOf(nftId), address(this));
    }

    function testJoinWithFullTokenSupply() public {
        (ERC721 zeroContract, , , ) = lilFractional.getVault(1);
        assertEq(address(zeroContract), address(0));
        assertEq(nft.ownerOf(nftId), address(this));

        uint256 vaultId = lilFractional.split(nft, nftId, 20 ether, 'Test Fractional', 'TFRAC');

        (, , ,FractionalToken tokenContract) = lilFractional.getVault(vaultId);
        assertEq(nft.ownerOf(nftId), address(lilFractional));
        assertEq(tokenContract.balanceOf(address(this)), 20 ether);

        tokenContract.approve(address(lilFractional), type(uint256).max);

        hevm.expectEmit(false, false, false, true);

        emit VaultDestroyed(vaultId);

        lilFractional.join(vaultId);

        (ERC721 joinedContract, , , ) = lilFractional.getVault(1);
        assertEq(address(joinedContract), address(0));
        assertEq(nft.ownerOf(nftId), address(this));
        assertEq(tokenContract.balanceOf(address(this)), 0 ether);
    }

    function testJoinWithoutFullTokenSupply() public {
        uint256 vaultId = lilFractional.split(nft, nftId, 20 ether, 'Test Fractional', 'TFRAC');

        (, , ,FractionalToken tokenContract) = lilFractional.getVault(vaultId);

        tokenContract.transfer(address(user), 19 ether);

        hevm.expectRevert(stdError.arithmeticError); // This error is dependent on the solmate impl of ERC20
		lilFractional.join(vaultId);

        assertEq(nft.ownerOf(nftId), address(lilFractional));
        assertEq(tokenContract.balanceOf(address(this)), 1 ether);
    }

    function testJoinWithNonExistingVault() public {
        hevm.expectRevert(abi.encodeWithSignature('VaultNotFound()'));
        lilFractional.join(1);
    }

    function testJoinWithoutHoldingAnyTokens() public {
        uint256 vaultId = lilFractional.split(nft, nftId, 20 ether, 'Test Fractional', 'TFRAC');

        (, , ,FractionalToken tokenContract) = lilFractional.getVault(vaultId);
        
        hevm.startPrank(address(user));
        tokenContract.approve(address(user), type(uint256).max);

        hevm.expectRevert(stdError.arithmeticError); // This error is dependent on the solmate impl of ERC20
		lilFractional.join(vaultId);

        assertEq(nft.ownerOf(nftId), address(lilFractional));
        assertEq(tokenContract.balanceOf(address(this)), 20 ether);
    }
}
