// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
    // VRF mock values
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE_LINK = 1e9; // 1 gwei

    int256 public MOCK_WEI_PER_UNIT_LINK = 4e15;
}

contract HelperConfig is CodeConstants, Script {
    error HelperConfig__NetworkConfigNotFound(uint256 chainId);

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link;
        address account;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig networkConfig) public networkConfigs;

    constructor() {
        networkConfigs[SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        }
        revert HelperConfig__NetworkConfigNotFound(chainId);
    }

    function getNetworkConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30, // 30 seconds
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // 500 gwei Key Hash
            subscriptionId: 113117463389530083285505248198248034425701841114418151818556284380270786639262, // subId, you can get it in the chainLink VRF dashboard
            callbackGasLimit: 500000, // 500,000 gas
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: 0x6bbC12fa8fC861b31B26Caf4d616cd1d1D8Cfc3D
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UNIT_LINK);
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30, // 30 seconds
            vrfCoordinator: address(vrfCoordinatorMock),
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // doesnt matter for mock
            subscriptionId: 0,
            callbackGasLimit: 500000, // 500,000 gas
            link: address(linkToken),
            account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
        });
        return localNetworkConfig;
    }
}
