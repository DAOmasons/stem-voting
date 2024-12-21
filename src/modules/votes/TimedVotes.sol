// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import "../../interfaces/IVotes.sol";
import {Metadata} from "../../core/Metadata.sol";
import {Contest} from "../../Contest.sol";

import {ContestStatus} from "../../core/ContestStatus.sol";
import {ModuleType} from "../../core/ModuleType.sol";

/// @title TimedVotes
/// @author @jord<https://github.com/jordanlesich>, @dekanbro<https://github.com/dekanbro>
/// @notice Timed voting module that allows voters to cast votes within a specified time period
contract TimedVotes is IVotes, Initializable {
    /// ===============================
    /// ========== Events =============
    /// ===============================

    /// @notice Emitted when the contract is initialized
    event Initialized(address contest, uint256 duration);

    /// @notice Emitted when voting has started
    event VotingStarted(uint256 startTime, uint256 endTime);

    /// @notice Emitted when a vote is cast
    event VoteCast(address indexed voter, bytes32 choiceId, uint256 amount, Metadata _reason);

    /// @notice Emitted when a vote is retracted
    event VoteRetracted(address indexed voter, bytes32 choiceId, uint256 amount, Metadata _reason);

    /// ===============================
    /// ========== Storage ============
    /// ===============================

    /// @notice The name and version of the module
    string public constant MODULE_NAME = "TimedVotes_v0.2.0";

    /// @notice The type of module
    ModuleType public constant MODULE_TYPE = ModuleType.Votes;

    /// @notice Reference to the contest contract
    Contest public contest;

    /// @notice The start time of the voting period
    uint256 public startTime;

    /// @notice The end time of the voting period
    uint256 public endTime;

    /// @notice The duration of the voting period
    uint256 public duration;

    bool _didAutostart;

    /// @notice Mapping of choiceId to voter to vote amount
    /// @dev choiceId => voter => amount
    mapping(bytes32 => mapping(address => uint256)) public votes;

    /// @notice Mapping of choiceId to total votes for that choice
    /// @dev choiceId => totalVotes
    mapping(bytes32 => uint256) public totalVotesForChoice;

    /// ===============================
    /// ========== Modifiers ==========
    /// ===============================

    /// @notice Only the contest contract can call this function
    /// @dev The caller must be the contest contract
    modifier onlyContest() {
        require(msg.sender == address(contest), "Only contest");
        _;
    }

    /// @notice Ensures the caller is within the voting period
    /// @dev The caller must be within the voting period
    modifier onlyDuringVotingPeriod() {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Must vote within voting period");
        _;
    }

    /// ===============================
    /// ========== Init ===============
    /// ===============================

    constructor() {}

    /// @notice Initializes the timed voting module
    /// @param _contest The address of the contest contract
    /// @param _initParams The initialization data
    /// @dev Bytes data includes the duration of the voting period
    function initialize(address _contest, bytes memory _initParams) public initializer {
        (uint256 _duration, bool _autostart, uint256 _startTime) = abi.decode(_initParams, (uint256, bool, uint256));

        contest = Contest(_contest);
        duration = _duration;

        if (_autostart) {
            _didAutostart = true;
            setVotingTime(_startTime);
        }

        emit Initialized(_contest, _duration);
    }

    /// ===============================
    /// ========== Setters ============
    /// ===============================

    /// @notice Sets the start time of the voting period
    /// @param _startTime The start time of the voting period
    function setVotingTime(uint256 _startTime) public {
        /// @Note:
        /// we need to make sure that this can be called after choices round had completed
        /// OR we need to be able facilitate an autostart in cases where contest starts at the voting period
        /// However autostart triggers on module init, so simply checking the contest status is insufficient
        /// because the contest inits after the module inits
        require(
            contest.isStatus(ContestStatus.Voting) || contest.isStatus(ContestStatus.Continuous) || _didAutostart,
            "Contest is not in voting state"
        );
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

    /// @notice Finalizes the voting period
    function finalizeVoting() public {
        require(
            contest.isStatus(ContestStatus.Voting) || contest.isStatus(ContestStatus.Continuous),
            "Contest is not in voting state"
        );
        require(endTime != 0 && block.timestamp > endTime, "Voting period has not ended");

        contest.finalizeVoting();
    }

    /// @notice Casts a vote for a choice
    /// @param _voter The address of the voter
    /// @param _choiceId The unique identifier for the choice
    /// @param _amount The amount of votes to cast
    function vote(address _voter, bytes32 _choiceId, uint256 _amount, bytes memory _data)
        public
        onlyContest
        onlyDuringVotingPeriod
    {
        votes[_choiceId][_voter] += _amount;
        totalVotesForChoice[_choiceId] += _amount;

        (bytes memory _votesParams,) = abi.decode(_data, (bytes, bytes));

        (Metadata memory _reason) = abi.decode(_votesParams, (Metadata));

        emit VoteCast(_voter, _choiceId, _amount, _reason);
    }

    /// @notice Retracts a vote for a choice
    /// @param _voter The address of the voter
    /// @param _choiceId The unique identifier for the choice
    /// @param _amount The amount of votes to retract
    function retractVote(address _voter, bytes32 _choiceId, uint256 _amount, bytes memory _data)
        public
        onlyContest
        onlyDuringVotingPeriod
    {
        uint256 votedAmount = votes[_choiceId][_voter];
        require(votedAmount >= _amount, "Retracted amount exceeds vote amount");

        votes[_choiceId][_voter] -= _amount;
        totalVotesForChoice[_choiceId] -= _amount;

        (bytes memory _votesParams,) = abi.decode(_data, (bytes, bytes));

        (Metadata memory _reason) = abi.decode(_votesParams, (Metadata));

        emit VoteRetracted(_voter, _choiceId, _amount, _reason);
    }

    /// ===============================
    /// ========== Getters ============
    /// ===============================

    /// @notice Gets the total votes for a choice
    /// @param _choiceId The unique identifier for the choice
    /// @return The total votes for the choice
    function getTotalVotesForChoice(bytes32 _choiceId) public view returns (uint256) {
        return totalVotesForChoice[_choiceId];
    }

    /// @notice Gets the votes for a choice by a voter
    /// @param _choiceId The unique identifier for the choice
    /// @param voter The address of the voter
    function getChoiceVotesByVoter(bytes32 _choiceId, address voter) public view returns (uint256) {
        return votes[_choiceId][voter];
    }
}
