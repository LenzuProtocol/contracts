// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IKandelSeeder.sol";
import "./interfaces/IKandel.sol";
import "./interfaces/IVaultFactory.sol";
import "./interfaces/ITokosLending.sol";

/**
 * @title AgentManager
 * @notice Allows users to deposit tokens and agent to rebalance automatically
 * @dev Supports user deposits with agent-controlled rebalancing
 */
contract AgentManager is Ownable {
    address public WETH;
    address public USDC;
    address public vault;
    address public kandelInstance;
    bool public isInElix;
    bool public isInTokos;

    // Configurable addresses
    address public kandelSeeder;
    address public vaultFactory;
    address public tokosLending;

    // Agent address for automated rebalancing
    address public agent;

    // User deposit tracking
    mapping(address => uint256) public userWethDeposits;
    mapping(address => uint256) public userUsdcDeposits;
    uint256 public totalWethDeposits;
    uint256 public totalUsdcDeposits;

    event UserDeposit(address indexed user, address indexed token, uint256 amount);
    event UserWithdraw(address indexed user, address indexed token, uint256 amount);
    event ProvisionedToElix(address indexed kandel, uint256 wethAmount, uint256 usdcAmount);
    event ProvisionedToTokos(uint256 wethAmount, uint256 usdcAmount);
    event EmergencyWithdrawal(uint256 wethAmount, uint256 usdcAmount);
    event VaultCreated(address indexed vault);
    event AssetsSet(address weth, address usdc);
    event AddressesUpdated(address kandelSeeder, address vaultFactory, address tokosLending);
    event AgentSet(address indexed agent);

    error AssetsNotSet();
    error InvalidAddress();
    error InsufficientBalance();
    error ContractNotSet(string contractName);
    error UnauthorizedAgent();
    error InsufficientUserBalance();

    modifier onlyOwnerOrAgent() {
        require(msg.sender == owner() || msg.sender == agent, "UnauthorizedAgent");
        _;
    }

    constructor(address initialOwner) Ownable(initialOwner) {}

    // ===========================
    // CONFIGURATION FUNCTIONS
    // ===========================

    function setAgent(address _agent) external onlyOwner {
        agent = _agent;
        emit AgentSet(_agent);
    }

    function setProtocolAddresses(address _kandelSeeder, address _vaultFactory, address _tokosLending)
        external
        onlyOwner
    {
        kandelSeeder = _kandelSeeder;
        vaultFactory = _vaultFactory;
        tokosLending = _tokosLending;
        emit AddressesUpdated(_kandelSeeder, _vaultFactory, _tokosLending);
    }

    function setAssets(address _weth, address _usdc) external onlyOwner {
        if (_weth == address(0) || _usdc == address(0)) {
            revert InvalidAddress();
        }
        WETH = _weth;
        USDC = _usdc;
        emit AssetsSet(_weth, _usdc);
    }

    // ===========================
    // USER DEPOSIT/WITHDRAW FUNCTIONS
    // ===========================

    function depositWETH(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(WETH != address(0), "WETH not set");

        IERC20(WETH).transferFrom(msg.sender, address(this), amount);

        userWethDeposits[msg.sender] += amount;
        totalWethDeposits += amount;

        emit UserDeposit(msg.sender, WETH, amount);
    }

    function depositUSDC(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(USDC != address(0), "USDC not set");

        IERC20(USDC).transferFrom(msg.sender, address(this), amount);

        userUsdcDeposits[msg.sender] += amount;
        totalUsdcDeposits += amount;

        emit UserDeposit(msg.sender, USDC, amount);
    }

    function withdrawWETH(uint256 amount) external {
        require(amount <= userWethDeposits[msg.sender], "Insufficient user balance");
        require(!isInElix && !isInTokos, "Cannot withdraw during active strategy");

        userWethDeposits[msg.sender] -= amount;
        totalWethDeposits -= amount;

        IERC20(WETH).transfer(msg.sender, amount);

        emit UserWithdraw(msg.sender, WETH, amount);
    }

    function withdrawUSDC(uint256 amount) external {
        require(amount <= userUsdcDeposits[msg.sender], "Insufficient user balance");
        require(!isInElix && !isInTokos, "Cannot withdraw during active strategy");

        userUsdcDeposits[msg.sender] -= amount;
        totalUsdcDeposits -= amount;

        IERC20(USDC).transfer(msg.sender, amount);

        emit UserWithdraw(msg.sender, USDC, amount);
    }

    // ===========================
    // AGENT REBALANCING FUNCTIONS
    // ===========================

    function provisionToElix(uint256 wethAmount, uint256 usdcAmount, KandelParams calldata params)
        external
        onlyOwnerOrAgent
    {
        if (WETH == address(0) || USDC == address(0)) revert AssetsNotSet();
        if (kandelSeeder == address(0)) revert ContractNotSet("KandelSeeder");

        // Withdraw from Tokos if active
        if (isInTokos) {
            _withdrawFromTokos();
        }

        // Create vault if needed
        if (vault == address(0)) {
            if (vaultFactory == address(0)) revert ContractNotSet("VaultFactory");
            vault = IVaultFactory(vaultFactory).createVault(address(this));
            emit VaultCreated(vault);
        }

        // Check balances
        if (IERC20(WETH).balanceOf(address(this)) < wethAmount) revert InsufficientBalance();
        if (IERC20(USDC).balanceOf(address(this)) < usdcAmount) revert InsufficientBalance();

        // Approve and seed
        IERC20(WETH).approve(kandelSeeder, wethAmount);
        IERC20(USDC).approve(kandelSeeder, usdcAmount);
        kandelInstance = IKandelSeeder(kandelSeeder).seed(vault, wethAmount, usdcAmount, params);

        isInElix = true;
        isInTokos = false;
        emit ProvisionedToElix(kandelInstance, wethAmount, usdcAmount);
    }

    function provisionToTokos(uint256 wethAmount, uint256 usdcAmount) external onlyOwnerOrAgent {
        if (WETH == address(0) || USDC == address(0)) revert AssetsNotSet();
        if (tokosLending == address(0)) revert ContractNotSet("TokosLending");

        // Retract from Elix if active
        if (isInElix && kandelInstance != address(0)) {
            IKandel(kandelInstance).retract();
        }

        // Check balances
        if (IERC20(WETH).balanceOf(address(this)) < wethAmount) revert InsufficientBalance();
        if (IERC20(USDC).balanceOf(address(this)) < usdcAmount) revert InsufficientBalance();

        // Deposit to Tokos
        if (wethAmount > 0) {
            IERC20(WETH).approve(tokosLending, wethAmount);
            ITokosLending(tokosLending).deposit(WETH, wethAmount);
        }
        if (usdcAmount > 0) {
            IERC20(USDC).approve(tokosLending, usdcAmount);
            ITokosLending(tokosLending).deposit(USDC, usdcAmount);
        }

        isInTokos = true;
        isInElix = false;
        emit ProvisionedToTokos(wethAmount, usdcAmount);
    }

    function emergencyWithdraw() external onlyOwnerOrAgent {
        if (isInElix && kandelInstance != address(0)) {
            IKandel(kandelInstance).retract();
        }
        if (isInTokos) {
            _withdrawFromTokos();
        }
        isInElix = false;
        isInTokos = false;
        emit EmergencyWithdrawal(IERC20(WETH).balanceOf(address(this)), IERC20(USDC).balanceOf(address(this)));
    }

    function _withdrawFromTokos() internal {
        if (tokosLending != address(0)) {
            // Check if we have deposits before withdrawing to avoid NoDeposit() error
            try ITokosLending(tokosLending).balanceOf(address(this), WETH) returns (uint256 wethBalance) {
                if (wethBalance > 0) {
                    try ITokosLending(tokosLending).withdraw(WETH, 0) {
                        // Withdrawal successful
                    } catch {
                        // If withdrawal fails (e.g., insufficient balance), skip it
                    }
                }
            } catch {
                // If balanceOf call fails, skip WETH withdrawal
            }

            try ITokosLending(tokosLending).balanceOf(address(this), USDC) returns (uint256 usdcBalance) {
                if (usdcBalance > 0) {
                    try ITokosLending(tokosLending).withdraw(USDC, 0) {
                        // Withdrawal successful
                    } catch {
                        // If withdrawal fails (e.g., insufficient balance), skip it
                    }
                }
            } catch {
                // If balanceOf call fails, skip USDC withdrawal
            }
        }
    }

    // ===========================
    // VIEW FUNCTIONS
    // ===========================

    function getUserBalance(address user) external view returns (uint256 wethBalance, uint256 usdcBalance) {
        return (userWethDeposits[user], userUsdcDeposits[user]);
    }

    function getContractBalances() external view returns (uint256 wethBalance, uint256 usdcBalance) {
        wethBalance = IERC20(WETH).balanceOf(address(this));
        usdcBalance = IERC20(USDC).balanceOf(address(this));
    }

    function getPositionSummary()
        external
        view
        returns (
            uint256 contractWeth,
            uint256 contractUsdc,
            uint256 vaultWeth,
            uint256 vaultUsdc,
            bool inElix,
            bool inTokos
        )
    {
        contractWeth = IERC20(WETH).balanceOf(address(this));
        contractUsdc = IERC20(USDC).balanceOf(address(this));

        if (vault != address(0)) {
            vaultWeth = IERC20(WETH).balanceOf(vault);
            vaultUsdc = IERC20(USDC).balanceOf(vault);
        }

        inElix = isInElix;
        inTokos = isInTokos;
    }

    function getProtocolAddresses() external view returns (address, address, address) {
        return (kandelSeeder, vaultFactory, tokosLending);
    }

    function getTokosAPY(address token) external view returns (uint256 apy) {
        if (tokosLending != address(0)) {
            return ITokosLending(tokosLending).getLendingAPY(token);
        }
        return 0;
    }

    // Fallback to receive tokens
    receive() external payable {}
}
