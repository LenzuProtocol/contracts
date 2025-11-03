#!/bin/bash

# Deploy Mock Tokens (mWETH and mUSDC) on Somnia Testnet

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Deploying Mock Tokens to Somnia Testnet${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check .env
if [ ! -f .env ]; then
    echo -e "${YELLOW}⚠ .env file not found! Please create one.${NC}"
    exit 1
fi

source .env

# Get deployer address
DEPLOYER=$(cast wallet address --private-key $PRIVATE_KEY)
echo -e "${BLUE}ℹ Deployer: $DEPLOYER${NC}"
echo ""

# Deploy mWETH
echo -e "${BLUE}ℹ Deploying mWETH...${NC}"
MWETH_RESULT=$(forge create src/mocks/MockWETH.sol:MockWETH \
    --broadcast \
    --rpc-url $SOMNIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --constructor-args $DEPLOYER 2>&1)

MWETH_ADDRESS=$(echo "$MWETH_RESULT" | grep "Deployed to:" | awk '{print $3}')
MWETH_TX=$(echo "$MWETH_RESULT" | grep "Transaction hash:" | awk '{print $3}')

echo -e "${GREEN}✓ mWETH deployed: $MWETH_ADDRESS${NC}"
echo -e "  TX: $MWETH_TX"
echo ""

# Deploy mUSDC
echo -e "${BLUE}ℹ Deploying mUSDC...${NC}"
MUSDC_RESULT=$(forge create src/mocks/MockUSDC.sol:MockUSDC \
    --broadcast \
    --rpc-url $SOMNIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --constructor-args $DEPLOYER 2>&1)

MUSDC_ADDRESS=$(echo "$MUSDC_RESULT" | grep "Deployed to:" | awk '{print $3}')
MUSDC_TX=$(echo "$MUSDC_RESULT" | grep "Transaction hash:" | awk '{print $3}')

echo -e "${GREEN}✓ mUSDC deployed: $MUSDC_ADDRESS${NC}"
echo -e "  TX: $MUSDC_TX"

echo ""
echo -e "${GREEN}✓ Mock tokens deployed successfully!${NC}"
echo ""
echo "Update your .env file:"
echo "WETH_ADDRESS=$MWETH_ADDRESS"
echo "USDC_ADDRESS=$MUSDC_ADDRESS"
echo ""
echo "Test faucets:"
echo "  cast send $MWETH_ADDRESS \"faucet()\" --rpc-url \$SOMNIA_RPC_URL --private-key \$PRIVATE_KEY"
echo "  cast send $MUSDC_ADDRESS \"faucet()\" --rpc-url \$SOMNIA_RPC_URL --private-key \$PRIVATE_KEY"
