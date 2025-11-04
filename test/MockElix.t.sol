// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/mocks/MockWETH.sol";
import "../src/mocks/MockUSDC.sol";
import "../src/mocks/MockKandelSeeder.sol";
import "../src/mocks/MockVaultFactory.sol";
// import "../src/MockAutonomousLiquidityManager.sol"; // Removed
import "../src/tokos/TokosLending.sol";
import "../src/interfaces/IKandelSeeder.sol";

/**
 * @title MockElixTest
 * @notice Test suite for mock Elix functionality
 */
// COMMENTED OUT - Contract depends on removed MockAutonomousLiquidityManager
/*
contract MockElixTest is Test {
    MockWETH weth;
    MockUSDC usdc;
    MockKandelSeeder kandelSeeder;
    MockVaultFactory vaultFactory;
    TokosLending tokosLending;
    // MockAutonomousLiquidityManager manager;
    
    address owner = address(0x123);
    uint256 constant INITIAL_BALANCE = 100000 * 1e18; // 100k tokens

    function setUp() public {
        // Deploy all contracts
        weth = new MockWETH(owner);
        usdc = new MockUSDC(owner);
        kandelSeeder = new MockKandelSeeder();
        vaultFactory = new MockVaultFactory();
        tokosLending = new TokosLending(owner);
        manager = new MockAutonomousLiquidityManager(owner);

        // Setup everything as owner
        vm.startPrank(owner);
        
        // Configure manager
        manager.setAssets(address(weth), address(usdc));
        manager.setProtocolAddresses(
            address(kandelSeeder),
            address(vaultFactory),
            address(tokosLending)
        );
        
        // Set up Tokos lending pools
        tokosLending.addPool(address(weth), 300); // 3% APY
        tokosLending.addPool(address(usdc), 500); // 5% APY

        // Mint tokens
        weth.mint(owner, INITIAL_BALANCE);
        usdc.mint(owner, INITIAL_BALANCE);
        
        // Transfer tokens to manager
        weth.transfer(address(manager), 50000 * 1e18);
        usdc.transfer(address(manager), 50000 * 1e18);
        
        vm.stopPrank();
    }

    function testKandelProvisioning() public {
        console.log("Testing Kandel provisioning...");
        
        uint256 wethAmount = 1000 * 1e18; // 1k WETH
        uint256 usdcAmount = 1000 * 1e18; // 1k USDC
        
        // Create Kandel parameters
        KandelParams memory params = KandelParams({
            base: address(weth),
            quote: address(usdc),
            spread: 50, // 0.5%
            pricePoints: 10,
            stepSize: 100
        });

        // Get initial balances
        (uint256 initialWeth, uint256 initialUsdc) = manager.getContractBalances();
        console.log("Initial WETH:", initialWeth / 1e18);
        console.log("Initial USDC:", initialUsdc / 1e18);

        // Provision to Elix
        vm.prank(owner);
        manager.provisionToElix(wethAmount, usdcAmount, params);

        // Check state changes
        assertTrue(manager.isInElix(), "Should be in Elix");
        assertFalse(manager.isInTokos(), "Should not be in Tokos");
        assertTrue(manager.kandelInstance() != address(0), "Kandel instance should exist");
        
        console.log("Kandel instance deployed at:", manager.kandelInstance());
        console.log("Kandel provisioning successful!");
    }

    function testTokosProvisioning() public {
        console.log("Testing Tokos provisioning...");
        
        uint256 wethAmount = 1000 * 1e18; // 1k WETH
        uint256 usdcAmount = 1000 * 1e18; // 1k USDC

        // Get initial balances
        (uint256 initialWeth, uint256 initialUsdc) = manager.getContractBalances();
        console.log("Initial WETH:", initialWeth / 1e18);
        console.log("Initial USDC:", initialUsdc / 1e18);

        // Provision to Tokos
        vm.prank(owner);
        manager.provisionToTokos(wethAmount, usdcAmount);

        // Check state changes
        assertFalse(manager.isInElix(), "Should not be in Elix");
        assertTrue(manager.isInTokos(), "Should be in Tokos");
        
        console.log("Tokos provisioning successful!");
    }

    function testElixToTokosSwitch() public {
        console.log("Testing Elix to Tokos switch...");
        
        uint256 amount = 1000 * 1e18;
        
        // First provision to Elix
        KandelParams memory params = KandelParams({
            base: address(weth),
            quote: address(usdc),
            spread: 50,
            pricePoints: 10,
            stepSize: 100
        });

        vm.prank(owner);
        manager.provisionToElix(amount, amount, params);
        
        assertTrue(manager.isInElix(), "Should be in Elix");
        address kandelAddr = manager.kandelInstance();
        assertTrue(kandelAddr != address(0), "Kandel should exist");

        // Then switch to Tokos
        vm.prank(owner);
        manager.provisionToTokos(amount / 2, amount / 2);

        // Check state
        assertFalse(manager.isInElix(), "Should not be in Elix after switch");
        assertTrue(manager.isInTokos(), "Should be in Tokos after switch");
        
        console.log("Elix to Tokos switch successful!");
    }

    function testEmergencyWithdraw() public {
        console.log("Testing emergency withdraw...");
        
        uint256 amount = 1000 * 1e18;
        
        // Provision to both protocols
        KandelParams memory params = KandelParams({
            base: address(weth),
            quote: address(usdc),
            spread: 50,
            pricePoints: 10,
            stepSize: 100
        });

        vm.startPrank(owner);
        manager.provisionToElix(amount, amount, params);
        manager.provisionToTokos(amount, amount);
        vm.stopPrank();

        // Get balances before emergency withdraw
        (uint256 beforeWeth, uint256 beforeUsdc) = manager.getContractBalances();
        
        // Emergency withdraw
        vm.prank(owner);
        manager.emergencyWithdraw();

        // Check state
        assertFalse(manager.isInElix(), "Should not be in Elix after emergency");
        assertFalse(manager.isInTokos(), "Should not be in Tokos after emergency");
        
        // Check balances increased (funds returned)
        (uint256 afterWeth, uint256 afterUsdc) = manager.getContractBalances();
        console.log("WETH recovered:", afterWeth / 1e18);
        console.log("USDC recovered:", afterUsdc / 1e18);
        
        console.log("Emergency withdraw successful!");
    }

    function testPositionSummary() public {
        console.log("Testing position summary...");
        
        uint256 amount = 1000 * 1e18;
        
        // Get initial summary
        (
            uint256 contractWeth,
            uint256 contractUsdc,
            uint256 vaultWeth,
            uint256 vaultUsdc,
            bool inElix,
            bool inTokos
        ) = manager.getPositionSummary();
        
        console.log("Initial contract WETH:", contractWeth / 1e18);
        console.log("Initial contract USDC:", contractUsdc / 1e18);
        assertFalse(inElix, "Should not be in Elix initially");
        assertFalse(inTokos, "Should not be in Tokos initially");
        
        // Provision to Elix
        KandelParams memory params = KandelParams({
            base: address(weth),
            quote: address(usdc),
            spread: 50,
            pricePoints: 10,
            stepSize: 100
        });

        vm.prank(owner);
        manager.provisionToElix(amount, amount, params);

        // Check updated summary
        (contractWeth, contractUsdc, vaultWeth, vaultUsdc, inElix, inTokos) = manager.getPositionSummary();
        
        console.log("After Elix - contract WETH:", contractWeth / 1e18);
        console.log("After Elix - vault WETH:", vaultWeth / 1e18);
        assertTrue(inElix, "Should be in Elix");
        assertFalse(inTokos, "Should not be in Tokos");
        
        console.log("Position summary working correctly!");
    }

    function testProtocolAddresses() public {
        console.log("Testing protocol addresses...");
        
        (address _kandelSeeder, address _vaultFactory, address _tokosLending) = manager.getProtocolAddresses();
        
        assertEq(_kandelSeeder, address(kandelSeeder), "Kandel seeder should match");
        assertEq(_vaultFactory, address(vaultFactory), "Vault factory should match");
        assertEq(_tokosLending, address(tokosLending), "Tokos lending should match");
        
        console.log("Kandel Seeder:", _kandelSeeder);
        console.log("Vault Factory:", _vaultFactory);
        console.log("Tokos Lending:", _tokosLending);
        
        console.log("Protocol addresses configured correctly!");
    }
}*/
