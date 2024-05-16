// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {GrantShipsSetup} from "../setup/GrantShipsSetup.t.sol";
import {ContestStatus} from "../../src/core/ContestStatus.sol";
import {Metadata} from "../../src/core/Metadata.sol";
import {HatsAllowList} from "../../src/modules/choices/HatsAllowList.sol";

contract GrantShipsBasic is GrantShipsSetup {
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
        assertEq(contest().executionModule(), signalOnly);
        assertEq(contest().isContinuous(), false);
        assertEq(contest().isRetractable(), true);
        assertEq(contest().CONTEST_VERSION(), "0.1.0");

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

    //////////////////////////////
    // Reverts
    //////////////////////////////

    function testRevert_finalizeChoices_notPopulating() public {
        _populate();
        _finalizeChoices();

        vm.expectRevert("Contest is not in populating state");
        _finalizeChoices();

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

    //////////////////////////////
    // Adversarial
    //////////////////////////////

    // double spend
    // transfer double-spend
    // vote/transfer/retract/vote
    // reentrancy

    //////////////////////////////
    // Getters
    //////////////////////////////

    //////////////////////////////
    // Helpers
    //////////////////////////////

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
