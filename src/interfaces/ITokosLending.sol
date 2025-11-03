// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ITokosLending
 * @notice Interface for Tokos lending protocol
 * @dev Hypothetical lending protocol for yield generation
 */
interface ITokosLending {
    /**
     * @notice Deposits tokens into the lending pool
     * @param token Token address to deposit
     * @param amount Amount to deposit
     */
    function deposit(address token, uint256 amount) external;

    /**
     * @notice Withdraws tokens from the lending pool
     * @param token Token address to withdraw
     * @param amount Amount to withdraw
     */
    function withdraw(address token, uint256 amount) external;

    /**
     * @notice Gets the current lending APY for a token
     * @param token Token address
     * @return apy Annual Percentage Yield in basis points (e.g., 500 = 5%)
     */
    function getLendingAPY(address token) external view returns (uint256 apy);

    /**
     * @notice Gets the health factor of a user's position
     * @param user User address
     * @return healthFactor Health factor (1e18 = 100%, below 1e18 = at risk)
     */
    function getHealthFactor(address user) external view returns (uint256 healthFactor);

    /**
     * @notice Gets the deposited balance of a user for a specific token
     * @param user User address
     * @param token Token address
     * @return balance Deposited amount
     */
    function balanceOf(address user, address token) external view returns (uint256 balance);

    /**
     * @notice Gets total liquidity available for a token
     * @param token Token address
     * @return liquidity Available liquidity
     */
    function getAvailableLiquidity(address token) external view returns (uint256 liquidity);
}
