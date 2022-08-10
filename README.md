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
> Fractionalization but smol

A distilled version of NFT fractionalization. This contract allows users to fractionalize their NFT and keeps track of each fractionalized NFT in vaults. This contract consists of two main methods `split(ERC721 nftContract, uint256 tokenId, uint256 supply, string name, string symbol)` and `join(uint256 id)` (which requires all fractionalized ERC20 tokens to trigger).

[Contract Source](./src/LilFractional.sol) • [Contract Testing](./src/test/LilFractional.t.sol)

# lil juicebox
> You Lil Juicebox funding contract

Juicebox in its most pure form. This contract allows users to contribute to a fund with `contribute() payable` (in return they will recieve special Juicebox ERC20 tokens), ask for an ETH refund with `refund(uint256 amount)`, allow the owner to withdraw ETH with `withdraw()`, renounce ownership with `renounce()`, and update the Juicebox funding state with `updateState(State state)`.

This contract could be extended further to keep track of different funds that are going on, instead of having one fund for one contract. As well as modifying the type and amount of ERC20 tokens that are given after contribution.

[Contract Source](./src/LilJuicebox.sol) • [Contract Testing](./src/test/LilJuicebox.t.sol)

# lil flashloan
> Lil Flashloans for Lil Arbitrage

lil Flashloan is a very simple flash loan implementation based off the [EIP-3156 Standard](https://eips.ethereum.org/EIPS/eip-3156). This contract allows the owner to set fees `setFee(ERC20 token, uint256 fee)`, withdraw funds with `withdraw(ERC20 token, uint256 amount)`, and allow any borrower to deploy their own contract under the `IERC3156FlashBorrower` interface to be used as a callback in the function `flashLoan(IERC3156FlashBorrower receiver, ERC20 token, uint256 amount, bytes calldata data)`.

The borrower contracts a VERY simple, mainly used to display what happens when a contract returns borrowed funds after use and when a contract tries to keep the transfered funds.

[Contract Source](./src/LilFlashloan.sol) • [Contract Testing](./src/test/LilFlashloan.t.sol)

# lil gonsis
>\<under-construction>

# lil superfluid
>\<under-construction>

# lil sudoswap
>\<under-construction>

# License
This project is open-sourced software licensed under the GNU Affero GPL v3.0 license. See the License file for more information.