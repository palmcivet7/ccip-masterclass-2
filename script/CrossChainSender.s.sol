// script/CrossChainSender.s.sol

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {CrossChainSender} from "../src/CrossChainSender.sol";

contract DeployCrossChainSender is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address ccipRouterAddressAvalancheFuji = 0x554472a2720E5E7D5D3C817529aBA05EEd5F82D8;
        address linkTokenAddressAvalancheFuji = 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846;
        address stakingTokenAddressAvalancheFuji = 0xD21341536c5cF5EB1bcb58f6723cE26e8D8E90e4; // CCIP-BnM

        CrossChainSender crossChainSender = new CrossChainSender(
            ccipRouterAddressAvalancheFuji,
            linkTokenAddressAvalancheFuji,
            stakingTokenAddressAvalancheFuji
        );

        console.log("CrossChainSender deployed to ", address(crossChainSender));

        vm.stopBroadcast();
    }
}
