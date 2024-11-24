// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {console} from "forge-std/console.sol";

/**
 * @title Raffle
 * @author @nikitabiichuk2009 (Nikita Biichuk)
 * @notice This contract is for creating a raffle
 * @dev This implements the Chainlink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    // Errors
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__TooEarlyToPickWinner();
    error Raffle__TransferPrizeToWinnerFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 playersLength, uint256 raffleState);
    error Raffle__PlayerIndexOutOfBounds(uint256 index);
    error Raffle__PlayerAlreadyEntered();
    // Type declarations

    enum RaffleState {
        OPEN,
        CALCULATING
    }

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    // Events
    event RaffleEntered(address indexed player);
    event RaffleWinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() public payable {
        // require(
        //     msg.value >= i_entranceFee,
        //     "Raffle__NotEnoughETH: Must send at least entrance fee"
        // );
        // require(msg.value >= i_entranceFee, Raffle__SendMoreToEnterRaffle()); starting from 0.26, still less gas efficient than this below
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }
        // check if the same player is trying to enter the raffle multiple times
        for (uint256 i = 0; i < s_players.length; i++) {
            if (s_players[i] == msg.sender) {
                revert Raffle__PlayerAlreadyEntered();
            }
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }
    /**
     * @dev This is the function that Chainlink Keeper nodes call to see if the lottery is ready to have a winner picked
     *     The following should be true in order for upkeepNeeded to be true::
     *     1. The time interval has passed between raffle runs
     *     2. The lottery is in the OPEN state
     *     3. The contract has ETH
     *     4. Your subs is funded with LINK
     * @param - checkData is not used for this contract
     * @return upkeepNeeded is true if the lottery is ready to be picked, false otherwise
     * @return - performData is not used for this contract
     */
    /**
     * @dev This is the function that the Chainlink Keeper nodes call
     * they look for `upkeepNeeded` to return True.
     * the following should be true for this to return true:
     * 1. The time interval has passed between raffle runs.
     * 2. The lottery is open.
     * 3. The contract has ETH.
     * 4. Implicity, your subscription is funded with LINK.
     */

    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert Raffle__TooEarlyToPickWinner();
        }

        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >= i_interval);
        bool hasPlayers = s_players.length > 0;
        bool raffleIsOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (timeHasPassed && hasPlayers && raffleIsOpen && hasBalance);
        return (upkeepNeeded, "0x0");
    }

    /**
     * @dev Once `checkUpkeep` is returning `true`, this function is called
     * and it kicks off a Chainlink VRF call to get a random winner.
     */
    function performUpkeep(bytes calldata /* performData */ ) external {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );
        emit RequestedRaffleWinner(requestId); // a bit redundant, but for testing purposes
    }
    // CEI: Checks, Effects, Interactions
    /**
     * @dev This is the function that Chainlink VRF node
     * calls to send the money to the random winner.
     */

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];

        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit RaffleWinnerPicked(recentWinner);
        console.log("Sending prize to winner: ", recentWinner);
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferPrizeToWinnerFailed();
        }
    }

    // Getter functions
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 index) public view returns (address) {
        if (index >= s_players.length || s_players[index] == address(0)) {
            revert Raffle__PlayerIndexOutOfBounds(index);
        }
        return s_players[index];
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }
}
