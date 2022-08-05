// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.13;

import { ERC20 } from 'solmate/tokens/ERC20.sol';
import { ERC721 } from 'solmate/tokens/ERC721.sol';

/// @title FractionalToken
/// @author Skylark
/// @notice Extended ERC20 token to handle ERC721 fractionalizing and joining
contract FractionalToken is ERC20 {
    /// @notice Constructor for a FractionalToken ERC20 contract
    /// @param name The name of the ERC20 token
    /// @param symbol The symbol of the ERC20 token
    /// @param mintSupply The amount of ERC20 tokens to mint
    /// @param mintTo The address that will get all minted ERC20 tokens
    constructor(
        string memory name,
        string memory symbol,
        uint256 mintSupply,
        address mintTo
    ) payable ERC20(name, symbol, 18) {
        _mint(mintTo, mintSupply);
    }

    /// @notice Burns the amount given from a user and checks if the caller has access to burn the amount tokens given
    /// @param from The address of the owner of tokens to be burned
    /// @param amount The number of tokens that will be burned
    /// @dev Took this trick from Miguel's implementation, where if the allowed amount is less than the amount expected to be burn it underflows and causes a revert
    function burn(address from, uint256 amount) public payable {
        uint256 allowed = allowance[from][msg.sender];

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        _burn(from, amount);
    }
}

/// @title lil fractional
/// @author Skylark
/// @notice A simple version of a contract that fractionalizes an ERC-721 into ERC-20 tokens
contract LilFractional {
    /// ERRORS ///

    /// @notice Thrown when trying to find a vault that doesn't exist
    error VaultNotFound();

    /// @dev Strcut for the vault
    /// @param nftContract The contract of the ERC721 to be vaulted
    /// @param nftTokenId The tokenId for the ERC721 token to be vaulted
    /// @param fractionalSupply The amount of ERC20 tokens the ERC721 will be fractionalized into
    /// @param tokenContract The ERC20 token contract that is connected to the fractionalized ERC721 token
    struct Vault {
        ERC721 nftContract;
        uint256 nftTokenId;
        uint256 fractionalSupply;
        FractionalToken tokenContract;
    }

    /// @notice Event is emitted when a new fractional vault is created
    /// @param vaultId the id for the new vault that is created
    event VaultCreated(uint256 vaultId);

    /// @notice Event is emitted when a fractionalized NFT is claimed and the vault is destroyed
    /// @param vaultId the id for the vault that was destroyed during the join
    event VaultDestroyed(uint256 vaultId);

    /// @notice Next id to be used in a vault creation
    uint256 internal vaultId = 1;

    /// @notice Stores all active vaults
    mapping(uint256 => Vault) public getVault;

    /// @notice Fractionalizes a given ERC721 token into a specified amount of ERC20 tokens
    /// @param nftContract The ERC721 contract that contains the NFT token that will be fractionalized
    /// @param tokenId The tokenId for the ERC721 token that will be fractionalized
    /// @param supply The amount of ERC20 tokens that the ERC721 token will be fractionalized into
    /// @param name The name of the ERC20 tokens
    /// @param symbol The symbol of the ERC20 tokens
    function split(
        ERC721 nftContract,
        uint256 tokenId,
        uint256 supply,
        string memory name,
        string memory symbol
    ) public payable returns (uint256) {
        FractionalToken fractionalToken = new FractionalToken(name, symbol, supply, msg.sender);

        Vault memory vault = Vault({
            nftContract: nftContract,
            nftTokenId: tokenId,
            fractionalSupply: supply,
            tokenContract: fractionalToken
        });

        emit VaultCreated(vaultId);

        getVault[vaultId] = vault;

        nftContract.transferFrom(msg.sender, address(this), tokenId);

        return vaultId++;
    }

    /// @notice Caller will burn the total supply of ERC20 tokens in exchange for the ERC721 token
    /// @param id The vault that contains the ERC721 token to be claimed
    function join(uint256 id) public payable {
        Vault memory vault = getVault[id];

        if (address(vault.nftContract) == address(0)) revert VaultNotFound();

        delete getVault[id];

        emit VaultDestroyed(id);

        vault.tokenContract.burn(msg.sender, vault.fractionalSupply);

        vault.nftContract.transferFrom(address(this), msg.sender, vault.nftTokenId);
    }

    /// @dev This function ensures this contract can receive ERC721 tokens
	function onERC721Received(
		address,
		address,
		uint256,
		bytes memory
	) public payable returns (bytes4) {
		return this.onERC721Received.selector;
	}
}
