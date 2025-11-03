// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SomniaAddresses
 * @notice Centralized registry of protocol addresses on Somnia testnet
 * @dev All Elix (Mangrove) protocol addresses for easy reference
 */
library SomniaAddresses {
    // ============================================
    // ELIX (MANGROVE) PROTOCOL ADDRESSES
    // ============================================

    /// @notice Mangrove core contract
    address public constant MGV = 0x13d30dF7e872660fDd5293BEe39EBd7a61C4C622;

    /// @notice Mangrove reader for querying order book state
    address public constant MGV_READER = 0xe3dbF8bAB1c5D4B3386Fc05e207Bd8f91552ACc0;

    /// @notice Mangrove order contract for managing orders
    address public constant MGV_ORDER = 0x6b3E0f24824be981e892ca719A16714bfd2D0Ac2;

    /// @notice Router proxy factory for creating custom routers
    address public constant ROUTER_PROXY_FACTORY = 0xE82C7B1Cb8C59088Fe196E01746a930E2b168ee8;

    /// @notice Smart router for optimized trade routing
    address public constant SMART_ROUTER = 0x94A07fb6E0d900c57b0a56cb30a5058AFF7dDD6b;

    /// @notice Mint helper for testing (provides test tokens)
    address public constant MINT_HELPER = 0x5FD5e6B0A50E907522101518C95AfE5e86e729F1;

    /// @notice Vault factory for creating strategy vaults
    address public constant VAULT_FACTORY = 0xD7c89B9AC4f09131a962BB9527CcF26cB68cF70c;

    /// @notice Kandel seeder for deploying market-making strategies
    address public constant KANDEL_SEEDER = 0x5Abc9F2f694269eb24FD27321A00445cc0E7B4c4;

    // ============================================
    // TOKOS LENDING PROTOCOL (TO BE DEPLOYED)
    // ============================================

    /// @notice Tokos lending protocol main contract
    address public constant TOKOS_LENDING = 0x5F9fb4Ac021Fc6dD4FFDB3257545651ac132651C;
}
