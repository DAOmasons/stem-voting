// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {Accounts} from "../../setup/Accounts.t.sol";
import {CheckpointVoting} from "../../../src/modules/votes/CheckpointVotes.sol";
import {Metadata} from "../../../src/core/Metadata.sol";
import {MockContestSetup} from "../../setup/MockContest.sol";
import {ContestStatus} from "../../../src/core/ContestStatus.sol";

contract CheckpointVotingTest is Test, Accounts, MockContestSetup {
    CheckpointVoting checkpointVoting;

    event Initialized(address contest, uint256 duration);
    event VoteCast(address indexed voter, bytes32 choiceId, uint256 amount, Metadata _reason);
    event VoteRetracted(address indexed voter, bytes32 choiceId, uint256 amount, Metadata _reason);
    event VotingStarted(uint256 startTime, uint256 endTime);

    uint256 _voteAmount = 10e18;
    uint256 TWO_WEEKS = 1209600;

    Metadata _reason = Metadata(1, "reason");

    // 05/05/2024 23:23:15 PST
    uint256 constant INIT_TIME = 1714976595;

    function setUp() public {
        __setupMockContest();
        checkpointVoting = new CheckpointVoting();

        // Forge block.timestamp starts at 0
        // warp into the future so we can test
        vm.warp(INIT_TIME);
    }

    //////////////////////////////
    // Base Functionality Tests
    //////////////////////////////

    function test_initialize() public {
        _inititalize();

        assertEq(address(checkpointVoting.contest()), address(mockContest()));
        assertEq(checkpointVoting.duration(), TWO_WEEKS);
    }

    function test_setVotingTime_now() public {
        _setVotingTime_now();

        assertEq(checkpointVoting.startTime(), block.timestamp);
        assertEq(checkpointVoting.endTime(), block.timestamp + TWO_WEEKS);
    }

    function test_setVotingTime_later() public {
        _setVotingTime_later();

        assertEq(checkpointVoting.startTime(), block.timestamp + TWO_WEEKS);
        assertEq(checkpointVoting.endTime(), block.timestamp + TWO_WEEKS * 2);
    }

    function test_vote_retractable() public {
        _vote();

        assertEq(checkpointVoting.votes(choice1(), address(voter1())), _voteAmount);
        assertEq(checkpointVoting.totalVotesForChoice(choice1()), _voteAmount);
    }

    function test_retract() public {
        _retract();

        assertEq(checkpointVoting.votes(choice1(), address(voter1())), 0);
        assertEq(checkpointVoting.totalVotesForChoice(choice1()), 0);
    }

    //////////////////////////////
    // Reverts
    //////////////////////////////

    function testRevert_setVotingTime_now_contestNotVoteStatus() public {
        _inititalize();

        vm.expectRevert("Contest is not in voting state");
        checkpointVoting.setVotingTime(0);
    }

    function testRevert_setVotingTime_later_contestNotVoteStatus() public {
        _inititalize();

        vm.expectRevert("Contest is not in voting state");
        checkpointVoting.setVotingTime(block.timestamp + TWO_WEEKS);
    }

    function testRevert_setVotingTime_later_startTimeInPast() public {
        _inititalize();

        mockContest().cheatStatus(ContestStatus.Voting);

        vm.expectRevert("Start time must be in the future");
        checkpointVoting.setVotingTime(block.timestamp - 1);

        checkpointVoting.setVotingTime(block.timestamp + 1);
    }

    function testRevert_setVotingTime_now_alreadyStarted() public {
        _setVotingTime_now();

        vm.expectRevert("Voting has already started");
        checkpointVoting.setVotingTime(0);

        vm.expectRevert("Voting has already started");
        checkpointVoting.setVotingTime(block.timestamp + 1);
    }

    function testRevert_setVotingTime_later_alreadyStarted() public {
        _setVotingTime_later();

        vm.expectRevert("Voting has already started");
        checkpointVoting.setVotingTime(block.timestamp + TWO_WEEKS);

        vm.expectRevert("Voting has already started");
        checkpointVoting.setVotingTime(0);
    }

    function testRevert_voteWithinVotePeriod_before() public {
        _setVotingTime_later();

        vm.expectRevert("Must vote within voting period");
        vm.prank(address(mockContest()));
        checkpointVoting.vote(voter1(), choice1(), _voteAmount, abi.encode(_reason));

        vm.warp(block.timestamp + TWO_WEEKS);
        vm.prank(address(mockContest()));
        checkpointVoting.vote(voter1(), choice1(), _voteAmount, abi.encode(_reason));
    }

    function testRevert_voteWithinVotePeriod_after() public {
        _setVotingTime_now();

        vm.warp(block.timestamp + TWO_WEEKS + 1);

        vm.expectRevert("Must vote within voting period");
        vm.prank(address(mockContest()));
        checkpointVoting.vote(voter1(), choice1(), _voteAmount, abi.encode(_reason));
    }

    function testRevert_vote_notContest() public {
        _setVotingTime_now();

        vm.prank(voter1());
        vm.expectRevert("Only contest");
        checkpointVoting.vote(voter1(), choice1(), _voteAmount, abi.encode(_reason));

        vm.startPrank(someGuy());
        vm.expectRevert("Only contest");
        checkpointVoting.vote(voter1(), choice1(), _voteAmount, abi.encode(_reason));
    }

    function testRevert_retract_not_contest() public {
        _retract();

        vm.prank(voter1());
        vm.expectRevert("Only contest");
        checkpointVoting.retractVote(voter1(), choice1(), _voteAmount, abi.encode(_reason));

        vm.startPrank(someGuy());
        vm.expectRevert("Only contest");
        checkpointVoting.retractVote(voter1(), choice1(), _voteAmount, abi.encode(_reason));
    }

    function testRevert_retract_more_than_voted() public {
        _retract();

        vm.startPrank(address(mockContest()));

        vm.expectRevert("Retracted amount exceeds vote amount");
        checkpointVoting.retractVote(voter1(), choice1(), _voteAmount * 2, abi.encode(_reason));

        vm.expectRevert("Retracted amount exceeds vote amount");
        checkpointVoting.retractVote(voter1(), choice1(), _voteAmount + 1, abi.encode(_reason));

        vm.stopPrank();
    }

    //////////////////////////////
    // Getters
    //////////////////////////////

    function test_getTotalVotesForChoice() public {
        // Votes 10e18
        _vote();

        // Votes 10e18
        vm.startPrank(address(mockContest()));
        checkpointVoting.vote(voter1(), choice1(), _voteAmount, abi.encode(_reason));

        // Votes 10e18
        checkpointVoting.vote(voter1(), choice1(), _voteAmount, abi.encode(_reason));

        // Retracts 5e18
        checkpointVoting.retractVote(voter1(), choice1(), _voteAmount / 2, abi.encode(_reason));

        // Votes 10e18
        checkpointVoting.vote(voter1(), choice1(), _voteAmount, abi.encode(_reason));

        // // Votes 10e18
        checkpointVoting.vote(voter1(), choice1(), _voteAmount, abi.encode(_reason));

        // // Retracts 20e18
        checkpointVoting.retractVote(voter1(), choice1(), _voteAmount * 2, abi.encode(_reason));

        vm.stopPrank();
        // total should be 25e18
        assertEq(checkpointVoting.getTotalVotesForChoice(choice1()), _voteAmount * 5 / 2);
    }

    function test_getChoiceVotesByVoter() public {
        // Voter 1 votes 10e18
        _vote();

        vm.startPrank(address(mockContest()));

        // Voter 1 votes 10e18 again
        checkpointVoting.vote(voter1(), choice1(), _voteAmount, abi.encode(_reason));

        // Voter 1 votes 10e18 again
        checkpointVoting.vote(voter1(), choice1(), _voteAmount, abi.encode(_reason));

        // Voter 1 retracts 5e18
        checkpointVoting.retractVote(voter1(), choice1(), _voteAmount / 2, abi.encode(_reason));

        // Voter 1 votes 10e18  for choice 2
        checkpointVoting.vote(voter1(), choice2(), _voteAmount, abi.encode(_reason));

        assertEq(checkpointVoting.getChoiceVotesByVoter(choice2(), voter1()), _voteAmount);
        assertEq(checkpointVoting.getChoiceVotesByVoter(choice1(), voter1()), _voteAmount * 5 / 2);

        // Voter 2 votes 10e18 for choice 1
        checkpointVoting.vote(voter2(), choice1(), _voteAmount, abi.encode(_reason));

        // Voter 2 votes 10e18 for choice 2
        checkpointVoting.vote(voter2(), choice2(), _voteAmount, abi.encode(_reason));

        // Voter 2 retracts 10e18 for choice 2
        checkpointVoting.retractVote(voter2(), choice2(), _voteAmount, abi.encode(_reason));

        // Voter 2 votes 10e18 for choice 3

        checkpointVoting.vote(voter2(), choice3(), _voteAmount, abi.encode(_reason));

        assertEq(checkpointVoting.getChoiceVotesByVoter(choice1(), voter2()), _voteAmount);
        assertEq(checkpointVoting.getChoiceVotesByVoter(choice2(), voter2()), 0);
        assertEq(checkpointVoting.getChoiceVotesByVoter(choice3(), voter2()), _voteAmount);
    }

    //////////////////////////////
    // Helpers
    //////////////////////////////

    function _retract() private {
        _vote();

        vm.expectEmit(true, false, false, true);
        emit VoteRetracted(voter1(), choice1(), _voteAmount, _reason);

        vm.prank(address(mockContest()));
        checkpointVoting.retractVote(voter1(), choice1(), _voteAmount, abi.encode(_reason));
    }

    function _vote() private {
        _setVotingTime_now();

        vm.expectEmit(true, false, false, true);
        emit VoteCast(voter1(), choice1(), _voteAmount, _reason);

        vm.prank(address(mockContest()));
        checkpointVoting.vote(voter1(), choice1(), _voteAmount, abi.encode(_reason));
    }

    function _setVotingTime_later() private {
        _inititalize();

        uint256 startTime = block.timestamp + TWO_WEEKS;
        mockContest().cheatStatus(ContestStatus.Voting);

        vm.expectEmit(true, false, false, true);
        emit VotingStarted(startTime, startTime + TWO_WEEKS);

        checkpointVoting.setVotingTime(startTime);
    }

    function _setVotingTime_now() private {
        _inititalize();

        mockContest().cheatStatus(ContestStatus.Voting);

        vm.expectEmit(true, false, false, true);
        emit VotingStarted(block.timestamp, block.timestamp + TWO_WEEKS);

        checkpointVoting.setVotingTime(0);
    }

    function _inititalize() private {
        vm.expectEmit(true, false, false, true);
        emit Initialized(address(mockContest()), TWO_WEEKS);

        bytes memory data = abi.encode(TWO_WEEKS);
        checkpointVoting.initialize(address(mockContest()), data);
    }
}
