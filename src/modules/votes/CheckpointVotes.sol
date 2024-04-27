// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../../interfaces/IVotes.sol";

contract CheckpointVoting is IVotes {
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

    constructor(address _contest, uint256 _checkpointBlock, bool _isRetractable) {
        contest = _contest;
        checkpointBlock = _checkpointBlock == 0 ? block.number : _checkpointBlock;
        isRetractable = _isRetractable;
    }

    function vote(bytes32 _choiceId, uint256 _amount) public onlyContest {
        // votes[_choiceId][msg.sender] += _amount;
        // totalVotesForChoice[_choiceId] += _amount;

        // emit VoteCasted(msg.sender, _choiceId, _amount);
    }

    function retractVote(bytes32 choiceId, uint256 amount) public {
        // require(isRetractable, "Votes are not retractable");

        // uint256 votedAmount = votes[choiceId][msg.sender];
        // require(votedAmount >= amount, "Insufficient votes allocated");

        // votes[choiceId][msg.sender] -= amount;
        // totalVotesForChoice[choiceId] -= amount;

        // emit VoteRetracted(msg.sender, choiceId, amount);
    }

    function getTotalVotesForChoice(bytes32 choiceId) public view returns (uint256) {
        return totalVotesForChoice[choiceId];
    }
}
