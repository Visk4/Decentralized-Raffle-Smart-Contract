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
// view & pure functions


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/** 
@title Raffle Contract
@author Viraj Salunke
@notice This contract is used to manage a raffle system where participants can enter and a winner can be selected.
@dev Implements Chainlink VRFv2.5
*/

contract Raffle is VRFConsumerBaseV2Plus {

    /* ERRORS */
    // use this when using if --> revert --> Custom error
    error Raffle__NotEnoughETHSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);

    /** TYPE DECLARATIONS */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit; 
    address payable [] private s_players;
    //@dev the duration of lottery in seconds
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /*EVENTS */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    //Since we inherited the contract we will need to fill the constructor of parent
    constructor(uint256 entranceFee,uint256 interval,address vrfCoordinator,bytes32 gasLane,uint256 subscriptionId,uint32 callbackGasLimit) VRFConsumerBaseV2Plus(vrfCoordinator) {        
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }


    function enterRaffle() external payable {
        //This is not very gas efficient as it stores Sting
        //require(msg.value >= i_entranceFee, "Not enough ETH sent to enter the raffle");

        //or u can do

        // This is less gas efficient and needs very specific compiler version
        // require(msg.value >= i_entranceFee, Raffle__NotEnoughETHSent());
        
        // or u can do

        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughETHSent();
        }

        if(s_raffleState != RaffleState.OPEN){
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender));

        //REASONS FOR USING EVENTS:
        //1. Makes migration easier
        //2. Makes front end "indexing" easier
        emit RaffleEntered(msg.sender);
    }
    
    /** 
     * @dev This is the func that Chainlink Keeper nodes call to check if the lottery is ready to have a winner picked.
     * The following should be true in order for upkeepNeeded to be true:
     * 1. The time interval has passed
     * 2. The lottery is open
     * 3. The contract has ETH
     * 4. Implicitly, your subscription has LINK
     * @param - ignored
     * @return upkeepNeeded - true if its time to restart the lottery
     * @return - ignored
     */
    
    function checkUpKeep(bytes memory /*checkData*/) public view returns (bool upkeepNeeded, bytes memory /*performData*/) {
        bool isOpen = (RaffleState.OPEN == s_raffleState);
        bool timePassed = ((block.timestamp - s_lastTimeStamp) >= i_interval);
        bool hasPlayers = (s_players.length > 0);
        bool hasBalance = (address(this).balance > 0);

        upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);

        //it will automatically retirn upkeepNeeded as true or false but we will still specify :)
        return (upkeepNeeded, "");
    }

    // 1. Get a random number
    // 2. Use random number to pick a player
    // 3. Be automatically called

    function performUpkeep(bytes calldata /*performData*/) external {
        //check if enough time has passed
        (bool upkeepNeeded, ) = checkUpKeep("");
        if(!upkeepNeeded){
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }
        if((block.timestamp - s_lastTimeStamp) < i_interval){
            revert();
        }

        s_raffleState = RaffleState.CALCULATING;

        //Getting a random number 
        // 1. Request RNG
        // 2. Get RNG
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            });
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);

        //actuallu=y this emit is redundant cause vrfcoordinator does emit it internally
        emit RequestedRaffleWinner(requestId);
    }

    //This function is called by Chainlink VRF when the random number is ready(actually first rawFulfil then this one)
    //CEI : Check-Effect-Interaction Pattern
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        // Checks
        //Here none

        // Effects
        uint256 winnerIndex = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[winnerIndex];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        //Reset the players array and update last timestamp
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(s_recentWinner);

        // Interactions (External Contract Calls)
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if(!success){
            revert Raffle__TransferFailed();
        }
    }

    /**
     * GETTER FUNCTIONS
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }
}