// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockSomniaAddresses
 * @notice Mock addresses for testing environment
 * @dev Use this instead of SomniaAddresses.sol when running with mocks
 */
library MockSomniaAddresses {
    // ============================================
    // MOCK PROTOCOL ADDRESSES (FOR TESTING)
    // ============================================

    /// @notice Mock Kandel seeder for testing Elix functionality
    /// @dev Deploy MockKandelSeeder.sol to this address or update after deployment
    address public constant KANDEL_SEEDER = address(0); // Set after deployment

    /// @notice Mock vault factory for testing
    /// @dev Deploy MockVaultFactory.sol to this address or update after deployment
    address public constant VAULT_FACTORY = address(0); // Set after deployment

    /// @notice Tokos lending protocol (keep your existing address)
    address public constant TOKOS_LENDING = 0x5F9fb4Ac021Fc6dD4FFDB3257545651ac132651C;

    // ============================================
    // REAL PROTOCOL ADDRESSES (FALLBACK)
    // ============================================
    // Keep the real addresses as backup

    /// @notice Mangrove core contract (real)
    address public constant MGV = 0x13d30dF7e872660fDd5293BEe39EBd7a61C4C622;

    /// @notice Mangrove reader for querying order book state (real)
    address public constant MGV_READER = 0xe3dbF8bAB1c5D4B3386Fc05e207Bd8f91552ACc0;

    /// @notice Mangrove order contract for managing orders (real)
    address public constant MGV_ORDER = 0x6b3E0f24824be981e892ca719A16714bfd2D0Ac2;

    /// @notice Router proxy factory for creating custom routers (real)
    address public constant ROUTER_PROXY_FACTORY = 0xE82C7B1Cb8C59088Fe196E01746a930E2b168ee8;

    /// @notice Smart router for optimized trade routing (real)
    address public constant SMART_ROUTER = 0x94A07fb6E0d900c57b0a56cb30a5058AFF7dDD6b;

    /// @notice Mint helper for testing (provides test tokens) (real)
    address public constant MINT_HELPER = 0x5FD5e6B0A50E907522101518C95AfE5e86e729F1;

    // ============================================
    // REAL ADDRESSES (ORIGINAL)
    // ============================================
    // These are the original production addresses

    /// @notice Real Kandel seeder (production)
    address public constant KANDEL_SEEDER_REAL = 0x5Abc9F2f694269eb24FD27321A00445cc0E7B4c4;

    /// @notice Real vault factory (production)
    address public constant VAULT_FACTORY_REAL = 0xD7c89B9AC4f09131a962BB9527CcF26cB68cF70c;
}
