// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockUSDC
 * @notice Mock USDC token for Somnia testnet
 * @dev Includes faucet functionality for easy testing. Uses 6 decimals like real USDC
 */
contract MockUSDC is ERC20, Ownable {
    uint8 private _decimals = 6;

    uint256 public constant FAUCET_AMOUNT = 10_000 * 1e6;

    uint256 public constant FAUCET_COOLDOWN = 1 hours;

    mapping(address => uint256) public lastFaucetClaim;

    event FaucetClaimed(address indexed user, uint256 amount);
    event Minted(address indexed to, uint256 amount);

    error FaucetCooldownActive(uint256 remainingTime);

    /**
     * @notice Deploys Mock USDC token
     * @param initialOwner Owner address
     */
    constructor(address initialOwner) ERC20("Mock USD Coin", "mUSDC") Ownable(initialOwner) {
        _mint(initialOwner, 10_000_000 * 1e6);
    }

    /**
     * @notice Claims tokens from the faucet
     * @dev Can be called once per hour per address
     */
    function faucet() external {
        uint256 timeSinceLastClaim = block.timestamp - lastFaucetClaim[msg.sender];

        if (lastFaucetClaim[msg.sender] != 0 && timeSinceLastClaim < FAUCET_COOLDOWN) {
            revert FaucetCooldownActive(FAUCET_COOLDOWN - timeSinceLastClaim);
        }

        lastFaucetClaim[msg.sender] = block.timestamp;
        _mint(msg.sender, FAUCET_AMOUNT);

        emit FaucetClaimed(msg.sender, FAUCET_AMOUNT);
    }

    /**
     * @notice Checks if an address can claim from faucet
     * @param user Address to check
     * @return canClaim Whether the address can claim
     * @return remainingTime Time until next claim (0 if can claim now)
     */
    function canClaimFaucet(address user) external view returns (bool canClaim, uint256 remainingTime) {
        if (lastFaucetClaim[user] == 0) {
            return (true, 0);
        }

        uint256 timeSinceLastClaim = block.timestamp - lastFaucetClaim[user];

        if (timeSinceLastClaim >= FAUCET_COOLDOWN) {
            return (true, 0);
        } else {
            return (false, FAUCET_COOLDOWN - timeSinceLastClaim);
        }
    }

    /**
     * @notice Mints tokens to a specific address (owner only)
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
        emit Minted(to, amount);
    }

    /**
     * @notice Burns tokens from caller
     * @param amount Amount to burn
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /**
     * @notice Burns tokens from a specific address (requires approval)
     * @param from Address to burn from
     * @param amount Amount to burn
     */
    function burnFrom(address from, uint256 amount) external {
        _spendAllowance(from, msg.sender, amount);
        _burn(from, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}
