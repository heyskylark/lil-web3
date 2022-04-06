// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.13;

import 'solmate/tokens/ERC721.sol';
import 'solmate/utils/SafeTransferLib.sol';

/// @title lil opensea
/// @author Brandon Feist
/// @notice A simple and condensed version of OpenSea
contract LilOpensea {
    /// ERRORS ///

    /// @notice Thrown when trying to cancel a listing that is owned by someone else
    error Unauthorized();

    /// @notice Thrown when a listing is not found
    error ListingDoesNotExist();

    /// @notice Thrown when the payable price does not match the listing price
    error InvalidPrice();

    /// @notice Thrown when a listing is expired
    error ExpiredListing();

    /// EVENTS ///

    /// @notice Event that is emitted when a listing is posted
    /// @param listing The listing that was posted
    event NewListing(Listing listing);

    /// @notice Event that is emitted when a listing is removed
    /// @param listing The listing that was removed
    event ListingRemoved(Listing listing);

    /// @notice Event that is emitted when a listing is purchased
    /// @param buyer The address of the purchaser of the listing
    /// @param listing The listing that was purchased
    event ListingBought(address indexed buyer, Listing listing);

    /// @notice Used to keep track of what the next sale is
    /// @dev Init at 1 since 0 is a default value for un-initialized uint256
    uint256 internal saleCounter = 1;

    // TODO: Look into data_sign and just giving the signed contract to purchase
        // Not sure if that's only for bids
    /// @dev A struct to resemble a listing
    /// @param tokenContract The address to the ERC721 contract
    /// @param tokenId The id for the ERC721 token
    /// @param creator The address of the listing creator
    /// @param askPrice The asking price for the listing
    /// @param expiryDate The expiration date for the listing
    struct Listing {
        ERC721 tokenContract;
        uint256 tokenId;
        address creator;
        uint256 askPrice;
        uint256 expiryDate;
    }

    /// @notice Stores all listings (active/inactive)
    mapping(uint256 => Listing) public getListing;

    /// @notice Checks if the msg.sender is the owner of the listing
    /// @param listingId The id of the listing to check ownership of
    modifier owner(uint256 listingId) {
        Listing memory listing = getListing[listingId];
        if (listing.creator == address(0)) revert ListingDoesNotExist();
        if (listing.creator != msg.sender) revert Unauthorized();

        _;
    }

    /// @notice Used to list a sale for an ERC721 token
    /// @param tokenContract The contract address for your ERC721 token
    /// @param tokenId The id of the ERC721 token
    /// @param askPrice asking price for the sale
    /// @param expiryDate The expiration date in seconds of the listing (0 if don't expire)
    function list(
        ERC721 tokenContract,
        uint256 tokenId,
        uint256 askPrice,
        uint256 expiryDate
    ) public payable returns (uint256) {
        Listing memory listing = Listing({
            tokenContract: tokenContract,
            tokenId: tokenId,
            creator: msg.sender,
            askPrice: askPrice,
            expiryDate: expiryDate
        });

        getListing[saleCounter] = listing;

        emit NewListing(listing);

        listing.tokenContract.transferFrom(msg.sender, address(this), tokenId);
        
        return saleCounter++;
    }

    /// @notice Used to buy a valid listing
    /// @param listingId The id of the valid listing
    function buyListing(uint256 listingId) public payable {
        Listing memory listing = getListing[listingId];

        if (listing.creator == address(0)) revert ListingDoesNotExist();
        if (msg.value != listing.askPrice) revert InvalidPrice();
        if (listing.expiryDate != 0 && block.timestamp > listing.expiryDate) revert ExpiredListing();

        delete getListing[listingId];

        emit ListingBought(msg.sender, listing);

        SafeTransferLib.safeTransferETH(listing.creator, listing.askPrice);
        listing.tokenContract.transferFrom(address(this), msg.sender, listing.tokenId);
    }

    /// @notice Used to cancel an active listing
    /// @param listingId The id of the active listing
    function cancelListing(uint256 listingId) public payable owner(listingId) {
        Listing memory listing = getListing[listingId];

        delete getListing[listingId];

        emit ListingRemoved(listing);

        listing.tokenContract.transferFrom(address(this), msg.sender, listing.tokenId);
    }
}
