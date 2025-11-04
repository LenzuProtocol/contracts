# Lenzu Protocol - Smart Contracts

An AI-powered autonomous liquidity management system built on Somnia blockchain, featuring testnet faucets, lending protocols, and agent management contracts. The system enables autonomous DeFi strategies across multiple protocols with real-time decision making.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   AI Agent Service                      │
│           (Multi-User Management & AI)                  │
│              ┌─────────────────────────┐                │
│              │     Price Oracle        │                │
│              │    (CoinGecko API)      │                │
│              └─────────────────────────┘                │
└────────────────┬────────────────────────────────────────┘
                 │ Web3 Calls
                 ▼
┌──────────────────────────────────────────────────────────┐
│              Smart Contract Layer                        │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────┐ │
│  │  Agent Manager  │ │ Tokos  &  Elix  │ │ Mock Tokens │ │
│  │   (ALM Core)    │ │   (Yield Gen)   │ │  (Testnet)  │ │
│  └─────────────────┘ └─────────────────┘ └─────────────┘ │
└──────────────────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│               Somnia Blockchain                         │
│        mWETH (10 ETH)    │    mUSDC (10,000)            │
│        Faucet Claims     │    Faucet Claims             │
└─────────────────────────────────────────────────────────┘
```

## 📦 Contracts Overview

### Core Contracts
- **AgentManager.sol** - Main autonomous liquidity management contract
- **TokosLending.sol** - Lending protocol with dynamic APY and yield generation
- **MockWETH.sol** - Testnet WETH with faucet functionality (10 ETH per claim)
- **MockUSDC.sol** - Testnet USDC with faucet functionality (10,000 USDC per claim)

### Interface Layer
- **IKandel.sol / IKandelSeeder.sol** - Elix protocol integrations
- **ITokosLending.sol** - Lending protocol interface
- **IVault.sol / IVaultFactory.sol** - Vault management interfaces

### Libraries
- **SomniaAddresses.sol** - Protocol address registry for production
- **MockSomniaAddresses.sol** - Testnet address registry

## 🚀 Quick Start

### 1. Install Dependencies

```bash
# Install Foundry (if not installed)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install project dependencies
forge install
```

### 2. Environment Setup

```bash
# Copy environment template
cp .env.example .env

# Edit .env with your configuration
PRIVATE_KEY=your_private_key_here
SOMNIA_RPC_URL=https://testnet.somnia.network
CHAIN_ID=50312
```

### 3. Get Testnet Tokens

Get STT (native token) from [Somnia Faucet](https://faucet.somnia.network) for gas fees.

## 🔧 Deployment

### Quick Deploy All Contracts

```bash
# Deploy everything with one command
./scripts/deploy_fixed.sh
```

This will deploy in the correct order:
1. Mock tokens (WETH, USDC)
2. Tokos lending protocol  
3. Agent manager contract
4. Save all addresses to `deployments/addresses.txt`

### Manual Deployment Steps

```bash
# 1. Deploy Mock Tokens
forge create src/mocks/MockWETH.sol:MockWETH \
  --constructor-args $DEPLOYER_ADDRESS \
  --rpc-url $SOMNIA_RPC_URL \
  --private-key $PRIVATE_KEY

forge create src/mocks/MockUSDC.sol:MockUSDC \
  --constructor-args $DEPLOYER_ADDRESS \
  --rpc-url $SOMNIA_RPC_URL \
  --private-key $PRIVATE_KEY

# 2. Deploy Tokos Lending
forge create src/tokos/TokosLending.sol:TokosLending \
  --rpc-url $SOMNIA_RPC_URL \
  --private-key $PRIVATE_KEY

# 3. Deploy Agent Manager
forge create src/AgentManager.sol:AgentManager \
  --constructor-args $OWNER_ADDRESS $TOKOS_ADDRESS $WETH_ADDRESS $USDC_ADDRESS \
  --rpc-url $SOMNIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

## 📋 Deployed Contract Addresses (Somnia Testnet)

```bash
# Core Contracts
AGENT_MANAGER=0x63FAb7efA8cda0adc2C78776488cC77279184E83
TOKOS_LENDING=0xBACBf125969023F26415A8b914d05f421B423009

# Mock Tokens (Faucets)
WETH_ADDRESS=0x578b2807ea81C429505F1be4743Aec422758A461
USDC_ADDRESS=0xEf2F49a4fC829B3cB1d80b0f9FDc0fb0D149e7B0

# Supporting Contracts
KANDEL_SEEDER=0xED05f0EF1BA48585C45B2DD52c0DbD57d66Ea981
VAULT_FACTORY=0xC231246DB86C897B1A8DaB35bA2A834F4bC6191c
```

## 🎯 Usage Examples

### 1. Claim Test Tokens from Faucets

```bash
# Claim 10 WETH (once per hour)
cast send $WETH_ADDRESS "faucet()" \
  --rpc-url $SOMNIA_RPC_URL \
  --private-key $PRIVATE_KEY

# Claim 10,000 USDC (once per hour)  
cast send $USDC_ADDRESS "faucet()" \
  --rpc-url $SOMNIA_RPC_URL \
  --private-key $PRIVATE_KEY

# Check if you can claim (returns canClaim, remainingTime)
cast call $WETH_ADDRESS "canClaimFaucet(address)" $YOUR_ADDRESS \
  --rpc-url $SOMNIA_RPC_URL
```

### 2. Check Token Balances

```bash
# Check your WETH balance
cast call $WETH_ADDRESS "balanceOf(address)" $YOUR_ADDRESS \
  --rpc-url $SOMNIA_RPC_URL

# Check your USDC balance  
cast call $USDC_ADDRESS "balanceOf(address)" $YOUR_ADDRESS \
  --rpc-url $SOMNIA_RPC_URL

# Check faucet amounts
cast call $WETH_ADDRESS "FAUCET_AMOUNT()" --rpc-url $SOMNIA_RPC_URL
cast call $USDC_ADDRESS "FAUCET_AMOUNT()" --rpc-url $SOMNIA_RPC_URL
```

### 3. Tokos Lending Operations

```bash
# Supply 1 WETH to lending pool
cast send $WETH_ADDRESS "approve(address,uint256)" $TOKOS_ADDRESS 1000000000000000000 \
  --rpc-url $SOMNIA_RPC_URL --private-key $PRIVATE_KEY

cast send $TOKOS_ADDRESS "supply(address,uint256)" $WETH_ADDRESS 1000000000000000000 \
  --rpc-url $SOMNIA_RPC_URL --private-key $PRIVATE_KEY

# Check lending APY
cast call $TOKOS_ADDRESS "getLendingAPY(address)" $WETH_ADDRESS \
  --rpc-url $SOMNIA_RPC_URL

# Check your supplied amount
cast call $TOKOS_ADDRESS "getSuppliedAmount(address,address)" $YOUR_ADDRESS $WETH_ADDRESS \
  --rpc-url $SOMNIA_RPC_URL
```

### 4. Agent Manager Operations

```bash
# Check agent status
cast call $AGENT_MANAGER "getPositionSummary()" \
  --rpc-url $SOMNIA_RPC_URL

# Supply funds to Tokos via Agent Manager (owner only)
cast send $AGENT_MANAGER "provisionToTokos(uint256,uint256)" 1000000000000000000 1000000000 \
  --rpc-url $SOMNIA_RPC_URL --private-key $PRIVATE_KEY

# Emergency withdraw all funds (owner only)
cast send $AGENT_MANAGER "emergencyWithdraw()" \
  --rpc-url $SOMNIA_RPC_URL --private-key $PRIVATE_KEY
```

## 🧪 Testing

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vvv

# Run specific test file
forge test --match-contract MockWETHTest

# Run specific test function
forge test --match-test testFaucetCooldown

# Generate gas report
forge test --gas-report

# Generate coverage report
forge coverage
```

### Test Coverage

- ✅ **MockWETH**: Faucet functionality, cooldown, transfers
- ✅ **MockUSDC**: Faucet functionality, decimals, minting
- ✅ **TokosLending**: Supply, withdraw, APY calculations
- ✅ **AgentManager**: Strategy execution, emergency procedures

## 📁 Project Structure

```
contracts/
├── src/
│   ├── AgentManager.sol                    # Main autonomous liquidity manager
│   ├── interfaces/
│   │   ├── IKandelSeeder.sol              # Elix Kandel seeder interface
│   │   ├── IKandel.sol                    # Kandel instance interface  
│   │   ├── IVaultFactory.sol              # Elix vault factory interface
│   │   ├── IVault.sol                     # Elix vault interface
│   │   └── ITokosLending.sol              # Tokos lending interface
│   ├── libraries/
│   │   ├── SomniaAddresses.sol            # Production address registry
│   │   └── MockSomniaAddresses.sol        # Testnet address registry
│   ├── mocks/
│   │   ├── MockWETH.sol                   # Testnet WETH with faucet
│   │   ├── MockUSDC.sol                   # Testnet USDC with faucet
│   │   ├── MockKandelSeeder.sol           # Mock Elix seeder
│   │   └── MockVaultFactory.sol           # Mock vault factory
│   └── tokos/
│       └── TokosLending.sol               # Lending protocol implementation
├── test/
│   ├── AgentManager.t.sol                 # Agent manager tests
│   ├── TokosLending.t.sol                 # Tokos lending tests
│   ├── MockWETH.t.sol                     # WETH faucet tests
│   ├── MockUSDC.t.sol                     # USDC faucet tests
│   └── MockElix.t.sol                     # Elix integration tests
├── scripts/
│   ├── deploy_fixed.sh                    # Deploy all contracts
│   ├── deploy-agent.sh                    # Deploy agent manager only
│   ├── claim-faucet.sh                    # Claim from faucets
│   └── check-balance.sh                   # Check token balances
├── deployments/
│   ├── addresses.txt                      # All deployed addresses
│   ├── manager_address.txt                # Agent manager address
│   ├── tokos_address.txt                  # Tokos lending address
│   ├── weth_address.txt                   # WETH token address
│   └── usdc_address.txt                   # USDC token address
├── foundry.toml                           # Foundry configuration
└── README.md                              # This file
```

## 🔐 Security Features

### Contract Security
- ✅ **Ownable**: Only authorized wallets can execute strategies
- ✅ **SafeERC20**: Protected token transfers with proper error handling
- ✅ **Balance Checks**: Validates sufficient funds before operations
- ✅ **Emergency Withdraw**: Panic button for risk management
- ✅ **Atomic Operations**: No partial state changes
- ✅ **Custom Errors**: Gas-efficient error handling
- ✅ **ReentrancyGuard**: Protection against reentrancy attacks

### Faucet Security
- ✅ **Cooldown Period**: 1 hour between claims per address
- ✅ **Fixed Amounts**: Prevents excessive token inflation
- ✅ **Rate Limiting**: Built-in spam protection
- ✅ **Balance Tracking**: Accurate accounting of claimed amounts

### Access Control
- ✅ **Role-based permissions**: Owner-only functions for critical operations
- ✅ **Multi-signature ready**: Compatible with multisig wallets
- ✅ **Upgradeable patterns**: Future-proof contract architecture

## 🌟 Core Features

### AgentManager (Autonomous Liquidity Manager)

#### Strategy Functions
- **provisionToTokos()** - Move funds to lending for yield generation
- **provisionToElix()** - Deploy funds to Kandel market-making (if integrated)
- **emergencyWithdraw()** - Panic button to retrieve all funds immediately
- **getPositionSummary()** - Complete portfolio overview and metrics

#### Management Functions  
- **setTokosLending()** - Update Tokos contract address (owner only)
- **rescueTokens()** - Recover accidentally sent tokens (owner only)
- **updateOwner()** - Transfer ownership to new address

### TokosLending Protocol

#### Core Lending Features
- **supply()** - Deposit tokens to earn yield
- **withdraw()** - Remove tokens from lending pool
- **borrow()** - Borrow against collateral (if implemented)
- **repay()** - Pay back borrowed amounts

#### Analytics Functions
- **getLendingAPY()** - Current annual percentage yield
- **getTotalValueLocked()** - Total funds in protocol
- **getSuppliedAmount()** - User's supplied balance
- **getUtilizationRate()** - Pool utilization metrics

### Mock Tokens (Testnet Only)

#### Faucet Functions
- **faucet()** - Claim tokens (10 WETH or 10,000 USDC)
- **canClaimFaucet()** - Check eligibility and cooldown
- **FAUCET_AMOUNT** - View claimable amount
- **FAUCET_COOLDOWN** - View cooldown period (1 hour)

#### Standard ERC20
- **transfer()**, **approve()**, **transferFrom()** - Standard token operations
- **balanceOf()**, **totalSupply()** - Balance queries
- **decimals()** - Token precision (18 for WETH, 6 for USDC)

## 🔗 Somnia Testnet Information

### Network Details
- **Chain ID**: 50312 (0xc488)
- **RPC URL**: https://testnet.somnia.network  
- **Currency**: STT (Somnia Test Token)
- **Block Explorer**: https://explorer.somnia.network
- **Faucet**: https://faucet.somnia.network

### Adding to Wallet

```json
{
  "chainId": "0xc488",
  "chainName": "Somnia Testnet",
  "nativeCurrency": {
    "name": "STT",
    "symbol": "STT", 
    "decimals": 18
  },
  "rpcUrls": ["https://testnet.somnia.network"],
  "blockExplorerUrls": ["https://explorer.somnia.network"]
}
```

## 🤖 AI Agent Integration

### Backend Integration Points

The contracts are designed to work seamlessly with the Lenzu Agent Service:

```javascript
// Agent service calls contract functions
const agentManager = new Contract(AGENT_MANAGER_ADDRESS, ABI, signer);

// Check current position
const position = await agentManager.getPositionSummary();

// Execute strategy based on AI decision
if (shouldSupplyToTokos) {
  await agentManager.provisionToTokos(wethAmount, usdcAmount);
}

// Emergency procedures
if (riskTooHigh) {
  await agentManager.emergencyWithdraw();
}
```

### Multi-User Support

The Agent Service can manage multiple users by:
1. Each user deploys their own AgentManager instance
2. Agent service maintains mapping of user → contract address
3. AI makes personalized decisions per user's portfolio

## 📊 Monitoring & Analytics

### On-chain Metrics

```bash
# Portfolio value
cast call $AGENT_MANAGER "getPositionSummary()" --rpc-url $SOMNIA_RPC_URL

# Tokos performance  
cast call $TOKOS_ADDRESS "getLendingAPY(address)" $WETH_ADDRESS --rpc-url $SOMNIA_RPC_URL
cast call $TOKOS_ADDRESS "getTotalValueLocked()" --rpc-url $SOMNIA_RPC_URL

# Token metrics
cast call $WETH_ADDRESS "totalSupply()" --rpc-url $SOMNIA_RPC_URL
cast call $USDC_ADDRESS "totalSupply()" --rpc-url $SOMNIA_RPC_URL
```

### Event Monitoring

Key events to monitor for analytics:

```solidity
// AgentManager events
event FundsDeployed(string strategy, uint256 wethAmount, uint256 usdcAmount);
event EmergencyWithdraw(uint256 wethAmount, uint256 usdcAmount);

// Tokos events  
event Supply(address indexed user, address indexed token, uint256 amount);
event Withdraw(address indexed user, address indexed token, uint256 amount);

// Faucet events
event FaucetClaimed(address indexed user, uint256 amount);
```

## 🛠️ Development Commands

### Building & Testing

```bash
# Clean build
forge clean && forge build

# Format code
forge fmt

# Run linter
forge test --check

# Gas optimization report
forge test --gas-report

# Generate documentation
forge doc --build
```

### Deployment Helpers

```bash
# Check deployment status
./scripts/check-balance.sh

# Claim tokens for testing
./scripts/claim-faucet.sh

# Verify contracts on explorer
forge verify-contract $CONTRACT_ADDRESS ContractName \
  --chain-id 50312 \
  --constructor-args $(cast abi-encode "constructor(address)" $OWNER_ADDRESS)
```

## 🆘 Troubleshooting

### Common Issues

**"Transaction failed: insufficient funds"**
- Get STT from [Somnia faucet](https://faucet.somnia.network) for gas
- Check your STT balance: `cast balance $YOUR_ADDRESS --rpc-url $SOMNIA_RPC_URL`

**"Faucet cooldown active"**  
- Wait 1 hour between faucet claims
- Check remaining time: `cast call $TOKEN_ADDRESS "canClaimFaucet(address)" $YOUR_ADDRESS`

**"Contract not found"**
- Verify contract addresses in `deployments/addresses.txt`
- Ensure you're using the correct RPC URL for Somnia testnet

**"Function not found in ABI"**
- Rebuild contracts: `forge build`
- Check contract is deployed: `cast code $CONTRACT_ADDRESS --rpc-url $SOMNIA_RPC_URL`

### Development Issues

**"Compilation failed"**
- Run `forge install` to ensure dependencies are installed
- Check Solidity version compatibility in `foundry.toml`

**"Tests failing"**
- Ensure you have test tokens: run `./scripts/claim-faucet.sh`
- Check test setup in `test/` directory

### Gas Issues

**"Transaction underpriced"**
- Somnia testnet uses dynamic gas pricing
- Try increasing gas limit: `--gas-limit 500000`

**"Gas estimation failed"**  
- Check contract state allows the operation
- Verify token approvals are set correctly

## 📚 Additional Resources

### Documentation
- **Foundry Book**: https://book.getfoundry.sh/
- **OpenZeppelin Contracts**: https://docs.openzeppelin.com/contracts/
- **Somnia Documentation**: https://docs.somnia.network/

### Somnia Ecosystem
- **Discord**: https://discord.gg/somnia
- **GitHub**: https://github.com/Somnia-Network
- **Block Explorer**: https://explorer.somnia.network

## 📝 License

MIT License - Built for the Somnia blockchain ecosystem.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Follow Solidity best practices and existing code style
4. Add comprehensive tests for new functionality
5. Run the full test suite: `forge test`
6. Submit a pull request with detailed description
