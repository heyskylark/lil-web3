// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.13;

import './Hevm.sol';
import '../LilOpenSea.sol';
import 'ds-test/test.sol';
import 'solmate/tokens/ERC721.sol';

contract User {
    receive() external payable {}
}

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

contract LilOpenseaTest is DSTest {
    uint256 nftId;
    Hevm internal hevm;
    User internal user;
    LilOpensea internal lilOpensea;
    TestNFT internal nft;
    uint256 internal testDate;

    event NewListing(LilOpensea.Listing listing);
    event ListingRemoved(LilOpensea.Listing listing);
    event ListingBought(address indexed buyer, LilOpensea.Listing listing);

    function setUp() public {
        user = new User();
        lilOpensea = new LilOpensea();
        nft = new TestNFT();
        hevm = Hevm(HEVM_ADDRESS);
        testDate = 1649505600;

        // Give marketplace access to all tokens for this
        nft.setApprovalForAll(address(lilOpensea), true);

        // Give marketplace access to all tokens for user
        hevm.prank(address(user));
        nft.setApprovalForAll(address(lilOpensea), true);

        nftId = nft.mint();
    }

    function testListsTokenWithAccess() public {
        (, , address currCreator, ,) = lilOpensea.getListing(1);
        assertEq(currCreator, address(0));
        assertEq(nft.ownerOf(nftId), address(this));

        hevm.expectEmit(false, false, false, true);
        emit NewListing(
            LilOpensea.Listing({
                tokenContract: nft,
                tokenId: nftId,
                creator: address(this),
                askPrice: 1 ether,
                expiryDate: 0 
            })
        );

        uint256 listingId = lilOpensea.list(nft, nftId, 1 ether, 0);

        assertEq(nft.ownerOf(nftId), address(lilOpensea));
        
        (
            ERC721 tokenContract,
            uint256 tokenId,
            address creator,
            uint256 askPrice,
            uint256 expiryDate
        ) = lilOpensea.getListing(listingId);
        assertEq(address(tokenContract), address(nft));
        assertEq(tokenId, nftId);
        assertEq(creator, address(this));
        assertEq(askPrice, 1 ether);
        assertEq(expiryDate, 0);
    }

    function testCannotListTokenNonOwner() public {
        assertEq(nft.ownerOf(nftId), address(this));

        hevm.prank(address(user));
        hevm.expectRevert('WRONG_FROM');
        lilOpensea.list(nft, nftId, 1 ether, 0);

        assertEq(nft.ownerOf(nftId), address(this));
    }

    function testCannotListTokenWihtoutAccess() public {
        assertEq(nft.ownerOf(nftId), address(this));

        nft.setApprovalForAll(address(lilOpensea), false);

        hevm.expectRevert('NOT_AUTHORIZED');
        lilOpensea.list(nft, nftId, 1 ether, 0);

        assertEq(nft.ownerOf(nftId), address(this));
    }

    function testPurchaseValidListing() public {
        assertEq(nft.ownerOf(nftId), address(this));

        uint256 thisBalance = address(this).balance;
        nft.transferFrom(address(this), address(user), nftId);
        assertEq(nft.ownerOf(nftId), address(user));

        hevm.prank(address(user));
        uint256 listingId = lilOpensea.list(nft, nftId, 1 ether, testDate);
        assertEq(nft.ownerOf(nftId), address(lilOpensea));
        assertEq(address(user).balance, 0);

        hevm.warp(testDate - 10);
        hevm.expectEmit(true, false, false, true);
        emit ListingBought(
            address(this),
            LilOpensea.Listing({
                tokenContract: nft,
                tokenId: nftId,
                creator: address(user),
                askPrice: 1 ether,
                expiryDate: testDate 
            })
        );
        lilOpensea.buyListing{ value: 1 ether }(listingId);

        assertEq(nft.ownerOf(nftId), address(this));
        assertEq(address(this).balance, thisBalance - 1 ether);
        assertEq(address(user).balance, 1 ether);

        (, , address creator, , ) = lilOpensea.getListing(listingId);
        assertEq(creator, address(0));
    }

    function testPurchaseValidListingWithNoExpiry() public {
        assertEq(nft.ownerOf(nftId), address(this));

        uint256 thisBalance = address(this).balance;
        nft.transferFrom(address(this), address(user), nftId);
        assertEq(nft.ownerOf(nftId), address(user));

        hevm.prank(address(user));
        uint256 listingId = lilOpensea.list(nft, nftId, 1 ether, 0);
        assertEq(nft.ownerOf(nftId), address(lilOpensea));
        assertEq(address(user).balance, 0);

        hevm.warp(testDate);
        hevm.expectEmit(true, false, false, true);
        emit ListingBought(
            address(this),
            LilOpensea.Listing({
                tokenContract: nft,
                tokenId: nftId,
                creator: address(user),
                askPrice: 1 ether,
                expiryDate: 0 
            })
        );
        lilOpensea.buyListing{ value: 1 ether }(listingId);

        assertEq(nft.ownerOf(nftId), address(this));
        assertEq(address(this).balance, thisBalance - 1 ether);
        assertEq(address(user).balance, 1 ether);

        (, , address creator, , ) = lilOpensea.getListing(listingId);
        assertEq(creator, address(0));
    }

    function testCannotPurchaseListingWithWrongPrice() public {
        assertEq(nft.ownerOf(nftId), address(this));

        uint256 thisBalance = address(this).balance;
        nft.transferFrom(address(this), address(user), nftId);
        assertEq(nft.ownerOf(nftId), address(user));

        hevm.prank(address(user));
        uint256 listingId = lilOpensea.list(nft, nftId, 1 ether, 0);
        assertEq(nft.ownerOf(nftId), address(lilOpensea));
        assertEq(address(user).balance, 0);

        hevm.expectRevert(abi.encodeWithSignature('InvalidPrice()'));
        lilOpensea.buyListing{ value: 0.5 ether }(listingId);

        assertEq(nft.ownerOf(nftId), address(lilOpensea));
        assertEq(address(this).balance, thisBalance);
        assertEq(address(user).balance, 0);

        (, , address creator, , ) = lilOpensea.getListing(listingId);
        assertEq(creator, address(user));
    }

    function testCannotPurchaseExpiredListing() public {
        assertEq(nft.ownerOf(nftId), address(this));

        uint256 thisBalance = address(this).balance;
        nft.transferFrom(address(this), address(user), nftId);
        assertEq(nft.ownerOf(nftId), address(user));

        hevm.prank(address(user));
        uint256 listingId = lilOpensea.list(nft, nftId, 1 ether, testDate);
        assertEq(nft.ownerOf(nftId), address(lilOpensea));
        assertEq(address(user).balance, 0);

        hevm.warp(testDate + 10);
        hevm.expectRevert(abi.encodeWithSignature('ExpiredListing()'));
        lilOpensea.buyListing{ value: 1 ether }(listingId);

        assertEq(nft.ownerOf(nftId), address(lilOpensea));
        assertEq(address(this).balance, thisBalance);
        assertEq(address(user).balance, 0);

        (, , address creator, , ) = lilOpensea.getListing(listingId);
        assertEq(creator, address(user));
    }

    function testCannotPurchaseNonexistantListing() public {
        uint256 thisBalance = address(this).balance;

        hevm.expectRevert(abi.encodeWithSignature('ListingDoesNotExist()'));
        lilOpensea.buyListing{ value: 1 ether }(1);

        assertEq(address(this).balance, thisBalance);
    }

    function testCancelValidListing() public {
        (, , address currCreator, ,) = lilOpensea.getListing(1);
        assertEq(currCreator, address(0));
        assertEq(nft.ownerOf(nftId), address(this));

        hevm.expectEmit(false, false, false, true);
        emit NewListing(
            LilOpensea.Listing({
                tokenContract: nft,
                tokenId: nftId,
                creator: address(this),
                askPrice: 1 ether,
                expiryDate: 0 
            })
        );

        uint256 listingId = lilOpensea.list(nft, nftId, 1 ether, 0);

        assertEq(nft.ownerOf(nftId), address(lilOpensea));

        hevm.expectEmit(false, false, false, true);
        emit ListingRemoved(
            LilOpensea.Listing({
                tokenContract: nft,
                tokenId: nftId,
                creator: address(this),
                askPrice: 1 ether,
                expiryDate: 0 
            })
        );
        lilOpensea.cancelListing(listingId);

        assertEq(nft.ownerOf(nftId), address(this));

        ( , , address creator, ,) = lilOpensea.getListing(listingId);
        assertEq(creator, address(0));      
    }

    function testCannotCancelUnownedListing() public {
        (, , address currCreator, ,) = lilOpensea.getListing(1);
        assertEq(currCreator, address(0));
        assertEq(nft.ownerOf(nftId), address(this));

        hevm.expectEmit(false, false, false, true);
        emit NewListing(
            LilOpensea.Listing({
                tokenContract: nft,
                tokenId: nftId,
                creator: address(this),
                askPrice: 1 ether,
                expiryDate: 0 
            })
        );

        uint256 listingId = lilOpensea.list(nft, nftId, 1 ether, 0);

        assertEq(nft.ownerOf(nftId), address(lilOpensea));

        hevm.prank(address(user));
        hevm.expectRevert((abi.encodeWithSignature('Unauthorized()')));
        lilOpensea.cancelListing(listingId);

        assertEq(nft.ownerOf(nftId), address(lilOpensea));

        (
            ERC721 tokenContract,
            uint256 tokenId,
            address creator,
            uint256 askPrice,
            uint256 expiryDate
        ) = lilOpensea.getListing(listingId);
        assertEq(address(tokenContract), address(nft));
        assertEq(tokenId, nftId);
        assertEq(creator, address(this));
        assertEq(askPrice, 1 ether);
        assertEq(expiryDate, 0);
    }

    function testCannotCancelNoneExistantListing() public {
        hevm.expectRevert((abi.encodeWithSignature('ListingDoesNotExist()')));
        lilOpensea.cancelListing(1);
    }
}
