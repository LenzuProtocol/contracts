// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AutonomousLiquidityManager.sol";
import "../src/interfaces/IKandelSeeder.sol";

contract MockERC20 is Test {
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

contract AutonomousLiquidityManagerTest is Test {
    AutonomousLiquidityManager public manager;
    MockERC20 public weth;
    MockERC20 public usdc;

    address public owner = address(0x1);
    address public nonOwner = address(0x2);

    function setUp() public {
        weth = new MockERC20("Wrapped ETH", "WETH");
        usdc = new MockERC20("USD Coin", "USDC");

        vm.prank(owner);
        manager = new AutonomousLiquidityManager(owner);

        vm.prank(owner);
        manager.setAssets(address(weth), address(usdc));

        weth.mint(address(manager), 100 ether);
        usdc.mint(address(manager), 100000 * 1e18);
    }

    function testDeployment() public view {
        assertEq(manager.owner(), owner);
        assertEq(manager.WETH(), address(weth));
        assertEq(manager.USDC(), address(usdc));
        assertFalse(manager.isInElix());
        assertFalse(manager.isInTokos());
    }

    function testSetAssets() public {
        vm.prank(owner);
        AutonomousLiquidityManager newManager = new AutonomousLiquidityManager(owner);

        MockERC20 newWeth = new MockERC20("New WETH", "WETH");
        MockERC20 newUsdc = new MockERC20("New USDC", "USDC");

        vm.prank(owner);
        newManager.setAssets(address(newWeth), address(newUsdc));

        assertEq(newManager.WETH(), address(newWeth));
        assertEq(newManager.USDC(), address(newUsdc));
    }

    function testSetAssetsRevertsForNonOwner() public {
        MockERC20 newWeth = new MockERC20("New WETH", "WETH");
        MockERC20 newUsdc = new MockERC20("New USDC", "USDC");

        vm.prank(nonOwner);
        vm.expectRevert();
        manager.setAssets(address(newWeth), address(newUsdc));
    }

    function testSetAssetsRevertsForZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(AutonomousLiquidityManager.InvalidAddress.selector);
        manager.setAssets(address(0), address(usdc));
    }

    function testGetContractBalances() public view {
        (uint256 wethBalance, uint256 usdcBalance) = manager.getContractBalances();
        assertEq(wethBalance, 100 ether);
        assertEq(usdcBalance, 100000 * 1e18);
    }

    function testGetVaultBalances() public view {
        (uint256 wethBalance, uint256 usdcBalance) = manager.getVaultBalances();
        assertEq(wethBalance, 0);
        assertEq(usdcBalance, 0);
    }

    function testGetPositionSummary() public view {
        (uint256 contractWeth, uint256 contractUsdc, uint256 vaultWeth, uint256 vaultUsdc, bool inElix, bool inTokos) =
            manager.getPositionSummary();

        assertEq(contractWeth, 100 ether);
        assertEq(contractUsdc, 100000 * 1e18);
        assertEq(vaultWeth, 0);
        assertEq(vaultUsdc, 0);
        assertFalse(inElix);
        assertFalse(inTokos);
    }

    function testRescueTokens() public {
        uint256 rescueAmount = 10 ether;

        vm.prank(owner);
        manager.rescueTokens(address(weth), rescueAmount);

        assertEq(weth.balanceOf(owner), rescueAmount);
        assertEq(weth.balanceOf(address(manager)), 100 ether - rescueAmount);
    }

    function testRescueTokensRevertsForNonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        manager.rescueTokens(address(weth), 10 ether);
    }

    function testReceiveETH() public {
        uint256 ethAmount = 1 ether;

        vm.deal(owner, ethAmount);
        vm.prank(owner);
        (bool success,) = address(manager).call{value: ethAmount}("");

        assertTrue(success);
        assertEq(address(manager).balance, ethAmount);
    }

    function testEmergencyWithdraw() public {
        vm.prank(owner);
        manager.emergencyWithdraw();

        assertFalse(manager.isInElix());
        assertFalse(manager.isInTokos());
    }

    function testEmergencyWithdrawRevertsForNonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        manager.emergencyWithdraw();
    }
}
