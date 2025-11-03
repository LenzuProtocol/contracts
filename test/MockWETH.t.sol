// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/mocks/MockWETH.sol";

contract MockWETHTest is Test {
    MockWETH public weth;

    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);

    event FaucetClaimed(address indexed user, uint256 amount);
    event Minted(address indexed to, uint256 amount);

    function setUp() public {
        vm.prank(owner);
        weth = new MockWETH(owner);
    }

    function testDeployment() public view {
        assertEq(weth.name(), "Mock Wrapped ETH");
        assertEq(weth.symbol(), "mWETH");
        assertEq(weth.decimals(), 18);
        assertEq(weth.owner(), owner);
        assertEq(weth.totalSupply(), 1_000_000 ether);
        assertEq(weth.balanceOf(owner), 1_000_000 ether);
    }

    function testConstants() public view {
        assertEq(weth.FAUCET_AMOUNT(), 10 ether);
        assertEq(weth.FAUCET_COOLDOWN(), 1 hours);
    }

    function testFaucetClaim() public {
        vm.prank(user1);
        weth.faucet();

        assertEq(weth.balanceOf(user1), 10 ether);
        assertEq(weth.lastFaucetClaim(user1), block.timestamp);
    }

    function testFaucetClaimEmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit FaucetClaimed(user1, 10 ether);

        vm.prank(user1);
        weth.faucet();
    }

    function testFaucetClaimMultipleUsers() public {
        vm.prank(user1);
        weth.faucet();

        vm.prank(user2);
        weth.faucet();

        assertEq(weth.balanceOf(user1), 10 ether);
        assertEq(weth.balanceOf(user2), 10 ether);
    }

    function testFaucetCooldown() public {
        vm.prank(user1);
        weth.faucet();

        vm.prank(user1);
        vm.expectRevert();
        weth.faucet();
    }

    function testFaucetClaimAfterCooldown() public {
        vm.prank(user1);
        weth.faucet();
        assertEq(weth.balanceOf(user1), 10 ether);

        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(user1);
        weth.faucet();
        assertEq(weth.balanceOf(user1), 20 ether);
    }

    function testCanClaimFaucet() public {
        (bool canClaim, uint256 remainingTime) = weth.canClaimFaucet(user1);
        assertTrue(canClaim);
        assertEq(remainingTime, 0);

        vm.prank(user1);
        weth.faucet();

        (canClaim, remainingTime) = weth.canClaimFaucet(user1);
        assertFalse(canClaim);
        assertEq(remainingTime, 1 hours);

        vm.warp(block.timestamp + 30 minutes);
        (canClaim, remainingTime) = weth.canClaimFaucet(user1);
        assertFalse(canClaim);
        assertEq(remainingTime, 30 minutes);

        vm.warp(block.timestamp + 31 minutes);
        (canClaim, remainingTime) = weth.canClaimFaucet(user1);
        assertTrue(canClaim);
        assertEq(remainingTime, 0);
    }

    function testMint() public {
        uint256 mintAmount = 100 ether;

        vm.prank(owner);
        weth.mint(user1, mintAmount);

        assertEq(weth.balanceOf(user1), mintAmount);
        assertEq(weth.totalSupply(), 1_000_000 ether + mintAmount);
    }

    function testMintEmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit Minted(user1, 50 ether);

        vm.prank(owner);
        weth.mint(user1, 50 ether);
    }

    function testMintRevertsForNonOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        weth.mint(user2, 100 ether);
    }

    function testBurn() public {
        vm.prank(owner);
        weth.mint(user1, 100 ether);

        uint256 burnAmount = 30 ether;

        vm.prank(user1);
        weth.burn(burnAmount);

        assertEq(weth.balanceOf(user1), 70 ether);
        assertEq(weth.totalSupply(), 1_000_000 ether + 70 ether);
    }

    function testBurnRevertsForInsufficientBalance() public {
        vm.prank(user1);
        vm.expectRevert();
        weth.burn(100 ether);
    }

    function testDeposit() public {
        uint256 depositAmount = 5 ether;

        vm.deal(user1, depositAmount);

        vm.prank(user1);
        weth.deposit{value: depositAmount}();

        assertEq(weth.balanceOf(user1), depositAmount);
        assertEq(address(weth).balance, depositAmount);
    }

    function testWithdraw() public {
        uint256 depositAmount = 5 ether;

        vm.deal(user1, depositAmount);
        vm.prank(user1);
        weth.deposit{value: depositAmount}();

        uint256 balanceBefore = user1.balance;

        vm.prank(user1);
        weth.withdraw(depositAmount);

        assertEq(weth.balanceOf(user1), 0);
        assertEq(user1.balance, balanceBefore + depositAmount);
    }

    function testWithdrawRevertsForInsufficientBalance() public {
        vm.prank(user1);
        vm.expectRevert();
        weth.withdraw(1 ether);
    }

    function testReceiveETH() public {
        uint256 sendAmount = 3 ether;

        vm.deal(user1, sendAmount);

        vm.prank(user1);
        (bool success,) = address(weth).call{value: sendAmount}("");

        assertTrue(success);
        assertEq(weth.balanceOf(user1), sendAmount);
        assertEq(address(weth).balance, sendAmount);
    }

    function testTransfer() public {
        vm.prank(owner);
        weth.transfer(user1, 100 ether);

        assertEq(weth.balanceOf(user1), 100 ether);
        assertEq(weth.balanceOf(owner), 1_000_000 ether - 100 ether);
    }

    function testTransferFrom() public {
        vm.prank(owner);
        weth.approve(user1, 100 ether);

        vm.prank(user1);
        weth.transferFrom(owner, user2, 50 ether);

        assertEq(weth.balanceOf(user2), 50 ether);
        assertEq(weth.allowance(owner, user1), 50 ether);
    }

    function testApprove() public {
        vm.prank(owner);
        weth.approve(user1, 500 ether);

        assertEq(weth.allowance(owner, user1), 500 ether);
    }

    function testFaucetAndTransfer() public {
        vm.prank(user1);
        weth.faucet();

        vm.prank(user1);
        weth.transfer(user2, 3 ether);

        assertEq(weth.balanceOf(user1), 7 ether);
        assertEq(weth.balanceOf(user2), 3 ether);
    }

    function testDepositAndBurn() public {
        uint256 amount = 5 ether;

        vm.deal(user1, amount);
        vm.prank(user1);
        weth.deposit{value: amount}();

        vm.prank(user1);
        weth.burn(2.5 ether);

        assertEq(weth.balanceOf(user1), 2.5 ether);
    }

    function testMultipleFaucetClaims() public {
        vm.prank(user1);
        weth.faucet();
        assertEq(weth.balanceOf(user1), 10 ether);

        vm.warp(block.timestamp + 1 hours);
        vm.prank(user1);
        weth.faucet();
        assertEq(weth.balanceOf(user1), 20 ether);

        vm.warp(block.timestamp + 2 hours);
        vm.prank(user1);
        weth.faucet();
        assertEq(weth.balanceOf(user1), 30 ether);
    }

    function testFuzzMint(uint256 amount) public {
        vm.assume(amount < type(uint256).max - weth.totalSupply());

        vm.prank(owner);
        weth.mint(user1, amount);

        assertEq(weth.balanceOf(user1), amount);
    }

    function testFuzzTransfer(uint256 amount) public {
        amount = bound(amount, 0, weth.balanceOf(owner));

        vm.prank(owner);
        weth.transfer(user1, amount);

        assertEq(weth.balanceOf(user1), amount);
    }

    function testFuzzDeposit(uint96 amount) public {
        vm.deal(user1, amount);

        vm.prank(user1);
        weth.deposit{value: amount}();

        assertEq(weth.balanceOf(user1), amount);
    }
}
