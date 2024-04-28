// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IFinalizationStrategy.sol";
import "./interfaces/IVotes.sol";
import "./interfaces/IPoints.sol";
import "./interfaces/IChoices.sol";
import "./interfaces/IContest.sol";

contract Contest is IContest {
    IVotes public votesContract;
    IPoints public pointsContract;
    IChoices public choicesContract;
    IFinalizationStrategy public finalizationStrategy;

    uint256 public startTime;
    uint256 public endTime;
    bool public isFinalized;

    mapping(bytes32 => uint256) public choicesIdx;
    bytes32[] public choiceList;

    event ContestStarted(uint256 startTime, uint256 endTime);
    event ContestFinalized(bytes32[] winningChoices);

    constructor(
        IVotes _votesContract,
        IPoints _pointsContract,
        IChoices _choicesContract,
        IFinalizationStrategy _finalizationStrategy,
        uint256 _startTime,
        uint256 _duration
    ) {
        require(_startTime >= block.timestamp, "Start time must be in the future");

        votesContract = _votesContract;
        pointsContract = _pointsContract;
        choicesContract = _choicesContract;
        finalizationStrategy = _finalizationStrategy;

        startTime = _startTime;
        endTime = _startTime + _duration;
    }

    modifier onlyDuringVotingPeriod() {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Voting is not active");
        _;
    }

    modifier onlyAfterEnd() {
        require(block.timestamp > endTime, "Contest is still active");
        _;
    }

    function claimPoints() public virtual onlyDuringVotingPeriod {
        pointsContract.claimPoints();
    }

    function vote(bytes32 choiceId, uint256 amount, bytes memory _data) public virtual onlyDuringVotingPeriod {
        pointsContract.allocatePoints(msg.sender, amount);
        votesContract.vote(msg.sender, choiceId, amount, _data);

        // Review: I'm not sure if we should create a new option if the choice ID doesn't exist
        // I'm thinking that it might be a negative side effect if a user could just create a new options
        // if there should be a constrained list of options

        // Add choice to list if not already present
        if (choicesIdx[choiceId] == 0) {
            choiceList.push(choiceId);
            choicesIdx[choiceId] = choiceList.length;
        }
    }

    function retractVote(bytes32 choiceId, uint256 amount, bytes memory _data) public virtual onlyDuringVotingPeriod {
        pointsContract.releasePoints(msg.sender, amount);
        votesContract.retractVote(msg.sender, choiceId, amount, _data);
    }

    function changeVote(bytes32 oldChoiceId, bytes32 newChoiceId, uint256 amount, bytes memory _data)
        public
        virtual
        onlyDuringVotingPeriod
    {
        retractVote(oldChoiceId, amount, _data);
        vote(newChoiceId, amount, _data);
    }

    function finalize() public virtual onlyAfterEnd {
        bytes32[] memory winningChoices = finalizationStrategy.finalize(address(this), choiceList);

        // Review: I'm thinking maybe that we should perhaps handle this in some sort of
        // execution module. There we could more granular about how and what we execute

        // loop through winning choicesIdx and execute
        for (uint256 i = 0; i < winningChoices.length; i++) {
            executeChoice(winningChoices[i]);
        }
        isFinalized = true;
        emit ContestFinalized(winningChoices);
    }

    function executeChoice(bytes32 choice) internal virtual {
        (, bytes memory data) = choicesContract.getChoice(choice);
        require(data.length > 0, "No executable data found");

        // Perform the delegatecall
        (bool success,) = address(this).delegatecall(data);
        require(success, "Execution failed");
    }

    // getters

    function getTotalVotesForChoice(bytes32 choiceId) public view override returns (uint256) {
        return votesContract.getTotalVotesForChoice(choiceId);
    }

    function getChoices() external view override returns (bytes32[] memory) {
        return choiceList;
    }
}
