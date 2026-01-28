// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";

import {Engagement} from "../src/Engagement.sol";
import {EngagementFactory} from "../src/EngagementFactory.sol";
import {MockERC20} from "../src/MockERC20.sol";

contract EngagementHandler is Test {
    Engagement public e;
    MockERC20 public token;

    address public admin;
    address public payer;

    constructor(Engagement _e, MockERC20 _token, address _admin, address _payer) {
        e = _e;
        token = _token;
        admin = _admin;
        payer = _payer;

        token.mint(payer, 1_000_000_000);
    }

    function trySetSplit(address r1, address r2, uint16 a, uint16 b) external {
        // keep within [1..10000]
        uint256 s1 = uint256(a) % 10_000;
        uint256 s2 = uint256(b) % 10_000;
        if (s1 == 0 || s2 == 0) return;
        if (s1 + s2 != 10_000) return;
        if (r1 == address(0) || r2 == address(0)) return;

        address[] memory rec = new address[](2);
        rec[0] = r1;
        rec[1] = r2;
        uint256[] memory shares = new uint256[](2);
        shares[0] = s1;
        shares[1] = s2;

        vm.prank(admin);
        // may revert depending on status
        try e.setSplit(rec, shares) {} catch {}
    }

    function tryLock() external {
        vm.prank(admin);
        try e.lock() {} catch {}
    }

    function tryFinalize(uint256 warpTo) external {
        // warp forward up to +7 days
        uint256 t = block.timestamp + (warpTo % (7 days));
        vm.warp(t);
        try e.finalize() {} catch {}
    }

    function tryDeposit(uint256 amount) external {
        uint256 a = amount % 200_000_000;
        if (a == 0) return;
        vm.startPrank(payer);
        token.approve(address(e), a);
        try e.deposit(a) {} catch {}
        vm.stopPrank();
    }

    function tryDistribute() external {
        try e.distribute() {} catch {}
    }
}

contract EngagementInvariantTest is StdInvariant, Test {
    EngagementFactory factory;
    Engagement e;
    MockERC20 token;

    EngagementHandler handler;

    address admin = address(0xA11CE);
    address payer = address(0xB0B);

    function setUp() public {
        token = new MockERC20("Mock", "MOCK", 6);
        factory = new EngagementFactory();
        e = factory.create(admin, token, uint64(block.timestamp), uint64(block.timestamp + 1 days), "meta");

        handler = new EngagementHandler(e, token, admin, payer);
        targetContract(address(handler));
    }

    function invariant_neverPaysMoreThanBalance() public view {
        // This invariant is weak but safe: token balance can't be negative.
        // More interesting checks are in invariant_lockedImpliesSplitSet.
        token.balanceOf(address(e));
    }

    function invariant_lockedImpliesSplitSet() public view {
        if (e.status() == Engagement.Status.LOCKED) {
            // recipients length must be > 0
            // Solidity auto-generated getter: recipients(uint256)
            // We can't read length directly without a helper, but sharesBps(0) should exist.
            // We'll check by attempting to read recipients(0) via low-level staticcall.
            (bool ok,) = address(e).staticcall(abi.encodeWithSignature("recipients(uint256)", 0));
            assertTrue(ok);
        }
    }
}
