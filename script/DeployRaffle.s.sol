// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

contract DeployRaffle is Script {
    function run() external {
        deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getNetworkConfig();
        if (networkConfig.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (networkConfig.subscriptionId, networkConfig.vrfCoordinator) =
                createSubscription.createSubscription(networkConfig.vrfCoordinator, networkConfig.account);
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                networkConfig.vrfCoordinator, networkConfig.subscriptionId, networkConfig.link, networkConfig.account
            );
        }
        vm.startBroadcast(networkConfig.account);
        Raffle raffle = new Raffle(
            networkConfig.entranceFee,
            networkConfig.interval,
            networkConfig.vrfCoordinator,
            networkConfig.gasLane,
            networkConfig.subscriptionId,
            networkConfig.callbackGasLimit
        );
        vm.stopBroadcast();
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffle), networkConfig.vrfCoordinator, networkConfig.subscriptionId);

        return (raffle, helperConfig);
    }
}
