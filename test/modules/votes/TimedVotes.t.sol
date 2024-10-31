// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import {Accounts} from "../../setup/Accounts.t.sol";
import {TimedVotes} from "../../../src/modules/votes/TimedVotes.sol";
import {Metadata} from "../../../src/core/Metadata.sol";
import {MockContestSetup} from "../../setup/MockContest.sol";
import {ContestStatus} from "../../../src/core/ContestStatus.sol";

contract TimedVotingTest is Test, Accounts, MockContestSetup {
    TimedVotes timedVotesModule;

    error InvalidInitialization();

    event Initialized(address contest, uint256 duration);
    event VoteCast(address indexed voter, bytes32 choiceId, uint256 amount, Metadata _reason);
    event VoteRetracted(address indexed voter, bytes32 choiceId, uint256 amount, Metadata _reason);
    event VotingStarted(uint256 startTime, uint256 endTime);
    event VotingComplete(uint256 endTime);

    uint256 _voteAmount = 10e18;
    uint256 TWO_WEEKS = 1209600;

    Metadata _reason = Metadata(1, "reason");

    // 05/05/2024 23:23:15 PST
    uint256 constant INIT_TIME = 1714976595;

    function setUp() public {
        __setupMockContest();
        timedVotesModule = new TimedVotes();

        // Forge block.timestamp starts at 0
        // warp into the future so we can test
        vm.warp(INIT_TIME);
    }

    //////////////////////////////
    // Base Functionality Tests
    //////////////////////////////

    function test_initialize() public {
        _inititalize();

        assertEq(address(timedVotesModule.contest()), address(mockContest()));
        assertEq(timedVotesModule.duration(), TWO_WEEKS);
    }

    function test_init_autostart() public {
        _init_autostart();

        assertEq(address(timedVotesModule.contest()), address(mockContest()));
        assertEq(timedVotesModule.duration(), TWO_WEEKS);
        assertEq(timedVotesModule.startTime(), block.timestamp);
        assertEq(timedVotesModule.endTime(), block.timestamp + TWO_WEEKS);
    }

    function test_init_autostartLater() public {
        _init_autostart_later();

        assertEq(address(timedVotesModule.contest()), address(mockContest()));
        assertEq(timedVotesModule.duration(), TWO_WEEKS);
        assertEq(timedVotesModule.startTime(), block.timestamp + TWO_WEEKS);
        assertEq(timedVotesModule.endTime(), block.timestamp + TWO_WEEKS * 2);
    }

    function test_autostart_vote() public {
        _vote_autostart();

        assertEq(timedVotesModule.votes(choice1(), address(voter1())), _voteAmount);
        assertEq(timedVotesModule.totalVotesForChoice(choice1()), _voteAmount);
    }

    function test_autostart_vote_later() public {
        _vote_autostart_later();

        assertEq(timedVotesModule.votes(choice1(), address(voter1())), _voteAmount);
        assertEq(timedVotesModule.totalVotesForChoice(choice1()), _voteAmount);
    }

    function test_setVotingTime_now() public {
        _setVotingTime_now();

        assertEq(timedVotesModule.startTime(), block.timestamp);
        assertEq(timedVotesModule.endTime(), block.timestamp + TWO_WEEKS);
    }

    function test_setVotingTime_later() public {
        _setVotingTime_later();

        assertEq(timedVotesModule.startTime(), block.timestamp + TWO_WEEKS);
        assertEq(timedVotesModule.endTime(), block.timestamp + TWO_WEEKS * 2);
    }

    function test_vote_retractable() public {
        _vote();

        assertEq(timedVotesModule.votes(choice1(), address(voter1())), _voteAmount);
        assertEq(timedVotesModule.totalVotesForChoice(choice1()), _voteAmount);
    }

    function test_retract() public {
        _retract();

        assertEq(timedVotesModule.votes(choice1(), address(voter1())), 0);
        assertEq(timedVotesModule.totalVotesForChoice(choice1()), 0);
    }

    function test_finalize() public {
        _finalizeVoting();

        assertEq(uint8(mockContest().contestStatus()), uint8(ContestStatus.Finalized));
    }

    //////////////////////////////
    // Reverts
    //////////////////////////////

    function testInitialize_twice() public {
        _inititalize();

        vm.expectRevert(InvalidInitialization.selector);

        bytes memory data = abi.encode(TWO_WEEKS);
        timedVotesModule.initialize(address(mockContest()), data);
    }

    function testRevert_setVotingTime_now_contestNotVoteStatus() public {
        _inititalize();

        vm.expectRevert("Contest is not in voting state");
        timedVotesModule.setVotingTime(0);
    }

    function testRevert_setVotingTime_later_contestNotVoteStatus() public {
        _inititalize();

        vm.expectRevert("Contest is not in voting state");
        timedVotesModule.setVotingTime(block.timestamp + TWO_WEEKS);
    }

    function testRevert_setVotingTime_later_startTimeInPast() public {
        _inititalize();

        mockContest().cheatStatus(ContestStatus.Voting);

        vm.expectRevert("Start time must be in the future");
        timedVotesModule.setVotingTime(block.timestamp - 1);

        timedVotesModule.setVotingTime(block.timestamp + 1);
    }

    function testRevert_autostart_doubleStart() public {
        _init_autostart();

        vm.expectRevert("Voting has already started");
        timedVotesModule.setVotingTime(0);

        vm.expectRevert("Voting has already started");
        timedVotesModule.setVotingTime(block.timestamp + 1);
    }

    function testRevert_autostart_beforeStart() public {
        _init_autostart_later();

        vm.expectRevert("Must vote within voting period");

        vm.prank(address(mockContest()));
        timedVotesModule.vote(voter1(), choice1(), _voteAmount, abi.encode(_reason));

        vm.warp(block.timestamp + TWO_WEEKS);

        vm.prank(address(mockContest()));
        timedVotesModule.vote(voter1(), choice1(), _voteAmount, abi.encode(_reason));

        vm.warp(block.timestamp + TWO_WEEKS + 1);

        vm.expectRevert("Must vote within voting period");
        vm.prank(address(mockContest()));
        timedVotesModule.vote(voter1(), choice1(), _voteAmount, abi.encode(_reason));
    }

    function testRevert_setVotingTime_now_alreadyStarted() public {
        _setVotingTime_now();

        vm.expectRevert("Voting has already started");
        timedVotesModule.setVotingTime(0);

        vm.expectRevert("Voting has already started");
        timedVotesModule.setVotingTime(block.timestamp + 1);
    }

    function testRevert_setVotingTime_later_alreadyStarted() public {
        _setVotingTime_later();

        vm.expectRevert("Voting has already started");
        timedVotesModule.setVotingTime(block.timestamp + TWO_WEEKS);

        vm.expectRevert("Voting has already started");
        timedVotesModule.setVotingTime(0);
    }

    function testRevert_voteWithinVotePeriod_before() public {
        _setVotingTime_later();

        vm.expectRevert("Must vote within voting period");
        vm.prank(address(mockContest()));
        timedVotesModule.vote(voter1(), choice1(), _voteAmount, abi.encode(_reason));

        vm.warp(block.timestamp + TWO_WEEKS);
        vm.prank(address(mockContest()));
        timedVotesModule.vote(voter1(), choice1(), _voteAmount, abi.encode(_reason));
    }

    function testRevert_voteWithinVotePeriod_after() public {
        _setVotingTime_now();

        vm.warp(block.timestamp + TWO_WEEKS + 1);

        vm.expectRevert("Must vote within voting period");
        vm.prank(address(mockContest()));
        timedVotesModule.vote(voter1(), choice1(), _voteAmount, abi.encode(_reason));
    }

    function testRevert_vote_notContest() public {
        _setVotingTime_now();

        vm.prank(voter1());
        vm.expectRevert("Only contest");
        timedVotesModule.vote(voter1(), choice1(), _voteAmount, abi.encode(_reason));

        vm.startPrank(someGuy());
        vm.expectRevert("Only contest");
        timedVotesModule.vote(voter1(), choice1(), _voteAmount, abi.encode(_reason));
    }

    function testRevert_retract_not_contest() public {
        _retract();

        vm.prank(voter1());
        vm.expectRevert("Only contest");
        timedVotesModule.retractVote(voter1(), choice1(), _voteAmount, abi.encode(_reason));

        vm.startPrank(someGuy());
        vm.expectRevert("Only contest");
        timedVotesModule.retractVote(voter1(), choice1(), _voteAmount, abi.encode(_reason));
    }

    function testRevert_retract_more_than_voted() public {
        _retract();

        vm.startPrank(address(mockContest()));

        vm.expectRevert("Retracted amount exceeds vote amount");
        timedVotesModule.retractVote(voter1(), choice1(), _voteAmount * 2, abi.encode(_reason));

        vm.expectRevert("Retracted amount exceeds vote amount");
        timedVotesModule.retractVote(voter1(), choice1(), _voteAmount + 1, abi.encode(_reason));

        vm.stopPrank();
    }

    function testRevert_finalize_notEnded() public {
        _vote();

        vm.expectRevert("Voting period has not ended");
        timedVotesModule.finalizeVoting();
    }

    function testRevert_finalize_notVotingStatus() public {
        _finalizeVoting();

        vm.expectRevert("Contest is not in voting state");
        timedVotesModule.finalizeVoting();
    }

    function testRevert_finalize_votingStatus() public {
        _inititalize();

        mockContest().cheatStatus(ContestStatus.Voting);

        vm.expectRevert("Voting period has not ended");
        timedVotesModule.finalizeVoting();
    }

    //////////////////////////////
    // Getters
    //////////////////////////////

    function test_getTotalVotesForChoice() public {
        // Votes 10e18
        _vote();

        // Votes 10e18
        vm.startPrank(address(mockContest()));
        timedVotesModule.vote(voter1(), choice1(), _voteAmount, abi.encode(_reason));

        // Votes 10e18
        timedVotesModule.vote(voter1(), choice1(), _voteAmount, abi.encode(_reason));

        // Retracts 5e18
        timedVotesModule.retractVote(voter1(), choice1(), _voteAmount / 2, abi.encode(_reason));

        // Votes 10e18
        timedVotesModule.vote(voter1(), choice1(), _voteAmount, abi.encode(_reason));

        // // Votes 10e18
        timedVotesModule.vote(voter1(), choice1(), _voteAmount, abi.encode(_reason));

        // // Retracts 20e18
        timedVotesModule.retractVote(voter1(), choice1(), _voteAmount * 2, abi.encode(_reason));

        vm.stopPrank();
        // total should be 25e18
        assertEq(timedVotesModule.getTotalVotesForChoice(choice1()), _voteAmount * 5 / 2);
    }

    function test_getChoiceVotesByVoter() public {
        // Voter 1 votes 10e18
        _vote();

        vm.startPrank(address(mockContest()));

        // Voter 1 votes 10e18 again
        timedVotesModule.vote(voter1(), choice1(), _voteAmount, abi.encode(_reason));

        // Voter 1 votes 10e18 again
        timedVotesModule.vote(voter1(), choice1(), _voteAmount, abi.encode(_reason));

        // Voter 1 retracts 5e18
        timedVotesModule.retractVote(voter1(), choice1(), _voteAmount / 2, abi.encode(_reason));

        // Voter 1 votes 10e18  for choice 2
        timedVotesModule.vote(voter1(), choice2(), _voteAmount, abi.encode(_reason));

        assertEq(timedVotesModule.getChoiceVotesByVoter(choice2(), voter1()), _voteAmount);
        assertEq(timedVotesModule.getChoiceVotesByVoter(choice1(), voter1()), _voteAmount * 5 / 2);

        // Voter 2 votes 10e18 for choice 1
        timedVotesModule.vote(voter2(), choice1(), _voteAmount, abi.encode(_reason));

        // Voter 2 votes 10e18 for choice 2
        timedVotesModule.vote(voter2(), choice2(), _voteAmount, abi.encode(_reason));

        // Voter 2 retracts 10e18 for choice 2
        timedVotesModule.retractVote(voter2(), choice2(), _voteAmount, abi.encode(_reason));

        // Voter 2 votes 10e18 for choice 3

        timedVotesModule.vote(voter2(), choice3(), _voteAmount, abi.encode(_reason));

        assertEq(timedVotesModule.getChoiceVotesByVoter(choice1(), voter2()), _voteAmount);
        assertEq(timedVotesModule.getChoiceVotesByVoter(choice2(), voter2()), 0);
        assertEq(timedVotesModule.getChoiceVotesByVoter(choice3(), voter2()), _voteAmount);
    }

    //////////////////////////////
    // Helpers
    //////////////////////////////

    function _finalizeVoting() private {
        _vote();
        // vm.expectEmit(true, false, false, true);
        // emit VotingStarted(block.timestamp, block.timestamp + TWO_WEEKS);
        vm.warp(block.timestamp + TWO_WEEKS + 1);
        timedVotesModule.finalizeVoting();
    }

    function _retract() private {
        _vote();

        vm.expectEmit(true, false, false, true);
        emit VoteRetracted(voter1(), choice1(), _voteAmount, _reason);

        vm.prank(address(mockContest()));
        timedVotesModule.retractVote(voter1(), choice1(), _voteAmount, abi.encode(_reason));
    }

    function _vote() private {
        _setVotingTime_now();

        vm.expectEmit(true, false, false, true);
        emit VoteCast(voter1(), choice1(), _voteAmount, _reason);

        vm.prank(address(mockContest()));
        timedVotesModule.vote(voter1(), choice1(), _voteAmount, abi.encode(_reason));
    }

    function _setVotingTime_later() private {
        _inititalize();

        uint256 startTime = block.timestamp + TWO_WEEKS;
        mockContest().cheatStatus(ContestStatus.Voting);

        vm.expectEmit(true, false, false, true);
        emit VotingStarted(startTime, startTime + TWO_WEEKS);

        timedVotesModule.setVotingTime(startTime);
    }

    function _setVotingTime_now() private {
        _inititalize();

        mockContest().cheatStatus(ContestStatus.Voting);

        vm.expectEmit(true, false, false, true);
        emit VotingStarted(block.timestamp, block.timestamp + TWO_WEEKS);

        timedVotesModule.setVotingTime(0);
    }

    function _inititalize() private {
        vm.expectEmit(true, false, false, true);
        emit Initialized(address(mockContest()), TWO_WEEKS);

        bytes memory data = abi.encode(TWO_WEEKS, false, 0);
        timedVotesModule.initialize(address(mockContest()), data);
    }

    function _vote_autostart() private {
        _init_autostart();

        vm.expectEmit(true, false, false, true);
        emit VoteCast(voter1(), choice1(), _voteAmount, _reason);

        vm.prank(address(mockContest()));
        timedVotesModule.vote(voter1(), choice1(), _voteAmount, abi.encode(_reason));
    }

    function _vote_autostart_later() private {
        _init_autostart_later();

        vm.warp(block.timestamp + TWO_WEEKS);

        vm.expectEmit(true, false, false, true);
        emit VoteCast(voter1(), choice1(), _voteAmount, _reason);

        vm.prank(address(mockContest()));
        timedVotesModule.vote(voter1(), choice1(), _voteAmount, abi.encode(_reason));
    }

    function _init_autostart() private {
        mockContest().cheatStatus(ContestStatus.Voting);

        vm.expectEmit(true, false, false, true);
        emit Initialized(address(mockContest()), TWO_WEEKS);

        bytes memory data = abi.encode(TWO_WEEKS, true, 0);
        timedVotesModule.initialize(address(mockContest()), data);
    }

    function _init_autostart_later() private {
        mockContest().cheatStatus(ContestStatus.Voting);

        vm.expectEmit(true, false, false, true);
        emit Initialized(address(mockContest()), TWO_WEEKS);

        bytes memory data = abi.encode(TWO_WEEKS, true, block.timestamp + TWO_WEEKS);
        timedVotesModule.initialize(address(mockContest()), data);
    }
}
