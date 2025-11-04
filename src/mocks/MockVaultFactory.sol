// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IVaultFactory.sol";
import "../interfaces/IVault.sol";

/**
 * @title MockVaultFactory
 * @notice Mock implementation of VaultFactory for testing purposes
 * @dev Creates simple vaults that can hold and transfer tokens
 */
contract MockVaultFactory is IVaultFactory {
    event VaultCreated(address indexed owner, address indexed vault);

    mapping(address => address[]) public ownerToVaults;
    address[] public allVaults;

    /**
     * @notice Creates a new mock vault for the given owner
     * @param owner The owner of the vault
     * @return vault Address of the created vault
     */
    function createVault(address owner) external returns (address vault) {
        MockVault newVault = new MockVault(owner);
        vault = address(newVault);

        ownerToVaults[owner].push(vault);
        allVaults.push(vault);

        emit VaultCreated(owner, vault);
    }

    /**
     * @notice Gets the vault address for a specific owner (returns first vault)
     * @param owner The owner address
     * @return vault The vault address (address(0) if none exists)
     */
    function getVault(address owner) external view returns (address vault) {
        if (ownerToVaults[owner].length > 0) {
            return ownerToVaults[owner][0];
        }
        return address(0);
    }

    /**
     * @notice Gets all vaults owned by an address
     * @param owner The owner address
     * @return vaults Array of vault addresses
     */
    function getVaultsForOwner(address owner) external view returns (address[] memory) {
        return ownerToVaults[owner];
    }

    /**
     * @notice Gets total number of vaults created
     * @return count Total count
     */
    function getVaultCount() external view returns (uint256) {
        return allVaults.length;
    }
}

/**
 * @title MockVault
 * @notice Mock implementation of a simple vault
 * @dev Holds tokens and allows owner to withdraw them
 */
contract MockVault is IVault {
    using SafeERC20 for IERC20;

    address public immutable owner;

    event Deposit(address indexed token, uint256 amount);
    event Withdrawal(address indexed token, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _owner) {
        owner = _owner;
    }

    /**
     * @notice Withdraws tokens from the vault
     * @param token Token address to withdraw
     * @param amount Amount to withdraw
     */
    function withdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(owner, amount);
        emit Withdrawal(token, amount);
    }

    /**
     * @notice Deposits tokens to the vault (anyone can deposit)
     * @param token Token address to deposit
     * @param amount Amount to deposit
     */
    function deposit(address token, uint256 amount) external {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit Deposit(token, amount);
    }

    /**
     * @notice Approves a spender to use vault tokens
     * @param token Token to approve
     * @param spender Address to approve
     * @param amount Amount to approve
     */
    function approve(address token, address spender, uint256 amount) external onlyOwner {
        IERC20(token).approve(spender, amount);
    }

    /**
     * @notice Gets token balance in the vault (IVault interface)
     * @param token Token address to check
     * @return balance Token balance
     */
    function balanceOf(address token) external view returns (uint256 balance) {
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * @notice Gets token balance in the vault (legacy method)
     * @param token Token address to check
     * @return balance Token balance
     */
    function getBalance(address token) external view returns (uint256 balance) {
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * @notice Emergency function to withdraw all tokens of a type
     * @param token Token to withdraw completely
     */
    function emergencyWithdraw(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).safeTransfer(owner, balance);
            emit Withdrawal(token, balance);
        }
    }

    /**
     * @notice Allows vault to receive ETH
     */
    receive() external payable {
        // Accept ETH deposits
    }

    /**
     * @notice Withdraw ETH from vault
     * @param amount Amount of ETH to withdraw
     */
    function withdrawETH(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient ETH");
        payable(owner).transfer(amount);
    }
}
