#!/bin/bash

# Deploy Tokos Lending Protocol on Somnia Testnet

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Deploying Tokos Lending Protocol${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check .env
if [ ! -f .env ]; then
    echo -e "${RED}✗ .env file not found!${NC}"
    exit 1
fi

source .env

# Check token addresses
if [ -z "$WETH_ADDRESS" ] || [ -z "$USDC_ADDRESS" ]; then
    echo -e "${YELLOW}⚠ Warning: WETH_ADDRESS or USDC_ADDRESS not set in .env${NC}"
    echo -e "${YELLOW}  Pools will not be initialized automatically.${NC}"
    echo ""
fi

# Get deployer address
DEPLOYER=$(cast wallet address --private-key $PRIVATE_KEY)
echo -e "${BLUE}ℹ Deployer: $DEPLOYER${NC}"
echo ""

# Deploy Tokos Lending
echo -e "${BLUE}ℹ Deploying Tokos Lending...${NC}"
TOKOS_RESULT=$(forge create src/tokos/TokosLending.sol:TokosLending \
    --broadcast \
    --rpc-url $SOMNIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --constructor-args $DEPLOYER 2>&1)

TOKOS_ADDRESS=$(echo "$TOKOS_RESULT" | grep "Deployed to:" | awk '{print $3}')
TOKOS_TX=$(echo "$TOKOS_RESULT" | grep "Transaction hash:" | awk '{print $3}')

echo -e "${GREEN}✓ Tokos Lending deployed: $TOKOS_ADDRESS${NC}"
echo -e "  TX: $TOKOS_TX"
echo ""

# Initialize pools if token addresses exist
if [ ! -z "$WETH_ADDRESS" ] && [ ! -z "$USDC_ADDRESS" ]; then
    echo -e "${BLUE}ℹ Adding WETH pool (3% APY)...${NC}"
    WETH_POOL_TX=$(cast send $TOKOS_ADDRESS \
        "addPool(address,uint256)" \
        $WETH_ADDRESS \
        300 \
        --rpc-url $SOMNIA_RPC_URL \
        --private-key $PRIVATE_KEY 2>&1 | grep "transactionHash" | cut -d'"' -f4)
    
    echo -e "${BLUE}ℹ Adding USDC pool (5% APY)...${NC}"
    USDC_POOL_TX=$(cast send $TOKOS_ADDRESS \
        "addPool(address,uint256)" \
        $USDC_ADDRESS \
        500 \
        --rpc-url $SOMNIA_RPC_URL \
        --private-key $PRIVATE_KEY 2>&1 | grep "transactionHash" | cut -d'"' -f4)
    
    echo -e "${GREEN}✓ Pools initialized${NC}"
fi

echo ""
echo -e "${GREEN}✓ Tokos Lending deployed successfully!${NC}"
echo ""
echo "Contract address: $TOKOS_ADDRESS"
echo ""
echo -e "${YELLOW}Next: Update SomniaAddresses.sol with:${NC}"
echo "  TOKOS_LENDING = $TOKOS_ADDRESS;"
