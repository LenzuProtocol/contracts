// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title TokosLending
 * @notice Simplified lending protocol for yield generation on Somnia testnet
 * @dev Supports deposit, withdrawal, and APY calculation for multiple tokens
 * @author Somnia Hackathon Team
 */
contract TokosLending is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct UserDeposit {
        uint256 amount;
        uint256 shares;
        uint256 lastUpdateTime;
        uint256 accruedInterest;
    }

    struct PoolInfo {
        uint256 totalDeposits;
        uint256 totalShares;
        uint256 baseAPY;
        uint256 utilizationRate;
        bool isActive;
    }

    mapping(address => PoolInfo) public pools;
    mapping(address => mapping(address => UserDeposit)) public userDeposits;

    address[] public supportedTokens;

    uint256 public constant UTILIZATION_MULTIPLIER = 200;
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    event Deposited(address indexed user, address indexed token, uint256 amount, uint256 shares);
    event Withdrawn(address indexed user, address indexed token, uint256 amount, uint256 shares);
    event InterestAccrued(address indexed user, address indexed token, uint256 interest);
    event PoolAdded(address indexed token, uint256 baseAPY);
    event APYUpdated(address indexed token, uint256 newAPY);

    error PoolNotActive();
    error InsufficientBalance();
    error InvalidAmount();
    error TokenNotSupported();
    error PoolAlreadyExists();
    error NoDeposit();

    constructor(address initialOwner) Ownable(initialOwner) {}

    /**
     * @notice Adds a new lending pool for a token
     * @param token Token address
     * @param baseAPY Base APY in basis points (e.g., 500 = 5%)
     */
    function addPool(address token, uint256 baseAPY) external onlyOwner {
        if (pools[token].isActive) {
            revert PoolAlreadyExists();
        }

        pools[token] =
            PoolInfo({totalDeposits: 0, totalShares: 0, baseAPY: baseAPY, utilizationRate: 0, isActive: true});

        supportedTokens.push(token);

        emit PoolAdded(token, baseAPY);
    }

    /**
     * @notice Updates the base APY for a pool
     * @param token Token address
     * @param newAPY New base APY in basis points
     */
    function updateAPY(address token, uint256 newAPY) external onlyOwner {
        if (!pools[token].isActive) {
            revert PoolNotActive();
        }
        pools[token].baseAPY = newAPY;
        emit APYUpdated(token, newAPY);
    }

    /**
     * @notice Deposits tokens into the lending pool
     * @param token Token address to deposit
     * @param amount Amount to deposit
     */
    function deposit(address token, uint256 amount) external nonReentrant {
        if (!pools[token].isActive) {
            revert PoolNotActive();
        }
        if (amount == 0) {
            revert InvalidAmount();
        }

        PoolInfo storage pool = pools[token];
        UserDeposit storage userDeposit = userDeposits[msg.sender][token];

        if (userDeposit.amount > 0) {
            _accrueInterest(msg.sender, token);
        }

        uint256 shares;
        if (pool.totalShares == 0) {
            shares = amount;
        } else {
            shares = (amount * pool.totalShares) / pool.totalDeposits;
        }

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        userDeposit.amount += amount;
        userDeposit.shares += shares;
        userDeposit.lastUpdateTime = block.timestamp;

        pool.totalDeposits += amount;
        pool.totalShares += shares;

        emit Deposited(msg.sender, token, amount, shares);
    }

    /**
     * @notice Withdraws tokens from the lending pool
     * @param token Token address to withdraw
     * @param amount Amount to withdraw (0 = withdraw all)
     */
    function withdraw(address token, uint256 amount) external nonReentrant {
        if (!pools[token].isActive) {
            revert PoolNotActive();
        }

        UserDeposit storage userDeposit = userDeposits[msg.sender][token];
        if (userDeposit.amount == 0) {
            revert NoDeposit();
        }

        _accrueInterest(msg.sender, token);

        uint256 withdrawAmount = amount == 0 ? userDeposit.amount : amount;

        if (withdrawAmount > userDeposit.amount) {
            revert InsufficientBalance();
        }

        PoolInfo storage pool = pools[token];

        uint256 sharesToBurn = (withdrawAmount * userDeposit.shares) / userDeposit.amount;

        userDeposit.amount -= withdrawAmount;
        userDeposit.shares -= sharesToBurn;
        userDeposit.lastUpdateTime = block.timestamp;

        pool.totalDeposits -= withdrawAmount;
        pool.totalShares -= sharesToBurn;

        IERC20(token).safeTransfer(msg.sender, withdrawAmount);

        emit Withdrawn(msg.sender, token, withdrawAmount, sharesToBurn);
    }

    /**
     * @notice Claims accrued interest without withdrawing principal
     * @param token Token address
     */
    function claimInterest(address token) external nonReentrant {
        UserDeposit storage userDeposit = userDeposits[msg.sender][token];
        if (userDeposit.amount == 0) {
            revert NoDeposit();
        }

        _accrueInterest(msg.sender, token);

        uint256 interest = userDeposit.accruedInterest;
        if (interest > 0) {
            userDeposit.accruedInterest = 0;
            IERC20(token).safeTransfer(msg.sender, interest);
        }
    }

    /**
     * @dev Accrues interest for a user's deposit
     * @param user User address
     * @param token Token address
     */
    function _accrueInterest(address user, address token) internal {
        UserDeposit storage userDeposit = userDeposits[user][token];

        if (userDeposit.amount == 0) return;

        uint256 timeElapsed = block.timestamp - userDeposit.lastUpdateTime;
        if (timeElapsed == 0) return;

        uint256 currentAPY = getLendingAPY(token);

        uint256 interest = (userDeposit.amount * currentAPY * timeElapsed) / (10000 * SECONDS_PER_YEAR);

        userDeposit.accruedInterest += interest;
        userDeposit.amount += interest;
        userDeposit.lastUpdateTime = block.timestamp;

        pools[token].totalDeposits += interest;

        emit InterestAccrued(user, token, interest);
    }

    /**
     * @notice Gets the current lending APY for a token
     * @param token Token address
     * @return apy Current APY in basis points
     */
    function getLendingAPY(address token) public view returns (uint256 apy) {
        PoolInfo memory pool = pools[token];
        if (!pool.isActive) return 0;

        uint256 utilizationBonus = (pool.utilizationRate * UTILIZATION_MULTIPLIER) / 10000;
        apy = pool.baseAPY + (pool.baseAPY * utilizationBonus) / 10000;
    }

    /**
     * @notice Gets the health factor of a user (always 100% for lending-only)
     * @dev In a full lending protocol with borrowing, this would be collateral/debt
     * @param user User address
     * @return healthFactor Health factor (1e18 = 100%)
     */
    function getHealthFactor(address user) external pure returns (uint256 healthFactor) {
        user;
        return 1e18;
    }

    /**
     * @notice Gets the deposited balance of a user for a specific token
     * @param user User address
     * @param token Token address
     * @return balance Deposited amount (including accrued interest)
     */
    function balanceOf(address user, address token) external view returns (uint256 balance) {
        UserDeposit memory userDeposit = userDeposits[user][token];

        if (userDeposit.amount == 0) return 0;

        uint256 timeElapsed = block.timestamp - userDeposit.lastUpdateTime;
        uint256 currentAPY = getLendingAPY(token);

        uint256 pendingInterest = (userDeposit.amount * currentAPY * timeElapsed) / (10000 * SECONDS_PER_YEAR);

        return userDeposit.amount + pendingInterest;
    }

    /**
     * @notice Gets total liquidity available for a token
     * @param token Token address
     * @return liquidity Available liquidity
     */
    function getAvailableLiquidity(address token) external view returns (uint256 liquidity) {
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * @notice Gets pool information for a token
     * @param token Token address
     * @return totalDeposits Total deposits in pool
     * @return totalShares Total shares issued
     * @return baseAPY Base APY
     * @return utilizationRate Utilization rate
     * @return isActive Pool active status
     */
    function getPoolInfo(address token)
        external
        view
        returns (uint256 totalDeposits, uint256 totalShares, uint256 baseAPY, uint256 utilizationRate, bool isActive)
    {
        PoolInfo memory pool = pools[token];
        return (pool.totalDeposits, pool.totalShares, pool.baseAPY, pool.utilizationRate, pool.isActive);
    }

    /**
     * @notice Gets user deposit information
     * @param user User address
     * @param token Token address
     * @return amount Deposited amount
     * @return shares Shares owned
     * @return lastUpdateTime Last update timestamp
     * @return accruedInterest Accrued interest
     */
    function getUserDeposit(address user, address token)
        external
        view
        returns (uint256 amount, uint256 shares, uint256 lastUpdateTime, uint256 accruedInterest)
    {
        UserDeposit memory userDeposit = userDeposits[user][token];
        return (userDeposit.amount, userDeposit.shares, userDeposit.lastUpdateTime, userDeposit.accruedInterest);
    }

    /**
     * @notice Gets list of all supported tokens
     * @return tokens Array of supported token addresses
     */
    function getSupportedTokens() external view returns (address[] memory tokens) {
        return supportedTokens;
    }

    /**
     * @notice Gets total value locked across all pools
     * @return tvl Total value locked (in token units)
     */
    function getTotalValueLocked() external view returns (uint256 tvl) {
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            tvl += pools[supportedTokens[i]].totalDeposits;
        }
    }
}
