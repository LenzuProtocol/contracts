// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IKandelSeeder.sol";
import "./interfaces/IKandel.sol";
import "./interfaces/IVaultFactory.sol";
import "./interfaces/IVault.sol";
import "./interfaces/ITokosLending.sol";
import "./libraries/SomniaAddresses.sol";

contract AutonomousLiquidityManager is Ownable {
    using SafeERC20 for IERC20;

    address public WETH;
    address public USDC;
    address public vault;
    address public kandelInstance;
    bool public isInElix;
    bool public isInTokos;

    event ProvisionedToElix(address indexed kandel, uint256 wethAmount, uint256 usdcAmount);

    event ProvisionedToTokos(uint256 wethAmount, uint256 usdcAmount);
    event EmergencyWithdrawal(uint256 wethAmount, uint256 usdcAmount);
    event VaultCreated(address indexed vault);
    event AssetsSet(address weth, address usdc);
    event FundsReceived(address indexed from, uint256 amount);

    error AssetsNotSet();
    error InvalidAddress();
    error InsufficientBalance(string token, uint256 required, uint256 available);
    error TokosNotDeployed();
    error NoVaultExists();
    error NoKandelInstance();

    /**
     * @notice Initializes the contract with the owner (backend agent wallet)
     * @param initialOwner Address of the backend agent that will control this vault
     */
    constructor(address initialOwner) Ownable(initialOwner) {}

    /**
     * @notice Sets the WETH and USDC token addresses
     * @dev Must be called before any strategy operations
     * @param _weth Address of WETH token on Somnia
     * @param _usdc Address of USDC token on Somnia
     */
    function setAssets(address _weth, address _usdc) external onlyOwner {
        if (_weth == address(0) || _usdc == address(0)) {
            revert InvalidAddress();
        }
        WETH = _weth;
        USDC = _usdc;
        emit AssetsSet(_weth, _usdc);
    }

    /**
     * @notice Provisions funds to Elix (Mangrove) Kandel market-making strategy
     * @dev Automatically withdraws from Tokos if funds are there first
     * @param wethAmount Amount of WETH to provision
     * @param usdcAmount Amount of USDC to provision
     * @param params Kandel strategy parameters (spread, price points, etc.)
     */
    function provisionToElix(uint256 wethAmount, uint256 usdcAmount, KandelParams calldata params) external onlyOwner {
        if (WETH == address(0) || USDC == address(0)) {
            revert AssetsNotSet();
        }

        if (isInTokos) {
            _withdrawFromTokos();
        }

        if (vault == address(0)) {
            vault = IVaultFactory(SomniaAddresses.VAULT_FACTORY).createVault(address(this));
            emit VaultCreated(vault);
        }

        uint256 wethBalance = IERC20(WETH).balanceOf(address(this));
        uint256 usdcBalance = IERC20(USDC).balanceOf(address(this));

        if (wethBalance < wethAmount) {
            revert InsufficientBalance("WETH", wethAmount, wethBalance);
        }
        if (usdcBalance < usdcAmount) {
            revert InsufficientBalance("USDC", usdcAmount, usdcBalance);
        }

        IERC20(WETH).forceApprove(SomniaAddresses.KANDEL_SEEDER, wethAmount);
        IERC20(USDC).forceApprove(SomniaAddresses.KANDEL_SEEDER, usdcAmount);

        kandelInstance = IKandelSeeder(SomniaAddresses.KANDEL_SEEDER).seed(vault, wethAmount, usdcAmount, params);

        isInElix = true;
        isInTokos = false;

        emit ProvisionedToElix(kandelInstance, wethAmount, usdcAmount);
    }

    /**
     * @notice Provisions funds to Tokos lending protocol for yield generation
     * @dev Automatically retracts from Elix if funds are there first
     * @param wethAmount Amount of WETH to deposit
     * @param usdcAmount Amount of USDC to deposit
     */
    function provisionToTokos(uint256 wethAmount, uint256 usdcAmount) external onlyOwner {
        if (WETH == address(0) || USDC == address(0)) {
            revert AssetsNotSet();
        }
        if (SomniaAddresses.TOKOS_LENDING == address(0)) {
            revert TokosNotDeployed();
        }

        if (isInElix && kandelInstance != address(0)) {
            _retractFromElix();
        }

        uint256 wethBalance = IERC20(WETH).balanceOf(address(this));
        uint256 usdcBalance = IERC20(USDC).balanceOf(address(this));

        if (wethBalance < wethAmount) {
            revert InsufficientBalance("WETH", wethAmount, wethBalance);
        }
        if (usdcBalance < usdcAmount) {
            revert InsufficientBalance("USDC", usdcAmount, usdcBalance);
        }

        if (wethAmount > 0) {
            IERC20(WETH).forceApprove(SomniaAddresses.TOKOS_LENDING, wethAmount);
        }
        if (usdcAmount > 0) {
            IERC20(USDC).forceApprove(SomniaAddresses.TOKOS_LENDING, usdcAmount);
        }

        if (wethAmount > 0) {
            ITokosLending(SomniaAddresses.TOKOS_LENDING).deposit(WETH, wethAmount);
        }
        if (usdcAmount > 0) {
            ITokosLending(SomniaAddresses.TOKOS_LENDING).deposit(USDC, usdcAmount);
        }

        isInTokos = true;
        isInElix = false;

        emit ProvisionedToTokos(wethAmount, usdcAmount);
    }

    /**
     * @notice Emergency withdrawal - retracts all funds from both protocols
     * @dev Panic button that pulls all liquidity back to this contract for safekeeping
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 wethRecovered = 0;
        uint256 usdcRecovered = 0;

        if (isInElix && kandelInstance != address(0)) {
            _retractFromElix();
        }

        if (isInTokos && SomniaAddresses.TOKOS_LENDING != address(0)) {
            _withdrawFromTokos();
        }

        wethRecovered = IERC20(WETH).balanceOf(address(this));
        usdcRecovered = IERC20(USDC).balanceOf(address(this));

        isInElix = false;
        isInTokos = false;

        emit EmergencyWithdrawal(wethRecovered, usdcRecovered);
    }

    /**
     * @dev Internal function to retract all liquidity from Elix Kandel
     */
    function _retractFromElix() internal {
        if (kandelInstance == address(0)) return;

        IKandel(kandelInstance).retract();

        if (vault != address(0)) {
            uint256 vaultWethBalance = IERC20(WETH).balanceOf(vault);
            uint256 vaultUsdcBalance = IERC20(USDC).balanceOf(vault);

            if (vaultWethBalance > 0) {
                IVault(vault).withdraw(WETH, vaultWethBalance);
            }
            if (vaultUsdcBalance > 0) {
                IVault(vault).withdraw(USDC, vaultUsdcBalance);
            }
        }

        isInElix = false;
    }

    /**
     * @dev Internal function to withdraw all funds from Tokos
     */
    function _withdrawFromTokos() internal {
        if (SomniaAddresses.TOKOS_LENDING == address(0)) return;

        ITokosLending tokos = ITokosLending(SomniaAddresses.TOKOS_LENDING);

        uint256 tokosWethBalance = tokos.balanceOf(address(this), WETH);
        uint256 tokosUsdcBalance = tokos.balanceOf(address(this), USDC);

        if (tokosWethBalance > 0) {
            tokos.withdraw(WETH, tokosWethBalance);
        }
        if (tokosUsdcBalance > 0) {
            tokos.withdraw(USDC, tokosUsdcBalance);
        }

        isInTokos = false;
    }

    /**
     * @notice Gets current token balances held in this contract
     * @return wethBalance Amount of WETH held
     * @return usdcBalance Amount of USDC held
     */
    function getContractBalances() external view returns (uint256 wethBalance, uint256 usdcBalance) {
        wethBalance = IERC20(WETH).balanceOf(address(this));
        usdcBalance = IERC20(USDC).balanceOf(address(this));
    }

    /**
     * @notice Gets vault token balances (funds in Elix)
     * @return wethBalance Amount of WETH in vault
     * @return usdcBalance Amount of USDC in vault
     */
    function getVaultBalances() external view returns (uint256 wethBalance, uint256 usdcBalance) {
        if (vault == address(0)) return (0, 0);
        wethBalance = IERC20(WETH).balanceOf(vault);
        usdcBalance = IERC20(USDC).balanceOf(vault);
    }

    /**
     * @notice Gets Tokos lending APY for a token
     * @param token Token address to query
     * @return apy Current APY from Tokos (in basis points)
     */
    function getTokosAPY(address token) external view returns (uint256 apy) {
        if (SomniaAddresses.TOKOS_LENDING == address(0)) return 0;
        return ITokosLending(SomniaAddresses.TOKOS_LENDING).getLendingAPY(token);
    }

    /**
     * @notice Gets health factor from Tokos lending position
     * @return healthFactor Current health factor (1e18 = 100%)
     */
    function getHealthFactor() external view returns (uint256 healthFactor) {
        if (SomniaAddresses.TOKOS_LENDING == address(0)) return 0;
        return ITokosLending(SomniaAddresses.TOKOS_LENDING).getHealthFactor(address(this));
    }

    /**
     * @notice Gets complete position summary across all protocols
     * @return contractWeth WETH held in contract
     * @return contractUsdc USDC held in contract
     * @return vaultWeth WETH in Elix vault
     * @return vaultUsdc USDC in Elix vault
     * @return inElix Whether funds are in Elix
     * @return inTokos Whether funds are in Tokos
     */
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

    /**
     * @notice Rescues any ERC20 tokens accidentally sent to this contract
     * @param token Token address to rescue
     * @param amount Amount to rescue
     */
    function rescueTokens(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(owner(), amount);
    }

    /**
     * @notice Allows contract to receive ETH
     */
    receive() external payable {
        emit FundsReceived(msg.sender, msg.value);
    }
}
