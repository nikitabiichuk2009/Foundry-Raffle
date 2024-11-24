// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test, CodeConstants {
    Raffle raffle;
    HelperConfig helperConfig;
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    event RaffleEntered(address indexed player);
    event RaffleWinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployContract();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getNetworkConfig();
        entranceFee = networkConfig.entranceFee;
        interval = networkConfig.interval;
        vrfCoordinator = networkConfig.vrfCoordinator;
        gasLane = networkConfig.gasLane;
        subscriptionId = networkConfig.subscriptionId;
        callbackGasLimit = networkConfig.callbackGasLimit;

        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}(); // send value to enter raffle
        _;
    }

    modifier SkipFork() {
        if (block.chainid == LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenYouDontpayEntranceFee() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleTracksPlayersWhenTheyEnter() public raffleEntered {
        assert(raffle.getPlayer(0) == PLAYER);
    }

    function testEnteringRaffleEmiitsEvent() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowToEnterRaffleWhenPlayerAlreadyEntered() public raffleEntered {
        vm.expectRevert(Raffle.Raffle__PlayerAlreadyEntered.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowToEnterRaffleWhenItIsNotOpen() public raffleEntered {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCheckUpKeepReturnsIfItHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepRevertsIfTimeHasNotPassed() public {
        vm.warp(block.timestamp + interval - 1);
        vm.roll(block.number + 1);
        vm.expectRevert(Raffle.Raffle__TooEarlyToPickWinner.selector);
        raffle.checkUpkeep("");
    }

    function testCheckUpKeepReturnsFalseIfItIsNotOpen() public raffleEntered {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepWhenAllConditionsAreMet() public raffleEntered {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(upkeepNeeded);
    }

    function testPerformUpkeepCanOnlyRunIfCheckUpKeepIsTrue() public raffleEntered {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // act, assert
        raffle.performUpkeep("");
    }

    function testperformUpKeepRevertsIfCheckUpKeepIsFalse() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        uint256 currentBallance = 0;
        uint256 playersLength = 0;
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBallance, playersLength, raffleState)
        );
        raffle.performUpkeep("");
    }

    function testPerformUpKeepEmitsRequestIdEvent() public raffleEntered {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(raffleState == Raffle.RaffleState.CALCULATING);
        assert(uint256(requestId) > 0);
    }

    function testFulFillRandomWordsCanOnlyBeCalledAfterPerformUpKeep(uint256 randomRequestId)
        public
        raffleEntered
        SkipFork
    {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testGetEntranceFeeReturnsCorrectValue() public {
        uint256 expectedEntranceFee = entranceFee;
        uint256 actualEntranceFee = raffle.getEntranceFee();
        assertEq(actualEntranceFee, expectedEntranceFee);
    }

    function testGetRaffleStateReturnsCorrectState() public {
        Raffle.RaffleState expectedState = Raffle.RaffleState.OPEN;
        Raffle.RaffleState actualState = raffle.getRaffleState();
        assertEq(uint256(actualState), uint256(expectedState));
    }

    function testGetPlayerReturnsCorrectPlayer() public raffleEntered {
        address expectedPlayer = PLAYER;
        address actualPlayer = raffle.getPlayer(0);
        assertEq(actualPlayer, expectedPlayer);
    }

    function testGetPlayerRevertsForInvalidIndex() public raffleEntered {
        // When expecting a custom error with parameters, we need to use abi.encodeWithSelector
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__PlayerIndexOutOfBounds.selector, 1));
        raffle.getPlayer(1);
    }

    function testFulFillRandomWordsPicksAWinnerAndSendsMoneyToWinner() public SkipFork raffleEntered {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        uint256 additionalEntrants = 3; // 4 total players
        uint256 startingIndex = 1;
        address expectedWinner = address(1);
        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address newPlayer = address(uint160(i)); // address(1), address(2) etc...
            hoax(newPlayer, 1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = expectedWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrants + 1);
        assert(expectedWinner == recentWinner);
        assert(winnerBalance == prize + winnerStartingBalance);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
