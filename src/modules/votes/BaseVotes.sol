// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../../interfaces/IVotes.sol";

contract BaseVotes is IVotes {
    address public contest;

    mapping(bytes32 => mapping(address => uint256)) public votes; // Mapping from choice to voter to vote count
    mapping(bytes32 => uint256) public totalVotesForChoice; // Total votes per choice

    event VoteCasted(address indexed voter, bytes32 choiceId, uint256 amount);
    event VoteRetracted(address indexed voter, bytes32 choiceId, uint256 amount);
    event VoteChanged(address indexed voter, bytes32 oldChoiceId, bytes32 newChoiceId, uint256 amount);

    modifier onlyContest() {
        require(msg.sender == contest, "Only contest");
        _;
    }

    //TODO initializer, should take bytes to destructure
    function setUp(address _contest) public {
        contest = _contest;
    }

    function vote(address _voter, bytes32 choiceId, uint256 amount) public onlyContest {
        votes[choiceId][_voter] += amount;
        totalVotesForChoice[choiceId] += amount; // Update the running total
        emit VoteCasted(_voter, choiceId, amount);
    }

    function retractVote(address _voter, bytes32 choiceId, uint256 amount) public onlyContest {
        uint256 votedAmount = votes[choiceId][_voter];
        require(votedAmount >= amount, "Insufficient votes allocated");

        votes[choiceId][_voter] -= amount;
        totalVotesForChoice[choiceId] -= amount; // Update the running total

        votes[choiceId][_voter] -= amount;
        emit VoteRetracted(_voter, choiceId, amount);
    }

    function getTotalVotesForChoice(bytes32 choiceId) public view returns (uint256) {
        return totalVotesForChoice[choiceId];
    }
}
