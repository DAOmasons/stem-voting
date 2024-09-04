// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {GrantShipsSetup} from "../setup/GrantShipsSetup.t.sol";
import {ContestStatus} from "../../src/core/ContestStatus.sol";
import {Metadata} from "../../src/core/Metadata.sol";
import {HatsAllowList} from "../../src/modules/choices/HatsAllowList.sol";

contract GrantShipsBasic is GrantShipsSetup {
    event ContestStatusChanged(ContestStatus status);

    Metadata metadata = Metadata(1, "QmWmyoMoctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWeVdD");
    Metadata metadata2 = Metadata(2, "QmBa4oMoctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWe2zF");
    Metadata metadata3 = Metadata(3, "QmHi23fctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWzt32");

    bytes choiceData = "choice1";
    bytes choiceData2 = "choice2";
    bytes choiceData3 = "choice3";

    function setUp() public {
        __setupGrantShipsBasic();
    }

    //////////////////////////////
    // Base Functionality Tests
    //////////////////////////////

    function test_setup() public view {
        // Check that the votes module is set up correctly

        assertEq(address(votesModule().contest()), address(contest()));
        assertEq(votesModule().duration(), TWO_WEEKS);

        // Check that the choices module is set up correctly

        assertEq(address(choicesModule().contest()), address(contest()));
        assertEq(address(choicesModule().hats()), address(hats()));
        assertEq(choicesModule().hatId(), facilitator1().id);

        // Check that the points module is set up correctly

        assertEq(pointsModule().votingCheckpoint(), SNAPSHOT_BLOCK);
        assertEq(address(pointsModule().voteToken()), address(arbToken()));
        assertEq(address(pointsModule().contest()), address(contest()));

        // Check that the contest is set up correctly

        assertEq(address(contest().votesModule()), address(votesModule()));
        assertEq(address(contest().pointsModule()), address(pointsModule()));
        assertEq(address(contest().choicesModule()), address(choicesModule()));
        assertEq(contest().executionModule(), address(executionModule()));
        assertEq(contest().isContinuous(), false);
        assertEq(contest().isRetractable(), true);
        assertEq(contest().CONTEST_VERSION(), "0.2.0");

        assertEq(uint8(contest().contestStatus()), uint8(ContestStatus.Populating));
    }

    function test_populate() public {
        _populate();

        (Metadata memory choice1Metadata, bytes memory choice1bytesData, bool choice1exists) =
            choicesModule().choices(choice1());

        (Metadata memory choice2Metadata, bytes memory choice2bytesData, bool choice2exists) =
            choicesModule().choices(choice2());

        (Metadata memory choice3Metadata, bytes memory choice3bytesData, bool choice3exists) =
            choicesModule().choices(choice3());

        assertEq(choice1Metadata.protocol, metadata.protocol);
        assertEq(choice1Metadata.pointer, metadata.pointer);
        assertEq(choice1bytesData, choiceData);
        assertTrue(choice1exists);

        assertEq(choice2Metadata.protocol, metadata2.protocol);
        assertEq(choice2Metadata.pointer, metadata2.pointer);
        assertEq(choice2bytesData, choiceData2);
        assertTrue(choice2exists);

        assertEq(choice3Metadata.protocol, metadata3.protocol);
        assertEq(choice3Metadata.pointer, metadata3.pointer);
        assertEq(choice3bytesData, choiceData3);
        assertTrue(choice3exists);
    }

    function testFinalizeChoices() public {
        _populate();
        _finalizeChoices();

        assertEq(uint8(contest().contestStatus()), uint8(ContestStatus.Voting));
    }

    function testStartVoting() public {
        _setUpVoting();

        assertEq(votesModule().startTime(), block.timestamp);
        assertEq(votesModule().endTime(), block.timestamp + TWO_WEEKS);
    }

    function testStartVoting_future() public {
        _populate();
        _finalizeChoices();
        _setVoting_future();

        assertEq(votesModule().startTime(), block.timestamp + TWO_WEEKS);
        assertEq(votesModule().endTime(), block.timestamp + TWO_WEEKS + TWO_WEEKS);
    }

    function testVote_single() public {
        _setUpVoting();

        _vote_single(0, choice1());

        //Votes are registered for choice
        assertEq(votesModule().votes(choice1(), arbVoter(0)), VOTE_AMOUNT);
        assertEq(votesModule().totalVotesForChoice(choice1()), VOTE_AMOUNT);

        //Total votes are registered for choice
        assertEq(votesModule().totalVotesForChoice(choice1()), VOTE_AMOUNT);
        assertEq(votesModule().getTotalVotesForChoice(choice1()), VOTE_AMOUNT);

        // Points are properly allocated for user
        assertEq(pointsModule().allocatedPoints(arbVoter(0)), VOTE_AMOUNT);
        assertEq(pointsModule().getAllocatedPoints(arbVoter(0)), VOTE_AMOUNT);
        assertTrue(pointsModule().hasAllocatedPoints(arbVoter(0), VOTE_AMOUNT));
        assertFalse(pointsModule().hasVotingPoints(arbVoter(0), 1));
    }

    function testRetract_single() public {
        _setUpVoting();

        _vote_single(0, choice1());
        _retract_single(0, choice1());

        assertEq(votesModule().votes(choice1(), arbVoter(0)), 0);
        assertEq(votesModule().totalVotesForChoice(choice1()), 0);

        assertEq(pointsModule().allocatedPoints(arbVoter(0)), 0);
        assertEq(pointsModule().getPoints(arbVoter(0)), VOTE_AMOUNT);
    }

    function testVote_retract_vote() public {
        _setUpVoting();

        _vote_single(0, choice1());
        _retract_single(0, choice1());
        _vote_single(0, choice1());

        assertEq(votesModule().totalVotesForChoice(choice1()), VOTE_AMOUNT);
        assertEq(votesModule().getTotalVotesForChoice(choice1()), VOTE_AMOUNT);

        assertEq(pointsModule().allocatedPoints(arbVoter(0)), VOTE_AMOUNT);
        assertEq(pointsModule().getPoints(arbVoter(0)), 0);
    }

    function testVote_many() public {
        _setUpVoting();

        _vote_single(0, choice1());
        _vote_single(1, choice1());
        _vote_single(2, choice1());
        _vote_single(3, choice1());
        _vote_single(4, choice1());

        assertEq(votesModule().votes(choice1(), arbVoter(0)), VOTE_AMOUNT);
        assertEq(votesModule().votes(choice1(), arbVoter(1)), VOTE_AMOUNT);
        assertEq(votesModule().votes(choice1(), arbVoter(2)), VOTE_AMOUNT);
        assertEq(votesModule().votes(choice1(), arbVoter(3)), VOTE_AMOUNT);
        assertEq(votesModule().votes(choice1(), arbVoter(4)), VOTE_AMOUNT);

        assertEq(votesModule().totalVotesForChoice(choice1()), VOTE_AMOUNT * 5);

        assertEq(pointsModule().allocatedPoints(arbVoter(0)), VOTE_AMOUNT);
        assertEq(pointsModule().allocatedPoints(arbVoter(1)), VOTE_AMOUNT);
        assertEq(pointsModule().allocatedPoints(arbVoter(2)), VOTE_AMOUNT);
        assertEq(pointsModule().allocatedPoints(arbVoter(3)), VOTE_AMOUNT);
        assertEq(pointsModule().allocatedPoints(arbVoter(4)), VOTE_AMOUNT);
    }

    function testChangeVote_single() public {
        _setUpVoting();

        _vote_single(0, choice1());

        assertEq(votesModule().votes(choice1(), arbVoter(0)), VOTE_AMOUNT);
        assertEq(votesModule().votes(choice2(), arbVoter(0)), 0);

        assertEq(pointsModule().allocatedPoints(arbVoter(0)), VOTE_AMOUNT);
        assertEq(pointsModule().getPoints(arbVoter(0)), 0);

        _change_vote_single(0, choice1(), choice2());

        assertEq(votesModule().votes(choice1(), arbVoter(0)), 0);
        assertEq(votesModule().votes(choice2(), arbVoter(0)), VOTE_AMOUNT);

        assertEq(pointsModule().allocatedPoints(arbVoter(0)), VOTE_AMOUNT);
        assertEq(pointsModule().getPoints(arbVoter(0)), 0);
    }

    function testBatchVote() public {
        _setUpVoting();
        _batch_vote_single();

        uint256 ONE_EIGHTH = VOTE_AMOUNT / 8;

        assertEq(votesModule().votes(choice1(), arbVoter(0)), ONE_EIGHTH * 3);
        assertEq(votesModule().votes(choice2(), arbVoter(0)), ONE_EIGHTH * 1);
        assertEq(votesModule().votes(choice3(), arbVoter(0)), ONE_EIGHTH * 4);

        assertEq(votesModule().totalVotesForChoice(choice1()), ONE_EIGHTH * 3);
        assertEq(votesModule().totalVotesForChoice(choice2()), ONE_EIGHTH * 1);
        assertEq(votesModule().totalVotesForChoice(choice3()), ONE_EIGHTH * 4);

        assertEq(pointsModule().allocatedPoints(arbVoter(0)), VOTE_AMOUNT);
        assertEq(pointsModule().getPoints(arbVoter(0)), 0);
    }

    function testBatchVote_single() public {
        _setUpVoting();
        _batch_vote_single();

        uint256 ONE_EIGHTH = VOTE_AMOUNT / 8;

        assertEq(votesModule().votes(choice1(), arbVoter(0)), ONE_EIGHTH * 3);
        assertEq(votesModule().votes(choice2(), arbVoter(0)), ONE_EIGHTH * 1);
        assertEq(votesModule().votes(choice3(), arbVoter(0)), ONE_EIGHTH * 4);

        assertEq(votesModule().totalVotesForChoice(choice1()), ONE_EIGHTH * 3);
        assertEq(votesModule().totalVotesForChoice(choice2()), ONE_EIGHTH * 1);
        assertEq(votesModule().totalVotesForChoice(choice3()), ONE_EIGHTH * 4);

        assertEq(pointsModule().allocatedPoints(arbVoter(0)), VOTE_AMOUNT);
        assertEq(pointsModule().getPoints(arbVoter(0)), 0);
    }

    function testBatchVote_many() public {
        _setUpVoting();
        _batch_vote_many();

        uint256 ONE_EIGHTH = VOTE_AMOUNT / 8;

        assertEq(votesModule().votes(choice1(), arbVoter(0)), ONE_EIGHTH * 3);
        assertEq(votesModule().votes(choice2(), arbVoter(0)), ONE_EIGHTH * 1);
        assertEq(votesModule().votes(choice3(), arbVoter(0)), ONE_EIGHTH * 4);

        assertEq(votesModule().votes(choice1(), arbVoter(1)), ONE_EIGHTH * 1);
        assertEq(votesModule().votes(choice2(), arbVoter(1)), ONE_EIGHTH * 1);
        assertEq(votesModule().votes(choice3(), arbVoter(1)), ONE_EIGHTH * 6);

        assertEq(votesModule().votes(choice1(), arbVoter(2)), ONE_EIGHTH * 2);
        assertEq(votesModule().votes(choice2(), arbVoter(2)), ONE_EIGHTH * 2);
        assertEq(votesModule().votes(choice3(), arbVoter(2)), ONE_EIGHTH * 4);

        assertEq(votesModule().votes(choice1(), arbVoter(3)), ONE_EIGHTH * 3);
        assertEq(votesModule().votes(choice2(), arbVoter(3)), ONE_EIGHTH * 3);
        assertEq(votesModule().votes(choice3(), arbVoter(3)), ONE_EIGHTH * 2);

        assertEq(votesModule().totalVotesForChoice(choice1()), ONE_EIGHTH * 9);
        assertEq(votesModule().totalVotesForChoice(choice2()), ONE_EIGHTH * 7);
        assertEq(votesModule().totalVotesForChoice(choice3()), ONE_EIGHTH * 16);

        assertEq(pointsModule().allocatedPoints(arbVoter(0)), VOTE_AMOUNT);
        assertEq(pointsModule().allocatedPoints(arbVoter(1)), VOTE_AMOUNT);
        assertEq(pointsModule().allocatedPoints(arbVoter(2)), VOTE_AMOUNT);

        assertEq(pointsModule().getPoints(arbVoter(0)), 0);
        assertEq(pointsModule().getPoints(arbVoter(1)), 0);
        assertEq(pointsModule().getPoints(arbVoter(2)), 0);
    }

    function testBatchRetract_single() public {
        _setUpVoting();
        _batch_retract_single();

        assertEq(votesModule().votes(choice1(), arbVoter(0)), 0);
        assertEq(votesModule().votes(choice2(), arbVoter(0)), 0);
        assertEq(votesModule().votes(choice3(), arbVoter(0)), 0);

        assertEq(votesModule().totalVotesForChoice(choice1()), 0);
        assertEq(votesModule().totalVotesForChoice(choice2()), 0);
        assertEq(votesModule().totalVotesForChoice(choice3()), 0);

        assertEq(pointsModule().allocatedPoints(arbVoter(0)), 0);
        assertEq(pointsModule().getPoints(arbVoter(0)), VOTE_AMOUNT);
    }

    function testBatchRetract_many() public {
        _setUpVoting();
        _batch_retract_many();

        assertEq(votesModule().votes(choice1(), arbVoter(0)), 0);
        assertEq(votesModule().votes(choice2(), arbVoter(0)), 0);
        assertEq(votesModule().votes(choice3(), arbVoter(0)), 0);

        assertEq(votesModule().votes(choice1(), arbVoter(1)), 0);
        assertEq(votesModule().votes(choice2(), arbVoter(1)), 0);
        assertEq(votesModule().votes(choice3(), arbVoter(1)), 0);

        assertEq(votesModule().votes(choice1(), arbVoter(2)), 0);
        assertEq(votesModule().votes(choice2(), arbVoter(2)), 0);
        assertEq(votesModule().votes(choice3(), arbVoter(2)), 0);

        assertEq(votesModule().totalVotesForChoice(choice1()), 0);
        assertEq(votesModule().totalVotesForChoice(choice2()), 0);
        assertEq(votesModule().totalVotesForChoice(choice3()), 0);

        assertEq(pointsModule().allocatedPoints(arbVoter(0)), 0);
        assertEq(pointsModule().getPoints(arbVoter(0)), VOTE_AMOUNT);

        assertEq(pointsModule().allocatedPoints(arbVoter(1)), 0);
        assertEq(pointsModule().getPoints(arbVoter(1)), VOTE_AMOUNT);

        assertEq(pointsModule().allocatedPoints(arbVoter(2)), 0);
        assertEq(pointsModule().getPoints(arbVoter(2)), VOTE_AMOUNT);
    }

    function testFinalizeVoting() public {
        _setUpVoting();
        _batch_vote_many();
        _finalizeVoting();

        assertEq(uint8(contest().contestStatus()), uint8(ContestStatus.Finalized));
    }

    function testExecute() public {
        _setUpVoting();
        _batch_vote_many();
        _finalizeVoting();
        _execute();

        assertEq(uint8(contest().contestStatus()), uint8(ContestStatus.Executed));
    }

    //////////////////////////////
    // Reverts
    //////////////////////////////

    function testRevert_finalizeChoices_notPopulating() public {
        _populate();
        _finalizeChoices();

        vm.expectRevert("Contest is not in populating state");
        vm.prank(facilitator1().wearer);
        choicesModule().finalizeChoices();

        vm.expectRevert("Contest is not in populating state");
        vm.prank(facilitator1().wearer);
        choicesModule().registerChoice(choice1(), abi.encode(choiceData, metadata));
    }

    function testRevert_setVotingTime_Immediate_beforeVotingPeriod() public {
        _populate();

        vm.expectRevert("Contest is not in voting state");
        _setVoting_immediate();

        _finalizeChoices();
        _setVoting_immediate();
    }

    function testRevert_batchRetract_notVotingPeriod() public {
        _populate();

        uint256 ONE_EIGHTH = VOTE_AMOUNT / 8;

        bytes32[] memory choices = new bytes32[](3);
        uint256[] memory amounts = new uint256[](3);
        bytes[] memory datas = new bytes[](3);

        choices[0] = choice1();
        choices[1] = choice2();
        choices[2] = choice3();

        amounts[0] = ONE_EIGHTH * 3;
        amounts[1] = ONE_EIGHTH * 1;
        amounts[2] = ONE_EIGHTH * 4;

        datas[0] = abi.encode(metadata);
        datas[1] = abi.encode(metadata2);
        datas[2] = abi.encode(metadata);

        vm.prank(arbVoter(0));
        vm.expectRevert("Contest is not in voting state");
        contest().batchRetractVote(choices, amounts, datas, VOTE_AMOUNT);
    }

    function testRevert_batchRetract_invalidLength() public {
        _setUpVoting();

        _batch_vote_single();

        uint256 ONE_EIGHTH = VOTE_AMOUNT / 8;

        bytes32[] memory choices = new bytes32[](2);
        uint256[] memory amounts = new uint256[](3);
        bytes[] memory datas = new bytes[](3);

        choices[0] = choice1();
        choices[1] = choice2();

        amounts[0] = ONE_EIGHTH * 3;
        amounts[1] = ONE_EIGHTH * 1;
        amounts[2] = ONE_EIGHTH * 4;

        datas[0] = abi.encode(metadata);
        datas[1] = abi.encode(metadata2);
        datas[2] = abi.encode(metadata);

        vm.prank(arbVoter(0));
        vm.expectRevert("Array mismatch: Invalid input length");
        contest().batchRetractVote(choices, amounts, datas, VOTE_AMOUNT);
    }

    function testRevert_batchRetract_invalidChoice() public {
        _setUpVoting();

        _batch_vote_single();

        uint256 ONE_EIGHTH = VOTE_AMOUNT / 8;

        bytes32[] memory choices = new bytes32[](3);
        uint256[] memory amounts = new uint256[](3);
        bytes[] memory datas = new bytes[](3);

        choices[0] = choice1();
        choices[1] = choice2();
        choices[2] = choice4();

        amounts[0] = ONE_EIGHTH * 3;
        amounts[1] = ONE_EIGHTH * 1;
        amounts[2] = ONE_EIGHTH * 4;

        datas[0] = abi.encode(metadata);
        datas[1] = abi.encode(metadata2);
        datas[2] = abi.encode(metadata);

        vm.prank(arbVoter(0));
        vm.expectRevert("Choice does not exist");
        contest().batchRetractVote(choices, amounts, datas, VOTE_AMOUNT);
    }

    function testRevert_batchRetract_overspend() public {
        _setUpVoting();

        _batch_vote_single();

        uint256 ONE_EIGHTH = VOTE_AMOUNT / 8;

        bytes32[] memory choices = new bytes32[](3);
        uint256[] memory amounts = new uint256[](3);
        bytes[] memory datas = new bytes[](3);

        choices[0] = choice1();
        choices[1] = choice2();
        choices[2] = choice3();

        amounts[0] = ONE_EIGHTH * 3;
        amounts[1] = ONE_EIGHTH * 1;
        // sneaks in an extra vote point
        amounts[2] = ONE_EIGHTH * 4 + 1;

        datas[0] = abi.encode(metadata);
        datas[1] = abi.encode(metadata2);
        datas[2] = abi.encode(metadata);

        vm.prank(arbVoter(0));
        // should be caught by points module
        vm.expectRevert("Insufficient points allocated");
        // keeps totals the same
        contest().batchRetractVote(choices, amounts, datas, VOTE_AMOUNT);
    }

    function testRevert_batchRetract_noVotes() public {
        _setUpVoting();

        uint256 ONE_EIGHTH = VOTE_AMOUNT / 8;

        bytes32[] memory choices = new bytes32[](3);
        uint256[] memory amounts = new uint256[](3);
        bytes[] memory datas = new bytes[](3);

        choices[0] = choice1();
        choices[1] = choice2();
        choices[2] = choice3();

        amounts[0] = ONE_EIGHTH * 3;
        amounts[1] = ONE_EIGHTH * 1;
        amounts[2] = ONE_EIGHTH * 4;

        datas[0] = abi.encode(metadata);
        datas[1] = abi.encode(metadata2);
        datas[2] = abi.encode(metadata);

        vm.prank(someGuy());
        vm.expectRevert("Insufficient points allocated");
        contest().batchRetractVote(choices, amounts, datas, 0);
    }

    // usually module specific functions are tested in the module test
    // and they are, but I'm doing some extra test for setVotingTime
    // to ensure that flow of interaction between modules is correct

    function testRevert_setVotingTime_Future_beforeVotingPeriod() public {
        _populate();

        vm.expectRevert("Contest is not in voting state");
        _setVoting_future();

        _finalizeChoices();
        _setVoting_future();
    }

    function testRevert_setVotingTime_votingAlreadyStarted() public {
        _setUpVoting();

        vm.expectRevert("Voting has already started");
        _setVoting_future();

        vm.expectRevert("Voting has already started");
        _setVoting_immediate();
    }

    function testRevert_setVotingTime_future_startTimeMustBeInFuture() public {
        _populate();
        _finalizeChoices();

        vm.prank(facilitator1().wearer);
        vm.expectRevert("Start time must be in the future");
        votesModule().setVotingTime(block.timestamp - 1);
    }

    function testRevert_vote_notVotingPeriod() public {
        _populate();

        vm.startPrank(arbVoter(0));

        vm.expectRevert("Contest is not in voting state");
        contest().vote(choice1(), VOTE_AMOUNT, abi.encode(metadata));
        vm.stopPrank();
    }

    function testRevert_vote_notValidChoice() public {
        _setUpVoting();

        vm.startPrank(arbVoter(0));

        vm.expectRevert("Choice does not exist");
        contest().vote("0x0", VOTE_AMOUNT, abi.encode(metadata));

        vm.expectRevert("Choice does not exist");
        contest().vote(choice4(), VOTE_AMOUNT, abi.encode(metadata));
        vm.stopPrank();
    }

    function testRevert_vote_overspend() public {
        _setUpVoting();

        vm.startPrank(arbVoter(0));

        vm.expectRevert("Insufficient points available");
        contest().vote(choice1(), VOTE_AMOUNT + 1, abi.encode(metadata));

        contest().vote(choice1(), VOTE_AMOUNT, abi.encode(metadata));

        vm.expectRevert("Insufficient points available");
        contest().vote(choice1(), 1, abi.encode(metadata));
        vm.stopPrank();
    }

    function testRevert_vote_noVotes() public {
        _setUpVoting();

        vm.startPrank(someGuy());

        vm.expectRevert("Amount must be greater than 0");
        contest().vote(choice1(), 0, abi.encode(metadata));
        vm.stopPrank();
    }

    function testRevert_retract_notVotingPeriod() public {
        vm.expectRevert("Contest is not in voting state");
        _retract_single(0, choice1());
    }

    function testRevert_retract_invalidChoice() public {
        _setUpVoting();

        vm.expectRevert("Choice does not exist");
        _retract_single(0, "0x0");

        vm.expectRevert("Choice does not exist");
        _retract_single(0, choice4());
    }

    function testRevert_retratct_overspend() public {
        _setUpVoting();

        _vote_single(0, choice1());

        vm.expectRevert("Insufficient points allocated");
        contest().retractVote(choice1(), VOTE_AMOUNT + 1, abi.encode(metadata));
    }

    function testRevert_retract_noVotes() public {
        _setUpVoting();

        vm.expectRevert("Amount must be greater than 0");
        contest().retractVote(choice1(), 0, abi.encode(metadata));
    }

    function testRevert_changeVote_notVotingPeriod() public {
        _populate();

        vm.expectRevert("Contest is not in voting state");
        _change_vote_single(0, choice1(), choice2());
    }

    function testRevert_changeVote_onlyValidChoice() public {
        _setUpVoting();

        vm.expectRevert("Choice does not exist");
        _change_vote_single(0, "0x0", choice2());

        vm.expectRevert("Choice does not exist");
        _change_vote_single(0, choice4(), choice2());

        vm.expectRevert("Choice does not exist");
        _change_vote_single(0, choice1(), "0x0");

        vm.expectRevert("Choice does not exist");
        _change_vote_single(0, choice2(), choice4());
    }

    function testRevert_changeVote_onlyHasAllocated() public {
        _setUpVoting();

        vm.expectRevert("Insufficient points allocated");
        _change_vote_single(0, choice1(), choice2());
    }

    function testRevert_changeVote_overspend() public {
        _setUpVoting();

        _vote_single(0, choice1());

        vm.expectRevert("Insufficient points allocated");
        contest().changeVote(choice1(), choice2(), VOTE_AMOUNT + 1, abi.encode(metadata));
    }

    function testRevert_batchVote_notVotingPeriod() public {
        _populate();

        vm.expectRevert("Contest is not in voting state");
        _batch_vote_single();
    }

    function testRevert_batchVote_onlyValidChoice() public {
        _setUpVoting();

        uint256 ONE_EIGHTH = VOTE_AMOUNT / 8;

        bytes32[] memory choices = new bytes32[](3);
        uint256[] memory amounts = new uint256[](3);
        bytes[] memory datas = new bytes[](3);

        choices[0] = choice1();
        choices[1] = choice2();
        choices[2] = choice4();

        amounts[0] = ONE_EIGHTH * 3;
        amounts[1] = ONE_EIGHTH * 1;
        amounts[2] = ONE_EIGHTH * 4;

        datas[0] = abi.encode(metadata);
        datas[1] = abi.encode(metadata2);
        datas[2] = abi.encode(metadata);

        vm.prank(arbVoter(0));
        vm.expectRevert("Choice does not exist");
        contest().batchVote(choices, amounts, datas, VOTE_AMOUNT);
    }

    function testRevert_batchVote_totalsMismatch() public {
        _setUpVoting();

        uint256 ONE_EIGHTH = VOTE_AMOUNT / 8;

        bytes32[] memory choices = new bytes32[](3);
        uint256[] memory amounts = new uint256[](3);
        bytes[] memory datas = new bytes[](3);

        choices[0] = choice1();
        choices[1] = choice2();
        choices[2] = choice3();

        amounts[0] = ONE_EIGHTH * 3;
        amounts[1] = ONE_EIGHTH * 1;
        amounts[2] = ONE_EIGHTH * 4;

        datas[0] = abi.encode(metadata);
        datas[1] = abi.encode(metadata2);
        datas[2] = abi.encode(metadata);

        vm.prank(arbVoter(0));
        vm.expectRevert("Invalid total amount");
        contest().batchVote(choices, amounts, datas, ONE_EIGHTH * 7);
    }

    function testRevert_batchVote_invalidLength() public {
        _setUpVoting();

        uint256 ONE_EIGHTH = VOTE_AMOUNT / 8;

        bytes32[] memory choices = new bytes32[](3);
        uint256[] memory amounts = new uint256[](3);
        bytes[] memory datas = new bytes[](2);

        choices[0] = choice1();
        choices[1] = choice2();
        choices[2] = choice3();

        amounts[0] = ONE_EIGHTH * 3;
        amounts[1] = ONE_EIGHTH * 1;
        amounts[2] = ONE_EIGHTH * 4;

        datas[0] = abi.encode(metadata);
        datas[1] = abi.encode(metadata2);

        vm.prank(arbVoter(0));
        vm.expectRevert("Array mismatch: Invalid input length");
        contest().batchVote(choices, amounts, datas, VOTE_AMOUNT);

        amounts = new uint256[](2);
        amounts[0] = ONE_EIGHTH * 3;
        amounts[1] = ONE_EIGHTH * 1;

        datas = new bytes[](3);

        datas[0] = abi.encode(metadata);
        datas[1] = abi.encode(metadata2);
        datas[2] = abi.encode(metadata);

        vm.expectRevert("Array mismatch: Invalid input length");
        vm.prank(arbVoter(0));
        contest().batchVote(choices, amounts, datas, VOTE_AMOUNT);
    }

    function testRevert_finalizeVoting_notVotingPeriod() public {
        _populate();

        vm.expectRevert("Contest is not in voting state");
        contest().finalizeVoting();
    }

    function testRevert_finalizeVoting_onlyVotesModule() public {
        _setUpVoting();

        vm.warp(votesModule().endTime() + 1);
        vm.prank(someGuy());
        vm.expectRevert("Only votes module");
        contest().finalizeVoting();
    }

    function testRevert_execute_notFinalized() public {
        _setUpVoting();

        vm.expectRevert("Contest is not finalized");
        contest().execute();
    }

    function testRevert_execute_notModule() public {
        _setUpVoting();
        _finalizeVoting();

        vm.prank(someGuy());
        vm.expectRevert("Only execution module");
        contest().execute();
    }

    //////////////////////////////
    // Adversarial
    //////////////////////////////

    function testRevert_batchVote_overspend_sneakTotal() public {
        _setUpVoting();

        uint256 ONE_EIGHTH = VOTE_AMOUNT / 8;

        bytes32[] memory choices = new bytes32[](3);
        uint256[] memory amounts = new uint256[](3);
        bytes[] memory datas = new bytes[](3);

        choices[0] = choice1();
        choices[1] = choice2();
        choices[2] = choice3();

        amounts[0] = ONE_EIGHTH * 3;
        amounts[1] = ONE_EIGHTH * 1;
        // sneaks in an extra vote point
        amounts[2] = ONE_EIGHTH * 4 + 1;

        datas[0] = abi.encode(metadata);
        datas[1] = abi.encode(metadata2);
        datas[2] = abi.encode(metadata);

        vm.prank(arbVoter(0));
        // should be caught by points module
        vm.expectRevert("Insufficient points available");
        // keeps totals the same
        contest().batchVote(choices, amounts, datas, VOTE_AMOUNT);
    }

    //REVIEW: This test simulates a potential attack vector, or at least an unintended side-effect
    // because points doesn't log the amount of points allocated
    // to a particular choice, it's possible to retract more votes from a choice
    // than what was allocated by the user

    // THis has the effect of 'voting down' other choices

    // In the case of the GS contracts, we catch the error in the votes module
    // but it's still a potential attack vector for other modules that don't
    // have the same checks

    // In this case, modular design ftw, but I think this may warrant some discussion
    // on potential changes to the contest contract or module interfaces

    function test_comingling_attack() public {
        _setUpVoting();

        uint256 ONE_EIGHTH = VOTE_AMOUNT / 8;

        bytes32[] memory choices = new bytes32[](3);
        uint256[] memory amounts = new uint256[](3);
        bytes[] memory datas = new bytes[](3);

        choices[0] = choice1();
        choices[1] = choice2();
        choices[2] = choice3();

        amounts[0] = ONE_EIGHTH * 3;
        amounts[1] = ONE_EIGHTH * 3;
        amounts[2] = ONE_EIGHTH * 2;

        datas[0] = abi.encode(metadata);
        datas[1] = abi.encode(metadata2);
        datas[2] = abi.encode(metadata);

        vm.prank(arbVoter(0));
        contest().batchVote(choices, amounts, datas, VOTE_AMOUNT);

        uint256[] memory adversarialAmounts = new uint256[](3);

        adversarialAmounts[0] = ONE_EIGHTH * 6;
        adversarialAmounts[1] = ONE_EIGHTH * 1;
        adversarialAmounts[2] = ONE_EIGHTH * 1;

        // In GS contracts, this is caught by the votes module

        vm.prank(arbVoter(0));
        vm.expectRevert("Retracted amount exceeds vote amount");
        contest().batchRetractVote(choices, adversarialAmounts, datas, VOTE_AMOUNT);

        vm.prank(arbVoter(0));
        vm.expectRevert("Retracted amount exceeds vote amount");
        contest().retractVote(choice1(), VOTE_AMOUNT, abi.encode(metadata));
    }

    function testRevert_doubleSpend() public {
        _setUpVoting();

        _vote_single(0, choice1());

        vm.prank(arbVoter(0));
        vm.expectRevert("Insufficient points available");
        contest().vote(choice1(), VOTE_AMOUNT, abi.encode(metadata));
    }
    // transfer double-spend

    function testRevert_transfer_doubleSpend_and_delegate() public {
        _setUpVoting();

        _vote_single(0, choice1());

        // vm.prank(arbVoter(0));
        // vm.expectRevert("Insufficient points available");

        vm.prank(arbVoter(0));
        arbToken().transfer(someGuy(), VOTE_AMOUNT);

        assertEq(pointsModule().getPoints(arbVoter(0)), 0);
        assertEq(pointsModule().getPoints(someGuy()), 0);
        assertEq(arbToken().balanceOf(arbVoter(0)), 0);
        assertEq(arbToken().balanceOf(someGuy()), VOTE_AMOUNT);

        vm.prank(someGuy());
        vm.expectRevert("Insufficient points available");
        contest().vote(choice1(), VOTE_AMOUNT, abi.encode(metadata));

        vm.prank(someGuy());
        arbToken().delegate(someGuy());

        vm.prank(someGuy());
        vm.expectRevert("Insufficient points available");
        contest().vote(choice1(), VOTE_AMOUNT, abi.encode(metadata));
    }

    //////////////////////////////
    // Helpers
    //////////////////////////////

    function _execute() internal {
        vm.expectEmit(true, false, false, true);
        emit ContestStatusChanged(ContestStatus.Executed);
        executionModule().execute("");
    }

    function _finalizeVoting() internal {
        vm.warp(votesModule().endTime() + 1);

        vm.expectEmit(true, false, false, true);
        emit ContestStatusChanged(ContestStatus.Finalized);
        votesModule().finalizeVoting();
    }

    function _batch_retract_many() internal {
        _batch_vote_many();

        uint256 ONE_EIGHTH = VOTE_AMOUNT / 8;

        bytes32[] memory choices = new bytes32[](3);
        uint256[] memory amounts = new uint256[](3);
        bytes[] memory datas = new bytes[](3);

        choices[0] = choice1();
        choices[1] = choice2();
        choices[2] = choice3();

        amounts[0] = ONE_EIGHTH * 3;
        amounts[1] = ONE_EIGHTH * 1;
        amounts[2] = ONE_EIGHTH * 4;

        datas[0] = abi.encode(metadata);
        datas[1] = abi.encode(metadata2);
        datas[2] = abi.encode(metadata);

        vm.prank(arbVoter(0));
        contest().batchRetractVote(choices, amounts, datas, VOTE_AMOUNT);

        bytes32[] memory user1choices = new bytes32[](3);
        uint256[] memory user1amounts = new uint256[](3);
        bytes[] memory user1datas = new bytes[](3);

        user1choices[0] = choice1();
        user1choices[1] = choice2();
        user1choices[2] = choice3();

        user1amounts[0] = ONE_EIGHTH * 1;
        user1amounts[1] = ONE_EIGHTH * 1;
        user1amounts[2] = ONE_EIGHTH * 6;

        user1datas[0] = abi.encode(metadata);
        user1datas[1] = abi.encode(metadata2);
        user1datas[2] = abi.encode(metadata);

        vm.prank(arbVoter(1));
        contest().batchRetractVote(user1choices, user1amounts, user1datas, VOTE_AMOUNT);

        bytes32[] memory user2choices = new bytes32[](3);
        uint256[] memory user2amounts = new uint256[](3);
        bytes[] memory user2datas = new bytes[](3);

        user2choices[0] = choice1();
        user2choices[1] = choice2();
        user2choices[2] = choice3();

        user2amounts[0] = ONE_EIGHTH * 2;
        user2amounts[1] = ONE_EIGHTH * 2;
        user2amounts[2] = ONE_EIGHTH * 4;

        user2datas[0] = abi.encode(metadata);
        user2datas[1] = abi.encode(metadata2);
        user2datas[2] = abi.encode(metadata);

        vm.prank(arbVoter(2));
        contest().batchRetractVote(user2choices, user2amounts, user2datas, VOTE_AMOUNT);

        bytes32[] memory user3choices = new bytes32[](3);
        uint256[] memory user3amounts = new uint256[](3);
        bytes[] memory user3datas = new bytes[](3);

        user3choices[0] = choice1();
        user3choices[1] = choice2();
        user3choices[2] = choice3();

        user3amounts[0] = ONE_EIGHTH * 3;
        user3amounts[1] = ONE_EIGHTH * 3;
        user3amounts[2] = ONE_EIGHTH * 2;

        user3datas[0] = abi.encode(metadata);
        user3datas[1] = abi.encode(metadata2);
        user3datas[2] = abi.encode(metadata);

        vm.prank(arbVoter(3));
        contest().batchRetractVote(user3choices, user3amounts, user3datas, VOTE_AMOUNT);
    }

    function _batch_retract_single() internal {
        _batch_vote_single();

        uint256 ONE_EIGHTH = VOTE_AMOUNT / 8;

        bytes32[] memory choices = new bytes32[](3);
        uint256[] memory amounts = new uint256[](3);
        bytes[] memory datas = new bytes[](3);

        choices[0] = choice1();
        choices[1] = choice2();
        choices[2] = choice3();

        amounts[0] = ONE_EIGHTH * 3;
        amounts[1] = ONE_EIGHTH * 1;
        amounts[2] = ONE_EIGHTH * 4;

        datas[0] = abi.encode(metadata);
        datas[1] = abi.encode(metadata2);
        datas[2] = abi.encode(metadata);

        vm.prank(arbVoter(0));
        contest().batchRetractVote(choices, amounts, datas, VOTE_AMOUNT);
    }

    function _batch_vote_many() internal {
        uint256 ONE_EIGHTH = VOTE_AMOUNT / 8;

        _batch_vote_single();

        bytes32[] memory user1choices = new bytes32[](3);
        uint256[] memory user1amounts = new uint256[](3);
        bytes[] memory user1datas = new bytes[](3);

        user1choices[0] = choice1();
        user1choices[1] = choice2();
        user1choices[2] = choice3();

        user1amounts[0] = ONE_EIGHTH * 1;
        user1amounts[1] = ONE_EIGHTH * 1;
        user1amounts[2] = ONE_EIGHTH * 6;

        user1datas[0] = abi.encode(metadata);
        user1datas[1] = abi.encode(metadata2);
        user1datas[2] = abi.encode(metadata);

        vm.prank(arbVoter(1));
        contest().batchVote(user1choices, user1amounts, user1datas, VOTE_AMOUNT);

        bytes32[] memory user2choices = new bytes32[](3);
        uint256[] memory user2amounts = new uint256[](3);
        bytes[] memory user2datas = new bytes[](3);

        user2choices[0] = choice1();
        user2choices[1] = choice2();
        user2choices[2] = choice3();

        user2amounts[0] = ONE_EIGHTH * 2;
        user2amounts[1] = ONE_EIGHTH * 2;
        user2amounts[2] = ONE_EIGHTH * 4;

        user2datas[0] = abi.encode(metadata);
        user2datas[1] = abi.encode(metadata2);
        user2datas[2] = abi.encode(metadata);

        vm.prank(arbVoter(2));
        contest().batchVote(user2choices, user2amounts, user2datas, VOTE_AMOUNT);

        bytes32[] memory user3choices = new bytes32[](3);
        uint256[] memory user3amounts = new uint256[](3);
        bytes[] memory user3datas = new bytes[](3);

        user3choices[0] = choice1();
        user3choices[1] = choice2();
        user3choices[2] = choice3();

        user3amounts[0] = ONE_EIGHTH * 3;
        user3amounts[1] = ONE_EIGHTH * 3;
        user3amounts[2] = ONE_EIGHTH * 2;

        user3datas[0] = abi.encode(metadata);
        user3datas[1] = abi.encode(metadata2);
        user3datas[2] = abi.encode(metadata);

        vm.prank(arbVoter(3));
        contest().batchVote(user3choices, user3amounts, user3datas, VOTE_AMOUNT);
    }

    function _batch_vote_single() internal {
        uint256 ONE_EIGHTH = VOTE_AMOUNT / 8;

        bytes32[] memory choices = new bytes32[](3);
        uint256[] memory amounts = new uint256[](3);
        bytes[] memory datas = new bytes[](3);

        choices[0] = choice1();
        choices[1] = choice2();
        choices[2] = choice3();

        amounts[0] = ONE_EIGHTH * 3;
        amounts[1] = ONE_EIGHTH * 1;
        amounts[2] = ONE_EIGHTH * 4;

        datas[0] = abi.encode(metadata);
        datas[1] = abi.encode(metadata2);
        datas[2] = abi.encode(metadata);

        vm.prank(arbVoter(0));
        contest().batchVote(choices, amounts, datas, VOTE_AMOUNT);
    }

    function _change_vote_single(uint8 voter, bytes32 _oldChoiceId, bytes32 _newChoiceId) internal {
        vm.prank(arbVoter(voter));
        contest().changeVote(_oldChoiceId, _newChoiceId, VOTE_AMOUNT, abi.encode(metadata));
    }

    function _retract_single(uint8 voter, bytes32 choiceId) internal {
        vm.prank(arbVoter(voter));
        contest().retractVote(choiceId, VOTE_AMOUNT, abi.encode(metadata));
    }

    function _vote_single(uint8 voter, bytes32 choiceId) internal {
        vm.prank(arbVoter(voter));
        contest().vote(choiceId, VOTE_AMOUNT, abi.encode(metadata));
    }

    function _setUpVoting() internal {
        _populate();
        _finalizeChoices();
        _setVoting_immediate();
    }

    function _setVoting_immediate() internal {
        vm.prank(facilitator1().wearer);
        votesModule().setVotingTime(0);
    }

    function _setVoting_future() internal {
        vm.prank(facilitator1().wearer);
        votesModule().setVotingTime(block.timestamp + TWO_WEEKS);
    }

    function _finalizeChoices() internal {
        vm.expectEmit(true, false, false, true);
        emit ContestStatusChanged(ContestStatus.Voting);
        vm.prank(facilitator1().wearer);
        choicesModule().finalizeChoices();
    }

    function _populate() internal {
        vm.prank(facilitator1().wearer);
        choicesModule().registerChoice(choice1(), abi.encode(choiceData, metadata));

        vm.prank(facilitator2().wearer);
        choicesModule().registerChoice(choice2(), abi.encode(choiceData2, metadata2));

        vm.prank(facilitator3().wearer);
        choicesModule().registerChoice(choice3(), abi.encode(choiceData3, metadata3));
    }
}
