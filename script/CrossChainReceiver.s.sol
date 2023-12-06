// script/CrossChainReceiver.s.sol

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {CrossChainReceiver} from "../src/CrossChainReceiver.sol";

contract DeployCrossChainReceiver is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address ccipRouterAddress = 0xD0daae2231E9CB96b94C8512223533293C3693Bf;
        address simplifiedStakingAddress = "PUT SIMPLIFIED_STAKING ADDRESS HERE";

        CrossChainReceiver crossChainReceiver = new CrossChainReceiver(
            ccipRouterAddress,
            simplifiedStakingAddress
        );

        console.log("CrossChainReceiver deployed to ", address(crossChainReceiver));

        vm.stopBroadcast();
    }
}
