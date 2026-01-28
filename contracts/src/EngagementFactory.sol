// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Engagement, IERC20} from "./Engagement.sol";

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

/// @title EngagementFactory (Beacon)
/// @notice Deploys Engagement instances behind a BeaconProxy.
///         Upgrades are performed by upgrading the beacon (owner-controlled).
contract EngagementFactory {
    event EngagementCreated(address indexed engagement, address indexed admin, address indexed token);

    UpgradeableBeacon public immutable beacon;

    constructor() {
        Engagement impl = new Engagement();
        // Mode B: initial owner is deployer. Later, transfer to Safe.
        beacon = new UpgradeableBeacon(address(impl), msg.sender);
    }

    function create(address admin, IERC20 token, uint64 startAt, uint64 endAt, string calldata metadataURI)
        external
        returns (Engagement)
    {
        bytes memory initData =
            abi.encodeWithSelector(Engagement.initialize.selector, admin, token, startAt, endAt, metadataURI);
        BeaconProxy proxy = new BeaconProxy(address(beacon), initData);

        emit EngagementCreated(address(proxy), admin, address(token));
        return Engagement(address(proxy));
    }

    /// @notice Convenience: transfer beacon ownership (upgrade control) to a new owner (e.g. Safe).
    function transferBeaconOwnership(address newOwner) external {
        require(msg.sender == beacon.owner(), "NOT_BEACON_OWNER");
        beacon.transferOwnership(newOwner);
    }
}
