#!/bin/bash

# Deploy Autonomous Liquidity Manager on Somnia Testnet

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Deploying Autonomous Liquidity Manager${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check .env
if [ ! -f .env ]; then
    echo -e "${RED}✗ .env file not found!${NC}"
    exit 1
fi

source .env

# Check prerequisites
if [ -z "$WETH_ADDRESS" ] || [ -z "$USDC_ADDRESS" ]; then
    echo -e "${RED}✗ WETH_ADDRESS and USDC_ADDRESS must be set in .env${NC}"
    echo -e "${YELLOW}  Run deploy-tokens.sh first!${NC}"
    exit 1
fi

# Get deployer address
DEPLOYER=$(cast wallet address --private-key $PRIVATE_KEY)
echo -e "${BLUE}ℹ Deployer: $DEPLOYER${NC}"
echo ""

# Deploy AutonomousLiquidityManager
echo -e "${BLUE}ℹ Deploying AutonomousLiquidityManager...${NC}"
ALM_RESULT=$(forge create src/AutonomousLiquidityManager.sol:AutonomousLiquidityManager \
    --broadcast \
    --rpc-url $SOMNIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --constructor-args $DEPLOYER 2>&1)

ALM_ADDRESS=$(echo "$ALM_RESULT" | grep "Deployed to:" | awk '{print $3}')
ALM_TX=$(echo "$ALM_RESULT" | grep "Transaction hash:" | awk '{print $3}')

echo -e "${GREEN}✓ AutonomousLiquidityManager deployed: $ALM_ADDRESS${NC}"
echo -e "  TX: $ALM_TX"
echo ""

# Initialize with setAssets
echo -e "${BLUE}ℹ Setting asset addresses...${NC}"
SET_ASSETS_TX=$(cast send $ALM_ADDRESS \
    "setAssets(address,address)" \
    $WETH_ADDRESS \
    $USDC_ADDRESS \
    --rpc-url $SOMNIA_RPC_URL \
    --private-key $PRIVATE_KEY 2>&1 | grep "transactionHash" | cut -d'"' -f4)

echo -e "${GREEN}✓ Assets configured${NC}"
echo ""
echo -e "${GREEN}✓ AutonomousLiquidityManager deployed successfully!${NC}"
echo ""
echo "Contract address: $ALM_ADDRESS"
echo "WETH: $WETH_ADDRESS"
echo "USDC: $USDC_ADDRESS"
echo ""
echo "Test commands:"
echo "  # Check balances:"
echo "  cast call $ALM_ADDRESS \"getContractBalances()\" --rpc-url \$SOMNIA_RPC_URL"
echo ""
echo "  # Transfer tokens to ALM (10 WETH, 10000 USDC):"
echo "  cast send $WETH_ADDRESS \"transfer(address,uint256)\" $ALM_ADDRESS 10000000000000000000 --rpc-url \$SOMNIA_RPC_URL --private-key \$PRIVATE_KEY"
echo "  cast send $USDC_ADDRESS \"transfer(address,uint256)\" $ALM_ADDRESS 10000000000 --rpc-url \$SOMNIA_RPC_URL --private-key \$PRIVATE_KEY"
