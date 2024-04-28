// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../../interfaces/IVotes.sol";
import {Metadata} from "../../core/Metadata.sol";

// Note: I may not need this contract as the functionality required
// so far is very similar to the BaseVotes contract

contract CheckpointVoting is IVotes {
    event Initialized(address contest, uint256 checkpointBlock, bool isRetractable);
    event VoteCast(address indexed voter, bytes32 choiceId, uint256 amount, Metadata _reason);
    event VoteRetracted(address indexed voter, bytes32 choiceId, uint256 amount, Metadata _reason);

    address public contest;
    uint256 public checkpointBlock;
    bool public isRetractable;

    modifier onlyContest() {
        require(msg.sender == contest, "Only contest");
        _;
    }

    // choiceId => voter => amount
    mapping(bytes32 => mapping(address => uint256)) public votes;
    // choiceId => total votes
    mapping(bytes32 => uint256) public totalVotesForChoice;

    constructor() {}

    function initialize(bytes memory _initParams) public {
        (address _contest, uint256 _checkpointBlock, bool _isRetractable) =
            abi.decode(_initParams, (address, uint256, bool));

        contest = _contest;
        checkpointBlock = _checkpointBlock == 0 ? block.number : _checkpointBlock;
        isRetractable = _isRetractable;

        emit Initialized(_contest, checkpointBlock, _isRetractable);
    }

    function vote(address _voter, bytes32 _choiceId, uint256 _amount, bytes memory _data) public onlyContest {
        votes[_choiceId][_voter] += _amount;
        totalVotesForChoice[_choiceId] += _amount;

        (Metadata memory _reason) = abi.decode(_data, (Metadata));

        emit VoteCast(_voter, _choiceId, _amount, _reason);
    }

    function retractVote(address _voter, bytes32 choiceId, uint256 amount, bytes memory _data) public onlyContest {
        require(isRetractable, "Votes are not retractable");

        uint256 votedAmount = votes[choiceId][_voter];
        require(votedAmount >= amount, "Insufficient votes allocated");

        votes[choiceId][_voter] -= amount;
        totalVotesForChoice[choiceId] -= amount;

        (Metadata memory _reason) = abi.decode(_data, (Metadata));

        emit VoteRetracted(_voter, choiceId, amount, _reason);
    }

    function getTotalVotesForChoice(bytes32 choiceId) public view returns (uint256) {
        return totalVotesForChoice[choiceId];
    }

    function getChoiceVotesByVoter(bytes32 choiceId, address voter) public view returns (uint256) {
        return votes[choiceId][voter];
    }
}
