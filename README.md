# Autonomous Liquidity Manager - Somnia Testnet

An AI-powered autonomous liquidity management system for DeFi strategies across Elix (Mangrove) and Tokos lending protocols on Somnia testnet.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   AI Agent Backend                      │
│                (Strategy Decision)                      │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│           AutonomousLiquidityManager.sol                │
│              (On-chain Executor)                        │
│                                                         │
│  ┌─────────────────────┐  ┌─────────────────────────┐   │
│  │    Elix Strategy    │  │     Tokos Strategy      │   │
│  │   (Kandel MM)       │  │   (Lending Yield)       │   │
│  └─────────────────────┘  └─────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│                Mock Tokens (Testnet)                    │
│           mWETH          │          mUSDC               │
└─────────────────────────────────────────────────────────┘
```

## 📦 Contracts Overview

- **AutonomousLiquidityManager.sol** - Main vault and strategy executor
- **TokosLending.sol** - Lending protocol with yield generation
- **MockWETH.sol / MockUSDC.sol** - Testnet tokens with faucet functionality
- **Interfaces** - Clean abstractions for Elix and Tokos protocols
- **Libraries** - Somnia protocol address registry

## 🚀 Quick Start

### 1. Install Dependencies

```bash
# Install Foundry (if not installed)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install OpenZeppelin contracts
forge install OpenZeppelin/openzeppelin-contracts
```

### 2. Environment Setup

```bash
# Copy environment template
cp .env.example .env

# Edit .env with your configuration
PRIVATE_KEY=your_private_key_here
SOMNIA_RPC_URL=https://dream-rpc.somnia.network
CHAIN_ID=50312
```

### 3. Get Testnet Tokens

Get STT (native token) from [Somnia Faucet](https://faucet.somnia.network) for gas fees.

## 🔧 Deployment

### Option 1: Deploy All (Recommended)

```bash
# Deploy mock tokens
./deploy-tokens.sh

# Update .env with token addresses (printed by script)
# Then deploy Tokos
./deploy-tokos.sh

# Finally deploy ALM
./deploy-alm.sh
```

### Option 2: Deploy Individually

```bash
# 1. Deploy Mock Tokens
./deploy-tokens.sh

# 2. Update .env with token addresses:
# WETH_ADDRESS=0x...
# USDC_ADDRESS=0x...

# 3. Deploy Tokos Lending
./deploy-tokos.sh

# 4. Update SomniaAddresses.sol with Tokos address

# 5. Deploy Autonomous Liquidity Manager
./deploy-alm.sh
```

## 📋 Contract Addresses (Example)

After deployment, your contracts will be at addresses like:

```bash
# Mock Tokens
WETH_ADDRESS=0xee8A21AA092902A595f591e6a4d2ABAAa0B49BF2
USDC_ADDRESS=0x164B4eF50c0C8C75Dc6F571e62731C4Fa0C6283A

# Protocol Contracts
TOKOS_LENDING=0x...
AUTONOMOUS_LIQUIDITY_MANAGER=0x...
```

## 🎯 Usage Examples

### 1. Claim Test Tokens

```bash
# Get 10 mWETH
cast send $WETH_ADDRESS "faucet()" --rpc-url $SOMNIA_RPC_URL --private-key $PRIVATE_KEY

# Get 10,000 mUSDC
cast send $USDC_ADDRESS "faucet()" --rpc-url $SOMNIA_RPC_URL --private-key $PRIVATE_KEY
```

### 2. Fund the Autonomous Liquidity Manager

```bash
# Transfer 10 WETH to ALM
cast send $WETH_ADDRESS "transfer(address,uint256)" $ALM_ADDRESS 10000000000000000000 \
  --rpc-url $SOMNIA_RPC_URL --private-key $PRIVATE_KEY

# Transfer 10,000 USDC to ALM  
cast send $USDC_ADDRESS "transfer(address,uint256)" $ALM_ADDRESS 10000000000 \
  --rpc-url $SOMNIA_RPC_URL --private-key $PRIVATE_KEY
```

### 3. Check Contract Balances

```bash
# Check ALM balances
cast call $ALM_ADDRESS "getContractBalances()" --rpc-url $SOMNIA_RPC_URL

# Check position summary
cast call $ALM_ADDRESS "getPositionSummary()" --rpc-url $SOMNIA_RPC_URL
```

### 4. Strategy Operations

```bash
# Provision to Tokos lending (1 WETH, 1000 USDC)
cast send $ALM_ADDRESS "provisionToTokos(uint256,uint256)" 1000000000000000000 1000000000 \
  --rpc-url $SOMNIA_RPC_URL --private-key $PRIVATE_KEY

# Emergency withdraw (get all funds back)
cast send $ALM_ADDRESS "emergencyWithdraw()" \
  --rpc-url $SOMNIA_RPC_URL --private-key $PRIVATE_KEY
```

### 5. Check Tokos APY

```bash
# Get WETH lending APY
cast call $TOKOS_ADDRESS "getLendingAPY(address)" $WETH_ADDRESS --rpc-url $SOMNIA_RPC_URL

# Get USDC lending APY  
cast call $TOKOS_ADDRESS "getLendingAPY(address)" $USDC_ADDRESS --rpc-url $SOMNIA_RPC_URL
```

## 🧪 Testing

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vvv

# Run specific test file
forge test --match-contract MockWETHTest

# Generate gas report
forge test --gas-report
```

## 📁 Project Structure

```
contracts/
├── src/
│   ├── AutonomousLiquidityManager.sol       # Main ALM contract
│   ├── interfaces/
│   │   ├── IKandelSeeder.sol                # Elix Kandel seeder interface
│   │   ├── IKandel.sol                      # Kandel instance interface
│   │   ├── IVaultFactory.sol                # Elix vault factory interface
│   │   ├── IVault.sol                       # Elix vault interface
│   │   └── ITokosLending.sol                # Tokos lending interface
│   ├── libraries/
│   │   └── SomniaAddresses.sol              # Protocol address registry
│   ├── mocks/
│   │   ├── MockWETH.sol                     # Test WETH with faucet
│   │   └── MockUSDC.sol                     # Test USDC with faucet
│   └── tokos/
│       └── TokosLending.sol                 # Lending protocol implementation
├── test/
│   ├── AutonomousLiquidityManager.t.sol     # ALM tests
│   ├── TokosLending.t.sol                   # Tokos tests
│   ├── MockWETH.t.sol                       # WETH tests
│   └── MockUSDC.t.sol                       # USDC tests
├── deploy-tokens.sh                         # Deploy mock tokens
├── deploy-tokos.sh                          # Deploy Tokos lending
└── deploy-alm.sh                            # Deploy ALM
```

## 🔐 Security Features

- ✅ **Ownable**: Only backend agent wallet can execute strategies
- ✅ **SafeERC20**: Protected token transfers
- ✅ **Balance Checks**: Validates sufficient funds before operations
- ✅ **Emergency Withdraw**: Panic button for risk management
- ✅ **Atomic Operations**: No partial state changes
- ✅ **Custom Errors**: Gas-efficient error handling
- ✅ **ReentrancyGuard**: Protection against reentrancy attacks

## 🌟 Core Features

### Autonomous Liquidity Manager

- **provisionToElix()** - Deploy funds to Kandel market-making
- **provisionToTokos()** - Move funds to lending for yield
- **emergencyWithdraw()** - Panic button to retrieve all funds
- **getPositionSummary()** - Complete portfolio overview

### Tokos Lending Protocol

- **Dynamic APY** - Interest rates adjust based on utilization
- **Multi-token support** - WETH and USDC pools
- **Share-based accounting** - Fair distribution of rewards
- **Real-time interest accrual** - Compound interest calculation

### Mock Tokens (Testnet)

- **Faucet functionality** - Get test tokens every hour
- **ERC20 compliant** - Full standard implementation
- **Realistic decimals** - 18 for WETH, 6 for USDC

## 🔗 Somnia Testnet Info

- **Chain ID:** 50312 (0xc488)
- **RPC URL:** https://dream-rpc.somnia.network
- **Currency:** STT
- **Block Explorer:** [Somnia Explorer](https://explorer.somnia.network)
- **Faucet:** [Get STT tokens](https://faucet.somnia.network)

### Elix (Mangrove) Protocol Addresses

| Contract | Address |
|----------|---------|
| Mangrove (MGV) | `0x13d30dF7e872660fDd5293BEe39EBd7a61C4C622` |
| MGV Reader | `0xe3dbF8bAB1c5D4B3386Fc05e207Bd8f91552ACc0` |
| Vault Factory | `0xD7c89B9AC4f09131a962BB9527CcF26cB68cF70c` |
| Kandel Seeder | `0x5Abc9F2f694269eb24FD27321A00445cc0E7B4c4` |

## 🤖 AI Agent Integration

The system is designed to work with an AI backend that:

1. **Monitors** market conditions (spreads, volatility, APYs)
2. **Decides** optimal strategy allocation
3. **Executes** via AutonomousLiquidityManager functions
4. **Tracks** performance and risk metrics

### Example Backend Flow

```javascript
// Check current position
const position = await alm.getPositionSummary();

// Compare opportunities
const elixSpread = await calculateElixOpportunity();
const tokosAPY = await alm.getTokosAPY(WETH);

// Make decision
if (elixSpread > tokosAPY && !position.inElix) {
  await alm.provisionToElix(wethAmount, usdcAmount, kandelParams);
} else if (tokosAPY > elixSpread && !position.inTokos) {
  await alm.provisionToTokos(wethAmount, usdcAmount);
}
```

## 📊 Monitoring & Analytics

### Key Metrics to Track

- **Total Value Locked (TVL)** in each strategy
- **APY Performance** vs benchmarks
- **Risk Metrics** (drawdown, volatility)
- **Gas Efficiency** of strategy switches
- **Slippage** in Elix operations

### Dashboard Integration

```bash
# Get all relevant data
cast call $ALM_ADDRESS "getPositionSummary()" --rpc-url $SOMNIA_RPC_URL
cast call $TOKOS_ADDRESS "getTotalValueLocked()" --rpc-url $SOMNIA_RPC_URL
cast call $TOKOS_ADDRESS "getLendingAPY(address)" $WETH_ADDRESS --rpc-url $SOMNIA_RPC_URL
```

## 🛠️ Development

### Build

```bash
forge build
```

### Format

```bash
forge fmt
```

### Coverage

```bash
forge coverage
```

### Gas Optimization

```bash
forge test --gas-report
```

## 📝 License

MIT License - Built for Somnia Hackathon 2025

## 🆘 Troubleshooting

### Common Issues

1. **Transaction Failures**: Ensure sufficient STT balance for gas
2. **Contract Not Found**: Verify correct addresses in .env
3. **Faucet Cooldown**: Wait 1 hour between faucet claims
4. **Insufficient Balance**: Check token balances before operations

### Support

- Check the contract addresses are correct in .env
- Verify you have STT tokens for gas
- Ensure private key has sufficient permissions
- Check Somnia testnet status

---

**Built for Somnia Hackathon 2025** 🚀