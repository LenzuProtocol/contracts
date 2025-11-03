// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IVault
 * @notice Interface for Elix (Mangrove) Vault instances
 * @dev Vaults hold tokens and manage approvals for strategies
 */
interface IVault {
    /**
     * @notice Withdraws tokens from the vault to the owner
     * @param token Token address to withdraw
     * @param amount Amount to withdraw
     */
    function withdraw(address token, uint256 amount) external;

    /**
     * @notice Approves a spender to use vault tokens
     * @param token Token to approve
     * @param spender Address to approve
     * @param amount Amount to approve
     */
    function approve(address token, address spender, uint256 amount) external;

    /**
     * @notice Deposits tokens into the vault
     * @param token Token address to deposit
     * @param amount Amount to deposit
     */
    function deposit(address token, uint256 amount) external;

    /**
     * @notice Gets the token balance held by the vault
     * @param token Token address
     * @return balance Token balance
     */
    function balanceOf(address token) external view returns (uint256 balance);
}
