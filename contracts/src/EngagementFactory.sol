// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Engagement, IERC20} from "./Engagement.sol";

/// @title EngagementFactory
/// @notice Deploys Engagement instances (one per project / engagement).
contract EngagementFactory {
    event EngagementCreated(address indexed engagement, address indexed admin, address indexed token);

    function create(address admin, IERC20 token) external returns (Engagement) {
        Engagement e = new Engagement(admin, token);
        emit EngagementCreated(address(e), admin, address(token));
        return e;
    }
}
