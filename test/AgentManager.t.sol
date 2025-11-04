// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AgentManager.sol";
import "../src/mocks/MockWETH.sol";
import "../src/mocks/MockUSDC.sol";
import "../src/tokos/TokosLending.sol";
import "../src/mocks/MockKandelSeeder.sol";
import "../src/mocks/MockVaultFactory.sol";

contract AgentManagerTest is Test {
    AgentManager public manager;
    MockWETH public weth;
    MockUSDC public usdc;
    TokosLending public tokos;
    MockKandelSeeder public kandelSeeder;
    MockVaultFactory public vaultFactory;

    address public owner = address(0x1);
    address public agent = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);

    uint256 public constant DEPOSIT_AMOUNT_WETH = 10 ether;
    uint256 public constant DEPOSIT_AMOUNT_USDC = 10000e6;

    function setUp() public {
        // Deploy tokens
        weth = new MockWETH(owner);
        usdc = new MockUSDC(owner);

        // Deploy supporting contracts
        tokos = new TokosLending(owner);
        kandelSeeder = new MockKandelSeeder();
        vaultFactory = new MockVaultFactory();

        // Deploy main contract
        manager = new AgentManager(owner);

        // Configure the manager
        vm.startPrank(owner);
        manager.setAssets(address(weth), address(usdc));
        manager.setProtocolAddresses(address(kandelSeeder), address(vaultFactory), address(tokos));
        manager.setAgent(agent);
        vm.stopPrank();

        // Add pools to Tokos
        vm.startPrank(owner);
        tokos.addPool(address(weth), 500); // 5% APY
        tokos.addPool(address(usdc), 300); // 3% APY
        vm.stopPrank();

        // Mint tokens to users (as owner)
        vm.startPrank(owner);
        weth.mint(user1, DEPOSIT_AMOUNT_WETH * 2);
        usdc.mint(user1, DEPOSIT_AMOUNT_USDC * 2);
        weth.mint(user2, DEPOSIT_AMOUNT_WETH);
        usdc.mint(user2, DEPOSIT_AMOUNT_USDC);
        vm.stopPrank();

        // Approve manager to spend user tokens
        vm.prank(user1);
        weth.approve(address(manager), type(uint256).max);
        vm.prank(user1);
        usdc.approve(address(manager), type(uint256).max);

        vm.prank(user2);
        weth.approve(address(manager), type(uint256).max);
        vm.prank(user2);
        usdc.approve(address(manager), type(uint256).max);
    }

    // ===========================
    // CONFIGURATION TESTS
    // ===========================

    function testSetAgent() public {
        address newAgent = address(0x5);

        vm.prank(owner);
        manager.setAgent(newAgent);

        assertEq(manager.agent(), newAgent);
    }

    function testSetAgentRevertsForNonOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        manager.setAgent(address(0x5));
    }

    function testSetAssets() public {
        address newWeth = address(0x6);
        address newUsdc = address(0x7);

        vm.prank(owner);
        manager.setAssets(newWeth, newUsdc);

        assertEq(manager.WETH(), newWeth);
        assertEq(manager.USDC(), newUsdc);
    }

    // ===========================
    // USER DEPOSIT TESTS
    // ===========================

    function testDepositWETH() public {
        uint256 initialBalance = weth.balanceOf(user1);

        vm.prank(user1);
        manager.depositWETH(DEPOSIT_AMOUNT_WETH);

        // Check user deposit tracking
        (uint256 userWeth, uint256 userUsdc) = manager.getUserBalance(user1);
        assertEq(userWeth, DEPOSIT_AMOUNT_WETH);
        assertEq(userUsdc, 0);

        // Check total deposits
        assertEq(manager.totalWethDeposits(), DEPOSIT_AMOUNT_WETH);
        assertEq(manager.totalUsdcDeposits(), 0);

        // Check token transfer
        assertEq(weth.balanceOf(user1), initialBalance - DEPOSIT_AMOUNT_WETH);
        assertEq(weth.balanceOf(address(manager)), DEPOSIT_AMOUNT_WETH);
    }

    function testDepositUSDC() public {
        uint256 initialBalance = usdc.balanceOf(user1);

        vm.prank(user1);
        manager.depositUSDC(DEPOSIT_AMOUNT_USDC);

        // Check user deposit tracking
        (uint256 userWeth, uint256 userUsdc) = manager.getUserBalance(user1);
        assertEq(userWeth, 0);
        assertEq(userUsdc, DEPOSIT_AMOUNT_USDC);

        // Check total deposits
        assertEq(manager.totalWethDeposits(), 0);
        assertEq(manager.totalUsdcDeposits(), DEPOSIT_AMOUNT_USDC);

        // Check token transfer
        assertEq(usdc.balanceOf(user1), initialBalance - DEPOSIT_AMOUNT_USDC);
        assertEq(usdc.balanceOf(address(manager)), DEPOSIT_AMOUNT_USDC);
    }

    function testMultipleUsersDeposit() public {
        // User1 deposits
        vm.prank(user1);
        manager.depositWETH(DEPOSIT_AMOUNT_WETH);

        vm.prank(user1);
        manager.depositUSDC(DEPOSIT_AMOUNT_USDC);

        // User2 deposits
        vm.prank(user2);
        manager.depositWETH(DEPOSIT_AMOUNT_WETH / 2);

        // Check individual balances
        (uint256 user1Weth, uint256 user1Usdc) = manager.getUserBalance(user1);
        (uint256 user2Weth, uint256 user2Usdc) = manager.getUserBalance(user2);

        assertEq(user1Weth, DEPOSIT_AMOUNT_WETH);
        assertEq(user1Usdc, DEPOSIT_AMOUNT_USDC);
        assertEq(user2Weth, DEPOSIT_AMOUNT_WETH / 2);
        assertEq(user2Usdc, 0);

        // Check totals
        assertEq(manager.totalWethDeposits(), DEPOSIT_AMOUNT_WETH + DEPOSIT_AMOUNT_WETH / 2);
        assertEq(manager.totalUsdcDeposits(), DEPOSIT_AMOUNT_USDC);
    }

    function testDepositRevertsForZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert("Amount must be greater than 0");
        manager.depositWETH(0);

        vm.prank(user1);
        vm.expectRevert("Amount must be greater than 0");
        manager.depositUSDC(0);
    }

    // ===========================
    // USER WITHDRAW TESTS
    // ===========================

    function testWithdrawWETH() public {
        // First deposit
        vm.prank(user1);
        manager.depositWETH(DEPOSIT_AMOUNT_WETH);

        uint256 withdrawAmount = DEPOSIT_AMOUNT_WETH / 2;
        uint256 initialBalance = weth.balanceOf(user1);

        // Withdraw
        vm.prank(user1);
        manager.withdrawWETH(withdrawAmount);

        // Check user balance tracking
        (uint256 userWeth,) = manager.getUserBalance(user1);
        assertEq(userWeth, DEPOSIT_AMOUNT_WETH - withdrawAmount);

        // Check token transfer
        assertEq(weth.balanceOf(user1), initialBalance + withdrawAmount);
        assertEq(weth.balanceOf(address(manager)), DEPOSIT_AMOUNT_WETH - withdrawAmount);

        // Check totals
        assertEq(manager.totalWethDeposits(), DEPOSIT_AMOUNT_WETH - withdrawAmount);
    }

    function testWithdrawRevertsForInsufficientBalance() public {
        vm.prank(user1);
        manager.depositWETH(DEPOSIT_AMOUNT_WETH);

        vm.prank(user1);
        vm.expectRevert("Insufficient user balance");
        manager.withdrawWETH(DEPOSIT_AMOUNT_WETH + 1);
    }

    function testWithdrawRevertsWhenInStrategy() public {
        // Deposit first
        vm.prank(user1);
        manager.depositWETH(DEPOSIT_AMOUNT_WETH);
        vm.prank(user1);
        manager.depositUSDC(DEPOSIT_AMOUNT_USDC);

        // Agent provisions to Tokos
        vm.prank(agent);
        manager.provisionToTokos(DEPOSIT_AMOUNT_WETH, DEPOSIT_AMOUNT_USDC);

        // User tries to withdraw while in strategy
        vm.prank(user1);
        vm.expectRevert("Cannot withdraw during active strategy");
        manager.withdrawWETH(DEPOSIT_AMOUNT_WETH);
    }

    // ===========================
    // AGENT PROVISIONING TESTS
    // ===========================

    function testAgentProvisionToTokos() public {
        // Users deposit
        vm.prank(user1);
        manager.depositWETH(DEPOSIT_AMOUNT_WETH);
        vm.prank(user1);
        manager.depositUSDC(DEPOSIT_AMOUNT_USDC);

        // Agent provisions to Tokos
        vm.prank(agent);
        manager.provisionToTokos(DEPOSIT_AMOUNT_WETH, DEPOSIT_AMOUNT_USDC);

        // Check contract state
        assertTrue(manager.isInTokos());
        assertFalse(manager.isInElix());

        // Check position summary
        (uint256 contractWeth, uint256 contractUsdc,,, bool inElix, bool inTokos) = manager.getPositionSummary();
        assertTrue(inTokos);
        assertFalse(inElix);

        // Tokens should be in Tokos now (contract balance should be 0 for available funds)
        // Note: In real Tokos, tokens would be transferred to Tokos contract
    }

    function testProvisionRevertsForNonAgent() public {
        vm.prank(user1);
        manager.depositWETH(DEPOSIT_AMOUNT_WETH);

        vm.prank(user1);
        vm.expectRevert("UnauthorizedAgent");
        manager.provisionToTokos(DEPOSIT_AMOUNT_WETH, 0);
    }

    function testOwnerCanAlsoProvision() public {
        vm.prank(user1);
        manager.depositWETH(DEPOSIT_AMOUNT_WETH);

        // Owner should also be able to provision
        vm.prank(owner);
        manager.provisionToTokos(DEPOSIT_AMOUNT_WETH, 0);

        assertTrue(manager.isInTokos());
    }

    function testEmergencyWithdraw() public {
        // Users deposit
        vm.prank(user1);
        manager.depositWETH(DEPOSIT_AMOUNT_WETH);
        vm.prank(user1);
        manager.depositUSDC(DEPOSIT_AMOUNT_USDC);

        // Agent provisions to Tokos
        vm.prank(agent);
        manager.provisionToTokos(DEPOSIT_AMOUNT_WETH, DEPOSIT_AMOUNT_USDC);

        assertTrue(manager.isInTokos());

        // Emergency withdraw
        vm.prank(agent);
        manager.emergencyWithdraw();

        // Should be out of all strategies
        assertFalse(manager.isInTokos());
        assertFalse(manager.isInElix());
    }

    // ===========================
    // VIEW FUNCTION TESTS
    // ===========================

    function testGetContractBalances() public {
        vm.prank(user1);
        manager.depositWETH(DEPOSIT_AMOUNT_WETH);
        vm.prank(user1);
        manager.depositUSDC(DEPOSIT_AMOUNT_USDC);

        (uint256 wethBalance, uint256 usdcBalance) = manager.getContractBalances();
        assertEq(wethBalance, DEPOSIT_AMOUNT_WETH);
        assertEq(usdcBalance, DEPOSIT_AMOUNT_USDC);
    }

    function testGetTokosAPY() public {
        uint256 wethApy = manager.getTokosAPY(address(weth));
        uint256 usdcApy = manager.getTokosAPY(address(usdc));

        assertEq(wethApy, 500); // 5% APY
        assertEq(usdcApy, 300); // 3% APY
    }

    function testGetProtocolAddresses() public {
        (address kandelSeederAddr, address vaultFactoryAddr, address tokosAddr) = manager.getProtocolAddresses();

        assertEq(kandelSeederAddr, address(kandelSeeder));
        assertEq(vaultFactoryAddr, address(vaultFactory));
        assertEq(tokosAddr, address(tokos));
    }

    // ===========================
    // INTEGRATION TESTS
    // ===========================

    function testFullDepositToTokosFlow() public {
        // 1. Multiple users deposit
        vm.prank(user1);
        manager.depositWETH(DEPOSIT_AMOUNT_WETH);

        vm.prank(user2);
        manager.depositUSDC(DEPOSIT_AMOUNT_USDC);

        // 2. Check total deposits
        assertEq(manager.totalWethDeposits(), DEPOSIT_AMOUNT_WETH);
        assertEq(manager.totalUsdcDeposits(), DEPOSIT_AMOUNT_USDC);

        // 3. Agent provisions to Tokos
        vm.prank(agent);
        manager.provisionToTokos(DEPOSIT_AMOUNT_WETH / 2, DEPOSIT_AMOUNT_USDC / 2);

        // 4. Contract should be in Tokos
        assertTrue(manager.isInTokos());

        // 5. Agent can emergency withdraw
        vm.prank(agent);
        manager.emergencyWithdraw();

        // 6. Users can now withdraw (after strategies are inactive)
        vm.prank(user1);
        manager.withdrawWETH(DEPOSIT_AMOUNT_WETH);

        vm.prank(user2);
        manager.withdrawUSDC(DEPOSIT_AMOUNT_USDC);

        // 7. Check final state
        (uint256 user1Weth, uint256 user1Usdc) = manager.getUserBalance(user1);
        (uint256 user2Weth, uint256 user2Usdc) = manager.getUserBalance(user2);

        assertEq(user1Weth, 0);
        assertEq(user1Usdc, 0);
        assertEq(user2Weth, 0);
        assertEq(user2Usdc, 0);
    }
}
