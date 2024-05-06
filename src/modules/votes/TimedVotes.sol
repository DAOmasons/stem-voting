// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../../interfaces/IVotes.sol";
import {Metadata} from "../../core/Metadata.sol";
import {Contest} from "../../Contest.sol";

import {ContestStatus} from "../../core/ContestStatus.sol";

// Note: I may not need this contract as the functionality required
// so far is very similar to the BaseVotes contract
contract TimedVotes is IVotes {
    /// ===============================
    /// ========== Events =============
    /// ===============================

    event Initialized(address contest, uint256 duration);

    event VotingStarted(uint256 startTime, uint256 endTime);

    event VotingComplete(uint256 endTime);

    event VoteCast(address indexed voter, bytes32 choiceId, uint256 amount, Metadata _reason);

    event VoteRetracted(address indexed voter, bytes32 choiceId, uint256 amount, Metadata _reason);

    /// ===============================
    /// ========== Storage ============
    /// ===============================

    // Todo: Use IContest once pattern is established
    Contest public contest;

    uint256 public startTime;

    uint256 public endTime;

    uint256 public duration;

    // choiceId => voter => amount
    mapping(bytes32 => mapping(address => uint256)) public votes;

    // choiceId => total votes
    mapping(bytes32 => uint256) public totalVotesForChoice;

    /// ===============================
    /// ========== Modifiers ==========
    /// ===============================

    modifier onlyContest() {
        require(msg.sender == address(contest), "Only contest");
        _;
    }

    modifier onlyDuringVotingPeriod() {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Must vote within voting period");
        _;
    }

    /// ===============================
    /// ========== Init ===============
    /// ===============================

    constructor() {}

    function initialize(address _contest, bytes memory _initParams) public {
        (uint256 _duration) = abi.decode(_initParams, (uint256));

        contest = Contest(_contest);
        duration = _duration;

        emit Initialized(_contest, _duration);
    }

    /// ===============================
    /// ========== Setters ============
    /// ===============================

    function setVotingTime(uint256 _startTime) public {
        require(contest.isStatus(ContestStatus.Voting), "Contest is not in voting state");
        require(startTime == 0, "Voting has already started");

        if (_startTime == 0) {
            startTime = block.timestamp;
        } else {
            require(_startTime > block.timestamp, "Start time must be in the future");

            startTime = _startTime;
        }

        endTime = startTime + duration;

        emit VotingStarted(startTime, endTime);
    }

    function finalizeVoting() public {
        require(contest.isStatus(ContestStatus.Voting), "Contest is not in voting state");
        require(block.timestamp > endTime, "Voting period has not ended");

        contest.finalizeVoting();
    }

    function vote(address _voter, bytes32 _choiceId, uint256 _amount, bytes memory _data)
        public
        onlyContest
        onlyDuringVotingPeriod
    {
        votes[_choiceId][_voter] += _amount;
        totalVotesForChoice[_choiceId] += _amount;

        (Metadata memory _reason) = abi.decode(_data, (Metadata));

        emit VoteCast(_voter, _choiceId, _amount, _reason);
    }

    function retractVote(address _voter, bytes32 choiceId, uint256 _amount, bytes memory _data)
        public
        onlyContest
        onlyDuringVotingPeriod
    {
        uint256 votedAmount = votes[choiceId][_voter];
        require(votedAmount >= _amount, "Retracted amount exceeds vote amount");

        votes[choiceId][_voter] -= _amount;
        totalVotesForChoice[choiceId] -= _amount;

        (Metadata memory _reason) = abi.decode(_data, (Metadata));

        emit VoteRetracted(_voter, choiceId, _amount, _reason);
    }

    /// ===============================
    /// ========== Getters ============
    /// ===============================

    function getTotalVotesForChoice(bytes32 choiceId) public view returns (uint256) {
        return totalVotesForChoice[choiceId];
    }

    function getChoiceVotesByVoter(bytes32 choiceId, address voter) public view returns (uint256) {
        return votes[choiceId][voter];
    }
}
