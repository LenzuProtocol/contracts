// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IKandelSeeder.sol";
import "../interfaces/IKandel.sol";

/**
 * @title MockKandelSeeder
 * @notice Mock implementation of Kandel Seeder for testing purposes
 * @dev Simulates the behavior of the real Elix Kandel seeder without external dependencies
 */
contract MockKandelSeeder is IKandelSeeder {
    using SafeERC20 for IERC20;

    event KandelSeeded(
        address indexed vault, address indexed kandel, uint256 baseAmount, uint256 quoteAmount, KandelParams params
    );

    mapping(address => address[]) public vaultToKandels;
    address[] public allKandels;

    /**
     * @notice Seeds a new mock Kandel market-making strategy
     * @param vault The vault that will hold the funds
     * @param baseAmount Amount of base tokens to provision
     * @param quoteAmount Amount of quote tokens to provision
     * @param params Strategy parameters
     * @return kandel Address of the deployed mock Kandel instance
     */
    function seed(address vault, uint256 baseAmount, uint256 quoteAmount, KandelParams calldata params)
        external
        returns (address kandel)
    {
        // Deploy a new mock Kandel instance
        MockKandel newKandel = new MockKandel(vault, params.base, params.quote, params.spread, params.pricePoints);

        kandel = address(newKandel);

        // Transfer tokens to the Kandel instance (simulate provisioning)
        if (baseAmount > 0) {
            IERC20(params.base).safeTransferFrom(msg.sender, kandel, baseAmount);
        }
        if (quoteAmount > 0) {
            IERC20(params.quote).safeTransferFrom(msg.sender, kandel, quoteAmount);
        }

        // Initialize the Kandel strategy
        newKandel.initialize(baseAmount, quoteAmount);

        // Record the new Kandel
        vaultToKandels[vault].push(kandel);
        allKandels.push(kandel);

        emit KandelSeeded(vault, kandel, baseAmount, quoteAmount, params);
    }

    /**
     * @notice Gets all Kandel instances for a vault
     * @param vault The vault address
     * @return kandels Array of Kandel addresses
     */
    function getKandelsForVault(address vault) external view returns (address[] memory) {
        return vaultToKandels[vault];
    }

    /**
     * @notice Gets total number of Kandel instances created
     * @return count Total count
     */
    function getKandelCount() external view returns (uint256) {
        return allKandels.length;
    }
}

/**
 * @title MockKandel
 * @notice Mock implementation of a Kandel market-making strategy
 * @dev Simulates market-making behavior for testing
 */
contract MockKandel is IKandel {
    using SafeERC20 for IERC20;

    address public immutable vault;
    address public immutable baseToken;
    address public immutable quoteToken;
    uint256 public immutable spread;
    uint256 public immutable pricePoints;

    uint256 public baseAmount;
    uint256 public quoteAmount;
    bool public isActive;
    uint256 public mockYield;

    event KandelInitialized(uint256 baseAmount, uint256 quoteAmount);
    event LiquidityRetracted(uint256 baseReturned, uint256 quoteReturned);
    event YieldGenerated(uint256 baseYield, uint256 quoteYield);

    constructor(address _vault, address _baseToken, address _quoteToken, uint256 _spread, uint256 _pricePoints) {
        vault = _vault;
        baseToken = _baseToken;
        quoteToken = _quoteToken;
        spread = _spread;
        pricePoints = _pricePoints;
    }

    /**
     * @notice Initializes the Kandel strategy with initial liquidity
     * @param _baseAmount Initial base token amount
     * @param _quoteAmount Initial quote token amount
     */
    function initialize(uint256 _baseAmount, uint256 _quoteAmount) external {
        require(!isActive, "Already initialized");

        baseAmount = _baseAmount;
        quoteAmount = _quoteAmount;
        isActive = true;

        // Simulate some initial yield generation
        _generateMockYield();

        emit KandelInitialized(_baseAmount, _quoteAmount);
    }

    /**
     * @notice Retracts all liquidity from the mock Kandel strategy
     * @dev Simulates yield generation and returns funds plus profit to vault
     */
    function retract() external {
        require(isActive, "Not active");

        // Generate final yield before retracting
        _generateMockYield();

        uint256 totalBase = baseAmount + (baseAmount * mockYield / 10000); // Mock profit
        uint256 totalQuote = quoteAmount + (quoteAmount * mockYield / 10000);

        // Transfer tokens back to vault
        if (totalBase > 0) {
            uint256 actualBase = IERC20(baseToken).balanceOf(address(this));
            uint256 transferBase = actualBase > totalBase ? totalBase : actualBase;
            IERC20(baseToken).safeTransfer(vault, transferBase);
        }

        if (totalQuote > 0) {
            uint256 actualQuote = IERC20(quoteToken).balanceOf(address(this));
            uint256 transferQuote = actualQuote > totalQuote ? totalQuote : actualQuote;
            IERC20(quoteToken).safeTransfer(vault, transferQuote);
        }

        isActive = false;
        emit LiquidityRetracted(totalBase, totalQuote);
    }

    /**
     * @notice Withdraws specific amount of tokens (for testing)
     * @param token Token address to withdraw
     * @param amount Amount to withdraw
     */
    function withdraw(address token, uint256 amount) external {
        require(token == baseToken || token == quoteToken, "Invalid token");
        IERC20(token).safeTransfer(vault, amount);
    }

    /**
     * @notice Generates mock yield based on time and strategy parameters
     * @dev Simulates realistic market-making returns
     */
    function _generateMockYield() internal {
        if (!isActive) return;

        // Mock yield calculation: 0.1% to 1% based on spread and time
        // Higher spread = higher potential yield
        uint256 baseYield = (spread * block.timestamp % 100) + 10; // 0.1% to 1%
        mockYield = baseYield > 100 ? 100 : baseYield; // Cap at 1%

        emit YieldGenerated(baseAmount * mockYield / 10000, quoteAmount * mockYield / 10000);
    }

    /**
     * @notice Gets current mock performance metrics
     * @return active Whether strategy is active
     * @return currentYield Current yield percentage (basis points)
     * @return totalValue Estimated total value in strategy
     */
    function getPerformance() external view returns (bool active, uint256 currentYield, uint256 totalValue) {
        active = isActive;
        currentYield = mockYield;
        totalValue = baseAmount + quoteAmount + (baseAmount * mockYield / 10000) + (quoteAmount * mockYield / 10000);
    }

    /**
     * @notice Gets current APY for this Kandel strategy
     * @return apy Annual Percentage Yield in basis points (e.g., 1200 = 12%)
     */
    function getAPY() external view returns (uint256 apy) {
        if (!isActive) return 0;
        
        // Mock APY calculation based on spread and market conditions
        // Market making typically yields 2-15% annually
        uint256 baseAPY = 800; // 8% base APY
        uint256 spreadBonus = spread * 2; // Higher spread = higher APY
        uint256 timeBonus = (block.timestamp % 500); // Time-based variation
        
        apy = baseAPY + spreadBonus + timeBonus;
        // Cap between 3% and 20%
        if (apy < 300) apy = 300;
        if (apy > 2000) apy = 2000;
    }

    /**
     * @notice Emergency function to recover tokens (only callable by vault)
     * @param token Token to recover
     */
    function emergencyWithdraw(address token) external {
        require(msg.sender == vault, "Only vault");
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).safeTransfer(vault, balance);
        }
    }
}
