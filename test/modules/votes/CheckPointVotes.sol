// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {Accounts} from "../../setup/Accounts.t.sol";
import {CheckpointVoting} from "../../../src/modules/votes/CheckpointVotes.sol";

contract CheckPointVotingTest is Test, Accounts {
    CheckpointVoting checkpointVoting;

    uint256 _voteAmount = 100;

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

        // assertEq(checkpointVoting.votes(choice1(), address(this)), _voteAmount);
        // assertEq(checkpointVoting.totalVotesForChoice(choice1()), _voteAmount);
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

        checkpointVoting.vote(choice1(), _voteAmount);
    }
}
