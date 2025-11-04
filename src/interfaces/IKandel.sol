// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IKandel
 * @notice Interface for interacting with deployed Kandel market-making instances
 * @dev Used to retract liquidity from active strategies
 */
interface IKandel {
    /**
     * @notice Retracts all liquidity from the Kandel order book
     * @dev Removes all active orders and returns funds to the vault
     */
    function retract() external;

    /**
     * @notice Withdraws tokens from the Kandel instance
     * @param token Token address to withdraw
     * @param amount Amount to withdraw
     */
    function withdraw(address token, uint256 amount) external;

    /**
     * @notice Gets the vault associated with this Kandel instance
     * @return vault The vault address
     */
    function vault() external view returns (address vault);

    /**
     * @notice Gets current APY for this Kandel strategy
     * @return apy Annual Percentage Yield in basis points (e.g., 1200 = 12%)
     */
    function getAPY() external view returns (uint256 apy);

    /**
     * @notice Gets current performance metrics
     * @return active Whether strategy is active
     * @return currentYield Current yield percentage (basis points)
     * @return totalValue Estimated total value in strategy
     */
    function getPerformance() external view returns (bool active, uint256 currentYield, uint256 totalValue);
}
