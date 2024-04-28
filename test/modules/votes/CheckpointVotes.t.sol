// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {Accounts} from "../../setup/Accounts.t.sol";
import {CheckpointVoting} from "../../../src/modules/votes/CheckpointVotes.sol";
import {Metadata} from "../../../src/core/Metadata.sol";

contract CheckPointVotingTest is Test, Accounts {
    CheckpointVoting checkpointVoting;

    uint256 _voteAmount = 10e18;

    function setUp() public {
        checkpointVoting = new CheckpointVoting();
    }

    function test_initialize_retractable() public {
        _inititalize_retractable();

        assertEq(checkpointVoting.contest(), mockContest());
        assertEq(checkpointVoting.checkpointBlock(), block.number);
        assertTrue(checkpointVoting.isRetractable());
    }

    function test_initialize_nonretractable() public {
        _inititalize_nonretractable();

        assertEq(checkpointVoting.contest(), mockContest());
        assertEq(checkpointVoting.checkpointBlock(), block.number);
        assertFalse(checkpointVoting.isRetractable());
    }

    function test_vote_retractable() public {
        _vote_retractable();

        assertEq(checkpointVoting.votes(choice1(), address(voter1())), _voteAmount);
        assertEq(checkpointVoting.totalVotesForChoice(choice1()), _voteAmount);
    }

    function testRevert_not_contest() public {
        _inititalize_retractable();

        vm.startPrank(voter1());
        vm.expectRevert("Only contest");
        checkpointVoting.vote(voter1(), choice1(), _voteAmount);
        vm.stopPrank();
    }

    function testRevert_not_retractable() public {
        _inititalize_nonretractable();

        vm.prank(mockContest());
        vm.expectRevert("Votes are not retractable");
        checkpointVoting.retractVote(voter1(), choice1(), _voteAmount);
    }

    function test_getTotalVotesForChoice() public {
        _vote_retractable();
        _vote_retractable();

        assertEq(checkpointVoting.getTotalVotesForChoice(choice1()), _voteAmount * 2);
    }

    function test_vote_nonretractable() public {
        _vote_nonretractable();

        assertEq(checkpointVoting.votes(choice1(), address(voter1())), _voteAmount);
        assertEq(checkpointVoting.totalVotesForChoice(choice1()), _voteAmount);
    }

    function _inititalize_retractable() private {
        bytes memory data = abi.encode(mockContest(), block.number, true);
        checkpointVoting.initialize(data);
    }

    function _inititalize_nonretractable() private {
        bytes memory data = abi.encode(mockContest(), block.number, false);
        checkpointVoting.initialize(data);
    }

    function _vote_retractable() private {
        _inititalize_retractable();

        vm.prank(mockContest());
        checkpointVoting.vote(voter1(), choice1(), _voteAmount);
    }

    function _vote_nonretractable() private {
        _inititalize_nonretractable();

        vm.prank(mockContest());
        checkpointVoting.vote(voter1(), choice1(), _voteAmount);
    }
}
