// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/tokos/TokosLending.sol";

contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract TokosLendingTest is Test {
    TokosLending public tokos;
    MockERC20 public weth;
    MockERC20 public usdc;

    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);

    uint256 constant BASE_APY_WETH = 300;
    uint256 constant BASE_APY_USDC = 500;

    function setUp() public {
        weth = new MockERC20("Wrapped ETH", "WETH");
        usdc = new MockERC20("USD Coin", "USDC");

        vm.prank(owner);
        tokos = new TokosLending(owner);

        vm.startPrank(owner);
        tokos.addPool(address(weth), BASE_APY_WETH);
        tokos.addPool(address(usdc), BASE_APY_USDC);
        vm.stopPrank();

        weth.mint(user1, 100 ether);
        usdc.mint(user1, 100000 * 1e18);
        weth.mint(user2, 50 ether);
        usdc.mint(user2, 50000 * 1e18);
    }

    function testDeployment() public view {
        assertEq(tokos.owner(), owner);

        (,, uint256 wethAPY,, bool wethActive) = tokos.getPoolInfo(address(weth));
        assertEq(wethAPY, BASE_APY_WETH);
        assertTrue(wethActive);

        (,, uint256 usdcAPY,, bool usdcActive) = tokos.getPoolInfo(address(usdc));
        assertEq(usdcAPY, BASE_APY_USDC);
        assertTrue(usdcActive);
    }

    function testGetSupportedTokens() public view {
        address[] memory tokens = tokos.getSupportedTokens();
        assertEq(tokens.length, 2);
        assertEq(tokens[0], address(weth));
        assertEq(tokens[1], address(usdc));
    }

    function testAddPoolRevertsIfAlreadyExists() public {
        vm.prank(owner);
        vm.expectRevert(TokosLending.PoolAlreadyExists.selector);
        tokos.addPool(address(weth), 100);
    }

    function testAddPoolRevertsForNonOwner() public {
        MockERC20 newToken = new MockERC20("New Token", "NEW");

        vm.prank(user1);
        vm.expectRevert();
        tokos.addPool(address(newToken), 100);
    }

    function testUpdateAPY() public {
        uint256 newAPY = 1000;

        vm.prank(owner);
        tokos.updateAPY(address(weth), newAPY);

        (,, uint256 apy,,) = tokos.getPoolInfo(address(weth));
        assertEq(apy, newAPY);
    }

    function testUpdateAPYRevertsForNonOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        tokos.updateAPY(address(weth), 1000);
    }

    function testDeposit() public {
        uint256 depositAmount = 10 ether;

        vm.startPrank(user1);
        weth.approve(address(tokos), depositAmount);
        tokos.deposit(address(weth), depositAmount);
        vm.stopPrank();

        uint256 balance = tokos.balanceOf(user1, address(weth));
        assertEq(balance, depositAmount);

        (uint256 totalDeposits,,,,) = tokos.getPoolInfo(address(weth));
        assertEq(totalDeposits, depositAmount);
    }

    function testDepositMultipleUsers() public {
        uint256 deposit1 = 10 ether;
        uint256 deposit2 = 20 ether;

        vm.startPrank(user1);
        weth.approve(address(tokos), deposit1);
        tokos.deposit(address(weth), deposit1);
        vm.stopPrank();

        vm.startPrank(user2);
        weth.approve(address(tokos), deposit2);
        tokos.deposit(address(weth), deposit2);
        vm.stopPrank();

        assertEq(tokos.balanceOf(user1, address(weth)), deposit1);
        assertEq(tokos.balanceOf(user2, address(weth)), deposit2);

        (uint256 totalDeposits,,,,) = tokos.getPoolInfo(address(weth));
        assertEq(totalDeposits, deposit1 + deposit2);
    }

    function testDepositRevertsForInactivePool() public {
        MockERC20 unsupportedToken = new MockERC20("Unsupported", "UNS");

        vm.startPrank(user1);
        unsupportedToken.mint(user1, 100 ether);
        unsupportedToken.approve(address(tokos), 10 ether);

        vm.expectRevert(TokosLending.PoolNotActive.selector);
        tokos.deposit(address(unsupportedToken), 10 ether);
        vm.stopPrank();
    }

    function testDepositRevertsForZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(TokosLending.InvalidAmount.selector);
        tokos.deposit(address(weth), 0);
    }

    function testWithdraw() public {
        uint256 depositAmount = 10 ether;
        uint256 withdrawAmount = 5 ether;

        vm.startPrank(user1);
        weth.approve(address(tokos), depositAmount);
        tokos.deposit(address(weth), depositAmount);

        tokos.withdraw(address(weth), withdrawAmount);
        vm.stopPrank();

        uint256 balance = tokos.balanceOf(user1, address(weth));
        assertApproxEqAbs(balance, depositAmount - withdrawAmount, 1e10);
    }

    function testWithdrawAll() public {
        uint256 depositAmount = 10 ether;

        vm.startPrank(user1);
        weth.approve(address(tokos), depositAmount);
        tokos.deposit(address(weth), depositAmount);

        tokos.withdraw(address(weth), 0);
        vm.stopPrank();

        uint256 balance = tokos.balanceOf(user1, address(weth));
        assertEq(balance, 0);
    }

    function testWithdrawRevertsForNoDeposit() public {
        vm.prank(user1);
        vm.expectRevert(TokosLending.NoDeposit.selector);
        tokos.withdraw(address(weth), 1 ether);
    }

    function testWithdrawRevertsForInsufficientBalance() public {
        uint256 depositAmount = 10 ether;

        vm.startPrank(user1);
        weth.approve(address(tokos), depositAmount);
        tokos.deposit(address(weth), depositAmount);

        vm.expectRevert(TokosLending.InsufficientBalance.selector);
        tokos.withdraw(address(weth), depositAmount + 1 ether);
        vm.stopPrank();
    }

    function testInterestAccrual() public {
        uint256 depositAmount = 100 ether;

        vm.startPrank(user1);
        weth.approve(address(tokos), depositAmount);
        tokos.deposit(address(weth), depositAmount);
        vm.stopPrank();

        vm.warp(block.timestamp + 365 days);

        uint256 balance = tokos.balanceOf(user1, address(weth));

        uint256 expectedInterest = (depositAmount * BASE_APY_WETH) / 10000;
        assertApproxEqAbs(balance, depositAmount + expectedInterest, 1e15);
    }

    function testClaimInterest() public {
        uint256 depositAmount = 100 ether;

        vm.startPrank(user1);
        weth.approve(address(tokos), depositAmount);
        tokos.deposit(address(weth), depositAmount);

        vm.warp(block.timestamp + 180 days);

        uint256 balanceBefore = weth.balanceOf(user1);
        tokos.claimInterest(address(weth));
        uint256 balanceAfter = weth.balanceOf(user1);

        vm.stopPrank();

        assertGt(balanceAfter, balanceBefore);
    }

    function testGetLendingAPY() public view {
        uint256 apy = tokos.getLendingAPY(address(weth));
        assertEq(apy, BASE_APY_WETH);
    }

    function testGetHealthFactor() public view {
        uint256 healthFactor = tokos.getHealthFactor(user1);
        assertEq(healthFactor, 1e18);
    }

    function testGetAvailableLiquidity() public {
        uint256 depositAmount = 10 ether;

        vm.startPrank(user1);
        weth.approve(address(tokos), depositAmount);
        tokos.deposit(address(weth), depositAmount);
        vm.stopPrank();

        uint256 liquidity = tokos.getAvailableLiquidity(address(weth));
        assertEq(liquidity, depositAmount);
    }

    function testGetUserDeposit() public {
        uint256 depositAmount = 10 ether;

        vm.startPrank(user1);
        weth.approve(address(tokos), depositAmount);
        tokos.deposit(address(weth), depositAmount);
        vm.stopPrank();

        (uint256 amount, uint256 shares,,) = tokos.getUserDeposit(user1, address(weth));
        assertEq(amount, depositAmount);
        assertEq(shares, depositAmount);
    }

    function testGetTotalValueLocked() public {
        uint256 wethDeposit = 10 ether;
        uint256 usdcDeposit = 5000 * 1e18;

        vm.startPrank(user1);
        weth.approve(address(tokos), wethDeposit);
        tokos.deposit(address(weth), wethDeposit);

        usdc.approve(address(tokos), usdcDeposit);
        tokos.deposit(address(usdc), usdcDeposit);
        vm.stopPrank();

        uint256 tvl = tokos.getTotalValueLocked();
        assertApproxEqAbs(tvl, wethDeposit + usdcDeposit, 1e10);
    }

    function testMultipleDepositWithdrawCycles() public {
        vm.startPrank(user1);
        weth.approve(address(tokos), 100 ether);

        tokos.deposit(address(weth), 10 ether);
        vm.warp(block.timestamp + 30 days);
        tokos.withdraw(address(weth), 5 ether);

        vm.warp(block.timestamp + 30 days);
        tokos.deposit(address(weth), 20 ether);
        vm.warp(block.timestamp + 60 days);

        uint256 finalBalance = tokos.balanceOf(user1, address(weth));
        vm.stopPrank();

        assertGt(finalBalance, 25 ether);
    }

    function testSharesCalculation() public {
        vm.startPrank(user1);
        weth.approve(address(tokos), 100 ether);
        tokos.deposit(address(weth), 10 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 180 days);

        vm.startPrank(user2);
        weth.approve(address(tokos), 100 ether);
        tokos.deposit(address(weth), 10 ether);
        vm.stopPrank();

        uint256 balance1 = tokos.balanceOf(user1, address(weth));
        uint256 balance2 = tokos.balanceOf(user2, address(weth));

        assertGt(balance1, balance2);
    }
}
