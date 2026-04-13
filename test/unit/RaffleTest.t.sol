// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Raffle} from "src/Raffle.sol";
import {CodeConstants} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";

contract RaffleTest is Script, CodeConstants {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entraceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("PLAYER");
    uint256 public constant STARTING_BALANCE = 10 ether;

    function setUp() public {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entraceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
    }

    function testRaffleInitializesInOpenState() public {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        // or assert(uint256(raffle.getRaffleState()) == 0);
    }

    /*/////////////////////////////////////////////////////////////////////////
                             ENTER RAFFLE
    //////////////////////////////////////////////////////////////////////////*/

    function testRaffleRevertsWhenYouDontPayEnough() public {
        //Arrange
        vm.prank(PLAYER);
        // Act / Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughETHSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_BALANCE);
        // Act
        raffle.enterRaffle{value: entraceFee}();
        // Assert
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        // Arrange
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_BALANCE);
        // Act
        vm.expectEmit(true, false, false, false);
        emit Raffle.RaffleEntered(PLAYER);
        // Assert
        raffle.enterRaffle{value: entraceFee}();
    }

    //roll and warp for altering time and block number
    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        // Arrange
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_BALANCE);
        // Act
        raffle.enterRaffle{value: entraceFee}();
        // wait ??
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep(""); // this will change the state to CALCULATING
        // Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entraceFee}();
    }

    /*////////////////////////////////////////////////////////////////
                    CHECK UPKEEP 
    ////////////////////////////////////////////////////////////////*/

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        //Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act
        (bool upkeepNeeded,) = raffle.checkUpKeep("");
        //Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsNotOpen() public {
        // Arrange
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_BALANCE);
        // Act
        raffle.enterRaffle{value: entraceFee}();
        // wait ??
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep(""); // this will change the state to CALCULATING

        (bool upkeepNeeded,) = raffle.checkUpKeep("");
        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        // Arrange
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_BALANCE);
        raffle.enterRaffle{value: entraceFee}();
        // Act
        (bool upkeepNeeded,) = raffle.checkUpKeep("");
        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersAreGood() public {
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_BALANCE);
        raffle.enterRaffle{value: entraceFee}();
        vm.warp(block.timestamp + interval);
        vm.roll(block.number + 1);

        (bool upkeepNeeded,) = raffle.checkUpKeep("");
        // Assert
        assert(upkeepNeeded);
    }

    /*////////////////////////////////////////////////////////////////
                    PERFORM UPKEEP  
    ////////////////////////////////////////////////////////////////*/

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // Arrange
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_BALANCE);
        raffle.enterRaffle{value: entraceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_BALANCE);
        raffle.enterRaffle{value: entraceFee}();
        currentBalance += entraceFee;
        numPlayers += 1;

        //Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, rState)
        );
        raffle.performUpkeep("");
    }

    modifier enteredRaffle() {
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_BALANCE);
        raffle.enterRaffle{value: entraceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    // What if we need to get data from emitted events in our tests?
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public enteredRaffle {
        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(raffleState == Raffle.RaffleState.CALCULATING);
        //or 1
    }

    /*/////////////////////////////////////////////////////////////////////////
                    FULFILL RANDOM WORDS
    //////////////////////////////////////////////////////////////////////////*/

    // below 2 tests will fail in fork url bcqz we are moacking the vrfcoordinator and the actual vrfcood only allows the nodes of chain

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            // Sepolia Chain ID
            return;
        }
        _;
    }

    function testFulfilRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomId) public enteredRaffle skipFork {
        // Arrange / Act / Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomId, address(raffle));
    }

    function testFulfillRandomWordsPicksAWinnerAndResetsRaffleState() public enteredRaffle skipFork {
        // Arrange
        uint256 additionalEntrants = 3; //4 total
        uint256 startingIndex = 1; // start from 1 as PLAYER is already in the raffle
        address expectedWinner = address(1);

        for (uint256 i = startingIndex; i < additionalEntrants + startingIndex; i++) {
            address newplayer = address(uint160(i));
            vm.deal(newplayer, 1 ether);
            vm.prank(newplayer);
            raffle.enterRaffle{value: entraceFee}();
        }
        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        //Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 lastTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entraceFee * (additionalEntrants + 1); // +1 for PLAYER

        assert(recentWinner == expectedWinner);
        assert(raffleState == Raffle.RaffleState.OPEN);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(lastTimeStamp > startingTimeStamp);
    }
}
