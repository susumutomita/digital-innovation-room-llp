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

        uint64 startAt = uint64(vm.envOr("MATCH_START_AT", uint256(block.timestamp)));
        uint64 endAt = uint64(vm.envOr("MATCH_END_AT", uint256(block.timestamp + 2 days)));
        string memory metadataURI = vm.envOr("METADATA_URI", string(""));

        vm.startBroadcast(pk);

        EngagementFactory factory = new EngagementFactory();
        Engagement engagement = factory.create(admin, IERC20(token), startAt, endAt, metadataURI);

        vm.stopBroadcast();

        console2.log("EngagementFactory:", address(factory));
        console2.log("Engagement:", address(engagement));
    }
}
