// script/SimplifiedStaking.s.sol

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {SimplifiedStaking} from "../src/SimplifiedStaking.sol";

contract DeploySimplifiedStaking is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address stakingTokenAddress = 0xFd57b4ddBf88a4e07fF4e34C487b99af2Fe82a05;
        address lpTokenAddress = 0x466D489b6d36E7E3b824ef491C225F5830E81cC1;

        SimplifiedStaking simplifiedStaking = new SimplifiedStaking(
            stakingTokenAddress,
            lpTokenAddress
        );

        console.log("SimplifiedStaking deployed to ", address(simplifiedStaking));

        vm.stopBroadcast();
    }
}
