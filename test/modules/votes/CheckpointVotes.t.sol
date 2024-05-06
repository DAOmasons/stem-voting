// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {Accounts} from "../../setup/Accounts.t.sol";
import {CheckpointVoting} from "../../../src/modules/votes/CheckpointVotes.sol";
import {Metadata} from "../../../src/core/Metadata.sol";

contract CheckpointVotingTest is Test, Accounts {
    CheckpointVoting checkpointVoting;

    event Initialized(address contest, uint256 duration);
    event VoteCast(address indexed voter, bytes32 choiceId, uint256 amount, Metadata _reason);
    event VoteRetracted(address indexed voter, bytes32 choiceId, uint256 amount, Metadata _reason);

    uint256 _voteAmount = 10e18;
    uint256 TWO_WEEKS = 1209600;

    Metadata _reason = Metadata(1, "reason");

    function setUp() public {
        checkpointVoting = new CheckpointVoting();
    }

    //////////////////////////////
    // Base Functionality Tests
    //////////////////////////////

    function test_initialize() public {
        _inititalize();

        assertEq(address(checkpointVoting.contest()), mockContest());
        // assertTrue(checkpointVoting.isRetractable());
    }

    // function test_vote_retractable() public {
    //     _vote_retractable();

    //     assertEq(checkpointVoting.votes(choice1(), address(voter1())), _voteAmount);
    //     assertEq(checkpointVoting.totalVotesForChoice(choice1()), _voteAmount);
    // }

    // function test_vote_nonretractable() public {
    //     _vote_nonretractable();

    //     assertEq(checkpointVoting.votes(choice1(), address(voter1())), _voteAmount);
    //     assertEq(checkpointVoting.totalVotesForChoice(choice1()), _voteAmount);
    // }

    // function test_retract() public {
    //     _retract();

    //     assertEq(checkpointVoting.votes(choice1(), address(voter1())), 0);
    //     assertEq(checkpointVoting.totalVotesForChoice(choice1()), 0);
    // }

    // function test_retract_some() public {
    //     _retract_some(_voteAmount / 2);

    //     assertEq(checkpointVoting.votes(choice1(), address(voter1())), _voteAmount / 2);
    //     assertEq(checkpointVoting.totalVotesForChoice(choice1()), _voteAmount / 2);
    // }

    //////////////////////////////
    // Reverts
    //////////////////////////////

    // function testRevert_vote_not_contest() public {
    //     _inititalize_retractable();

    //     vm.startPrank(voter1());
    //     vm.expectRevert("Only contest");
    //     checkpointVoting.vote(voter1(), choice1(), _voteAmount, abi.encode(_reason));
    //     vm.stopPrank();
    // }

    // function testRevert_retract_not_contest() public {
    //     _vote_retractable();

    //     vm.startPrank(voter1());
    //     vm.expectRevert("Only contest");
    //     checkpointVoting.retractVote(voter1(), choice1(), _voteAmount, abi.encode(_reason));
    //     vm.stopPrank();
    // }

    // function testRevert_not_retractable() public {
    //     _inititalize_nonretractable();

    //     vm.prank(mockContest());
    //     vm.expectRevert("Votes are not retractable");
    //     checkpointVoting.retractVote(voter1(), choice1(), _voteAmount, abi.encode(_reason));
    // }

    // function testRevert_retract_more_than_voted() public {
    //     _vote_retractable();

    //     vm.startPrank(mockContest());

    //     vm.expectRevert("Insufficient votes allocated");
    //     checkpointVoting.retractVote(voter1(), choice1(), _voteAmount * 2, abi.encode(_reason));

    //     vm.expectRevert("Insufficient votes allocated");
    //     checkpointVoting.retractVote(voter1(), choice1(), _voteAmount + 1, abi.encode(_reason));

    //     vm.stopPrank();
    // }

    //////////////////////////////
    // Getters
    //////////////////////////////

    // function test_getTotalVotesForChoice() public {
    //     // Votes 10e18
    //     _vote_retractable();
    //     // Votes 10e18
    //     _vote_retractable();
    //     // Votes 10e18
    //     // Retracts 5e18
    //     _retract_some(_voteAmount / 2);
    //     // Votes 10e18
    //     _vote_retractable();
    //     // Votes 10e18
    //     // Retracts 20e18
    //     _retract_some(_voteAmount * 2);

    //     // total should be 25e18
    //     assertEq(checkpointVoting.getTotalVotesForChoice(choice1()), _voteAmount * 5 / 2);
    // }

    // function test_getChoiceVotesByVoter() public {
    //     _vote_retractable();
    //     _vote_retractable();

    //     assertEq(checkpointVoting.getChoiceVotesByVoter(choice1(), voter1()), _voteAmount * 2);
    // }

    //////////////////////////////
    // Helpers
    //////////////////////////////

    // function _retract_some(uint256 _amount) private {
    //     _vote_retractable();

    //     vm.expectEmit(true, false, false, true);
    //     emit VoteRetracted(voter1(), choice1(), _amount, _reason);

    //     vm.prank(mockContest());
    //     checkpointVoting.retractVote(voter1(), choice1(), _amount, abi.encode(_reason));
    // }

    // function _retract() private {
    //     _vote_retractable();

    //     vm.expectEmit(true, false, false, true);
    //     emit VoteRetracted(voter1(), choice1(), _voteAmount, _reason);

    //     vm.prank(mockContest());
    //     checkpointVoting.retractVote(voter1(), choice1(), _voteAmount, abi.encode(_reason));
    // }

    // function _vote() private {
    //     _inititalize();

    //     vm.expectEmit(true, false, false, true);
    //     emit VoteCast(voter1(), choice1(), _voteAmount, _reason);

    //     vm.prank(mockContest());
    //     checkpointVoting.vote(voter1(), choice1(), _voteAmount, abi.encode(_reason));
    // }

    function _inititalize() private {
        vm.expectEmit(true, false, false, true);
        emit Initialized(mockContest(), TWO_WEEKS);

        bytes memory data = abi.encode(TWO_WEEKS);
        checkpointVoting.initialize(mockContest(), data);
    }
}
