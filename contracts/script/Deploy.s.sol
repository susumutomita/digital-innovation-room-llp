// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {EngagementFactory} from "../src/EngagementFactory.sol";
import {Engagement, IERC20} from "../src/Engagement.sol";

contract Deploy is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address admin = vm.envAddress("ENGAGEMENT_ADMIN");
        address token = vm.envAddress("TOKEN_ADDRESS");

        vm.startBroadcast(pk);

        EngagementFactory factory = new EngagementFactory();
        Engagement engagement = factory.create(admin, IERC20(token));

        vm.stopBroadcast();

        console2.log("EngagementFactory:", address(factory));
        console2.log("Engagement:", address(engagement));
    }
}
