// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IVaultFactory
 * @notice Interface for Elix (Mangrove) Vault Factory
 * @dev Deployed at 0xD7c89B9AC4f09131a962BB9527CcF26cB68cF70c on Somnia testnet
 */
interface IVaultFactory {
    /**
     * @notice Creates a new vault for the specified owner
     * @param owner Address that will own the vault
     * @return vault Address of the newly created vault
     */
    function createVault(address owner) external returns (address vault);

    /**
     * @notice Gets the vault address for a specific owner
     * @param owner The owner address
     * @return vault The vault address (address(0) if none exists)
     */
    function getVault(address owner) external view returns (address vault);
}
