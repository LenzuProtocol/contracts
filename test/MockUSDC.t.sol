// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/mocks/MockUSDC.sol";

contract MockUSDCTest is Test {
    MockUSDC public usdc;

    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);

    event FaucetClaimed(address indexed user, uint256 amount);
    event Minted(address indexed to, uint256 amount);

    function setUp() public {
        vm.prank(owner);
        usdc = new MockUSDC(owner);
    }

    function testDeployment() public view {
        assertEq(usdc.name(), "Mock USD Coin");
        assertEq(usdc.symbol(), "mUSDC");
        assertEq(usdc.decimals(), 6);
        assertEq(usdc.owner(), owner);
        assertEq(usdc.totalSupply(), 10_000_000 * 1e6);
        assertEq(usdc.balanceOf(owner), 10_000_000 * 1e6);
    }

    function testConstants() public view {
        assertEq(usdc.FAUCET_AMOUNT(), 10_000 * 1e6);
        assertEq(usdc.FAUCET_COOLDOWN(), 1 hours);
    }

    function testDecimals() public view {
        assertEq(usdc.decimals(), 6);
    }

    function testFaucetClaim() public {
        vm.prank(user1);
        usdc.faucet();

        assertEq(usdc.balanceOf(user1), 10_000 * 1e6);
        assertEq(usdc.lastFaucetClaim(user1), block.timestamp);
    }

    function testFaucetClaimEmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit FaucetClaimed(user1, 10_000 * 1e6);

        vm.prank(user1);
        usdc.faucet();
    }

    function testFaucetClaimMultipleUsers() public {
        vm.prank(user1);
        usdc.faucet();

        vm.prank(user2);
        usdc.faucet();

        assertEq(usdc.balanceOf(user1), 10_000 * 1e6);
        assertEq(usdc.balanceOf(user2), 10_000 * 1e6);
    }

    function testFaucetCooldown() public {
        vm.prank(user1);
        usdc.faucet();

        vm.prank(user1);
        vm.expectRevert();
        usdc.faucet();
    }

    function testFaucetClaimAfterCooldown() public {
        vm.prank(user1);
        usdc.faucet();
        assertEq(usdc.balanceOf(user1), 10_000 * 1e6);

        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(user1);
        usdc.faucet();
        assertEq(usdc.balanceOf(user1), 20_000 * 1e6);
    }

    function testCanClaimFaucet() public {
        (bool canClaim, uint256 remainingTime) = usdc.canClaimFaucet(user1);
        assertTrue(canClaim);
        assertEq(remainingTime, 0);

        vm.prank(user1);
        usdc.faucet();

        (canClaim, remainingTime) = usdc.canClaimFaucet(user1);
        assertFalse(canClaim);
        assertEq(remainingTime, 1 hours);

        vm.warp(block.timestamp + 30 minutes);
        (canClaim, remainingTime) = usdc.canClaimFaucet(user1);
        assertFalse(canClaim);
        assertEq(remainingTime, 30 minutes);

        vm.warp(block.timestamp + 31 minutes);
        (canClaim, remainingTime) = usdc.canClaimFaucet(user1);
        assertTrue(canClaim);
        assertEq(remainingTime, 0);
    }

    function testMint() public {
        uint256 mintAmount = 50_000 * 1e6;

        vm.prank(owner);
        usdc.mint(user1, mintAmount);

        assertEq(usdc.balanceOf(user1), mintAmount);
        assertEq(usdc.totalSupply(), 10_000_000 * 1e6 + mintAmount);
    }

    function testMintEmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit Minted(user1, 25_000 * 1e6);

        vm.prank(owner);
        usdc.mint(user1, 25_000 * 1e6);
    }

    function testMintRevertsForNonOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        usdc.mint(user2, 10_000 * 1e6);
    }

    function testBurn() public {
        vm.prank(owner);
        usdc.mint(user1, 10_000 * 1e6);

        uint256 burnAmount = 3_000 * 1e6;

        vm.prank(user1);
        usdc.burn(burnAmount);

        assertEq(usdc.balanceOf(user1), 7_000 * 1e6);
        assertEq(usdc.totalSupply(), 10_000_000 * 1e6 + 7_000 * 1e6);
    }

    function testBurnRevertsForInsufficientBalance() public {
        vm.prank(user1);
        vm.expectRevert();
        usdc.burn(1_000 * 1e6);
    }

    function testBurnFrom() public {
        vm.prank(owner);
        usdc.mint(user1, 10_000 * 1e6);

        vm.prank(user1);
        usdc.approve(user2, 5_000 * 1e6);

        vm.prank(user2);
        usdc.burnFrom(user1, 3_000 * 1e6);

        assertEq(usdc.balanceOf(user1), 7_000 * 1e6);
        assertEq(usdc.allowance(user1, user2), 2_000 * 1e6);
    }

    function testBurnFromRevertsWithoutApproval() public {
        vm.prank(owner);
        usdc.mint(user1, 10_000 * 1e6);

        vm.prank(user2);
        vm.expectRevert();
        usdc.burnFrom(user1, 1_000 * 1e6);
    }

    function testTransfer() public {
        uint256 transferAmount = 50_000 * 1e6;

        vm.prank(owner);
        usdc.transfer(user1, transferAmount);

        assertEq(usdc.balanceOf(user1), transferAmount);
        assertEq(usdc.balanceOf(owner), 10_000_000 * 1e6 - transferAmount);
    }

    function testTransferRevertsForInsufficientBalance() public {
        vm.prank(user1);
        vm.expectRevert();
        usdc.transfer(user2, 1_000 * 1e6);
    }

    function testTransferFrom() public {
        vm.prank(owner);
        usdc.approve(user1, 100_000 * 1e6);

        vm.prank(user1);
        usdc.transferFrom(owner, user2, 50_000 * 1e6);

        assertEq(usdc.balanceOf(user2), 50_000 * 1e6);
        assertEq(usdc.allowance(owner, user1), 50_000 * 1e6);
    }

    function testApprove() public {
        vm.prank(owner);
        usdc.approve(user1, 500_000 * 1e6);

        assertEq(usdc.allowance(owner, user1), 500_000 * 1e6);
    }

    function testIncreaseAllowance() public {
        vm.startPrank(owner);
        usdc.approve(user1, 100_000 * 1e6);
        usdc.approve(user1, 150_000 * 1e6);
        vm.stopPrank();

        assertEq(usdc.allowance(owner, user1), 150_000 * 1e6);
    }

    function testSmallAmounts() public {
        vm.prank(owner);
        usdc.transfer(user1, 1 * 1e6);

        assertEq(usdc.balanceOf(user1), 1 * 1e6);
    }

    function testCentAmounts() public {
        vm.prank(owner);
        usdc.transfer(user1, 1e4);

        assertEq(usdc.balanceOf(user1), 1e4);
    }

    function testMicroAmounts() public {
        vm.prank(owner);
        usdc.transfer(user1, 1);

        assertEq(usdc.balanceOf(user1), 1);
    }

    function testFaucetAndTransfer() public {
        vm.prank(user1);
        usdc.faucet();

        vm.prank(user1);
        usdc.transfer(user2, 3_000 * 1e6);

        assertEq(usdc.balanceOf(user1), 7_000 * 1e6);
        assertEq(usdc.balanceOf(user2), 3_000 * 1e6);
    }

    function testMultipleFaucetClaims() public {
        vm.prank(user1);
        usdc.faucet();
        assertEq(usdc.balanceOf(user1), 10_000 * 1e6);

        vm.warp(block.timestamp + 1 hours);
        vm.prank(user1);
        usdc.faucet();
        assertEq(usdc.balanceOf(user1), 20_000 * 1e6);

        vm.warp(block.timestamp + 2 hours);
        vm.prank(user1);
        usdc.faucet();
        assertEq(usdc.balanceOf(user1), 30_000 * 1e6);
    }

    function testComplexScenario() public {
        vm.prank(user1);
        usdc.faucet();

        vm.prank(user1);
        usdc.transfer(user2, 4_000 * 1e6);

        vm.prank(user2);
        usdc.approve(user1, 2_000 * 1e6);

        vm.prank(user1);
        usdc.transferFrom(user2, owner, 1_000 * 1e6);

        assertEq(usdc.balanceOf(user1), 6_000 * 1e6);
        assertEq(usdc.balanceOf(user2), 3_000 * 1e6);
        assertEq(usdc.allowance(user2, user1), 1_000 * 1e6);
    }

    function testFaucetMintAndBurn() public {
        vm.prank(user1);
        usdc.faucet();

        uint256 initialBalance = usdc.balanceOf(user1);

        vm.prank(owner);
        usdc.mint(user1, 5_000 * 1e6);

        assertEq(usdc.balanceOf(user1), initialBalance + 5_000 * 1e6);

        vm.prank(user1);
        usdc.burn(3_000 * 1e6);

        assertEq(usdc.balanceOf(user1), initialBalance + 2_000 * 1e6);
    }

    function testFuzzMint(uint256 amount) public {
        amount = bound(amount, 0, 1_000_000_000 * 1e6);

        vm.prank(owner);
        usdc.mint(user1, amount);

        assertEq(usdc.balanceOf(user1), amount);
    }

    function testFuzzTransfer(uint256 amount) public {
        amount = bound(amount, 0, usdc.balanceOf(owner));

        vm.prank(owner);
        usdc.transfer(user1, amount);

        assertEq(usdc.balanceOf(user1), amount);
    }

    function testFuzzBurn(uint256 mintAmount, uint256 burnAmount) public {
        mintAmount = bound(mintAmount, 1, 1_000_000_000 * 1e6);
        burnAmount = bound(burnAmount, 0, mintAmount);

        vm.prank(owner);
        usdc.mint(user1, mintAmount);

        vm.prank(user1);
        usdc.burn(burnAmount);

        assertEq(usdc.balanceOf(user1), mintAmount - burnAmount);
    }

    function testFuzzApproveAndTransferFrom(uint256 approveAmount, uint256 transferAmount) public {
        approveAmount = bound(approveAmount, 0, usdc.balanceOf(owner));
        transferAmount = bound(transferAmount, 0, approveAmount);

        vm.prank(owner);
        usdc.approve(user1, approveAmount);

        vm.prank(user1);
        usdc.transferFrom(owner, user2, transferAmount);

        assertEq(usdc.balanceOf(user2), transferAmount);
        assertEq(usdc.allowance(owner, user1), approveAmount - transferAmount);
    }

    function testZeroTransfer() public {
        vm.prank(owner);
        usdc.transfer(user1, 0);

        assertEq(usdc.balanceOf(user1), 0);
    }

    function testZeroApprove() public {
        vm.prank(owner);
        usdc.approve(user1, 0);

        assertEq(usdc.allowance(owner, user1), 0);
    }

    function testSelfTransfer() public {
        uint256 balanceBefore = usdc.balanceOf(owner);

        vm.prank(owner);
        usdc.transfer(owner, 1_000 * 1e6);

        assertEq(usdc.balanceOf(owner), balanceBefore);
    }
}
