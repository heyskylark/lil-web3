# lil-web3
Inspired by [@m1guelpf](https://twitter.com/m1guelpf) and his [lil-web3 project](https://github.com/m1guelpf/lil-web3).

lil-web3 are simplified and focused web3 protocols and apps with the explicit purpose to get a better understanding of the Web3 ecosystem.

# lil ens
> A lil registry and resolver compact into one.

lil ENS consists of three elements, a lookup map, a `register(string name)` function, and a `setOwner(string name, address addr)` transfer function.

I spent some time reading through [EIP-137](https://eips.ethereum.org/EIPS/eip-137), which explains the standard registry and resolver pattern. Since this project is lil, I will not be building out a more fleshed out registry/resolver. I do plan on doing that in the future and updating with a link that here.

For the lil project the main goal is to distil the purpose ENS into its most condensed simplest form.

[Contract Source](./src/LilENS.sol) • [Contract Testing](./src/test/LilENS.t.sol)

# lil opensea
> A lil marketplace without the fees

lil Opensea is a simple contract that holds listings and consists of three functions create a listing `list(ERC721 tokenContract, uint256 tokenId, uint256 askPrice, uint256 expiryDate)`, pruchase a listing `buyListing(uint256 listingId)`, and cancel a listing `cancelListing(uint256)`.

This contract does not include the ability to bid, it only acts a simple marketplace to put ERC721 tokens up for sale and be able to purchase said listings outright.

I did want to also add the ability to have listings expires. As of right now, after expiration the listings stay on the contract indefinitely but are then invalid. If there is a better way, feedback is always appreciated!

[Contract Source](./src/LilOpensea.sol) • [Contract Testing](./src/test/LilOpensea.t.sol)

# lil fractional
>\<under-construction>

# lil juicebox
>\<under-construction>

# lil flashloan
>\<under-construction>

# lil gonsis
>\<under-construction>

# lil superfluid
>\<under-construction>

# lil sudoswap
>\<under-construction>

# License
This project is open-sourced software licensed under the GNU Affero GPL v3.0 license. See the License file for more information.