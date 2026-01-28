// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import {Engagement} from "../src/Engagement.sol";
import {EngagementFactory} from "../src/EngagementFactory.sol";
import {MockERC20} from "../src/MockERC20.sol";

import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract EngagementV2 is Engagement {
    // Append new storage at the end only.
    uint256 public newField;

    function setNewField(uint256 v) external {
        newField = v;
    }
}

contract EngagementUpgradeTest is Test {
    address admin = address(0xA11CE);
    address payer = address(0xB0B);
    address r1 = address(0x1111);
    address r2 = address(0x2222);

    MockERC20 token;
    EngagementFactory factory;

    function setUp() public {
        token = new MockERC20("Mock", "MOCK", 6);
        factory = new EngagementFactory();
        token.mint(payer, 1_000_000_000);
    }

    function testUpgradeBeaconKeepsState() public {
        uint64 startAt = uint64(block.timestamp);
        uint64 endAt = uint64(block.timestamp + 2 days);

        Engagement engagement = factory.create(admin, token, startAt, endAt, "meta");

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

        // deposit
        vm.startPrank(payer);
        token.approve(address(engagement), 100_000_000);
        engagement.deposit(100_000_000);
        vm.stopPrank();

        // Upgrade beacon
        EngagementV2 impl2 = new EngagementV2();
        UpgradeableBeacon b = factory.beacon();
        // owner is deployer (= this test contract)
        b.upgradeTo(address(impl2));

        // State should remain
        assertEq(uint256(engagement.status()), uint256(Engagement.Status.LOCKED));
        assertEq(address(engagement.token()), address(token));
        assertEq(engagement.admin(), admin);

        // New method available
        EngagementV2 upgraded = EngagementV2(address(engagement));
        upgraded.setNewField(42);
        assertEq(upgraded.newField(), 42);

        // Still can distribute
        engagement.distribute();
        assertEq(token.balanceOf(r1), 70_000_000);
        assertEq(token.balanceOf(r2), 30_000_000);
    }
}
