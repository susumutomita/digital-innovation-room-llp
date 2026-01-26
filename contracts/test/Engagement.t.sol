// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {Engagement} from "../src/Engagement.sol";
import {EngagementFactory} from "../src/EngagementFactory.sol";
import {MockERC20} from "../src/MockERC20.sol";

contract EngagementTest is Test {
    address admin = address(0xA11CE);
    address payer = address(0xB0B);
    address r1 = address(0x1111);
    address r2 = address(0x2222);

    MockERC20 token;
    EngagementFactory factory;
    Engagement engagement;

    function setUp() public {
        token = new MockERC20("Mock", "MOCK", 6);
        factory = new EngagementFactory();
        engagement = factory.create(admin, token);

        token.mint(payer, 1_000_000_000); // 1,000 MOCK with 6 decimals

        vm.startPrank(admin);
        address[] memory rec = new address[](2);
        rec[0] = r1;
        rec[1] = r2;
        uint256[] memory shares = new uint256[](2);
        shares[0] = 7000;
        shares[1] = 3000;
        engagement.setSplit(rec, shares);
        engagement.lock();
        vm.stopPrank();
    }

    function testDepositAndDistribute() public {
        vm.startPrank(payer);
        token.approve(address(engagement), 100_000_000);
        engagement.deposit(100_000_000);
        vm.stopPrank();

        engagement.distribute();

        assertEq(token.balanceOf(r1), 70_000_000);
        assertEq(token.balanceOf(r2), 30_000_000);
        assertEq(token.balanceOf(address(engagement)), 0);
    }

    function testMultipleDeposits() public {
        vm.startPrank(payer);
        token.approve(address(engagement), 200_000_000);
        engagement.deposit(50_000_000);
        engagement.deposit(150_000_000);
        vm.stopPrank();

        engagement.distribute();

        assertEq(token.balanceOf(r1), 140_000_000);
        assertEq(token.balanceOf(r2), 60_000_000);
    }

    function testCannotChangeSplitAfterLock() public {
        vm.startPrank(admin);
        address[] memory rec = new address[](1);
        rec[0] = r1;
        uint256[] memory shares = new uint256[](1);
        shares[0] = 10_000;
        vm.expectRevert("BAD_STATUS");
        engagement.setSplit(rec, shares);
        vm.stopPrank();
    }
}
