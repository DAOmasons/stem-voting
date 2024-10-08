// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import "../../interfaces/IVotes.sol";
import {Metadata} from "../../core/Metadata.sol";
import {Contest} from "../../Contest.sol";
import {DualTokenPointsV0} from "../points/DualTokenPointsV0.sol";

import {ContestStatus} from "../../core/ContestStatus.sol";
import {ModuleType} from "../../core/ModuleType.sol";

/// @title DualTokenTimedV0
/// @author @jord<https://github.com/jordanlesich>
/// @notice Timed voting module that incorporates a dual token voting strategy.
/// @notice this module is NOT PURELY MODULAR, requires DualTokenPointsV0
contract DualTokenTimedV0 is IVotes, Initializable {
    /// ===============================
    /// ========== Events =============
    /// ===============================

    /// @notice Emitted when the contract is initialized
    event Initialized(address contest, uint256 duration, address daoToken, address contextToken);

    /// @notice Emitted when voting has started
    event VotingStarted(uint256 startTime, uint256 endTime, address pointModule);

    /// @notice Emitted when a vote is cast
    event VoteCast(address indexed voter, bytes32 choiceId, uint256 amount, Metadata _reason, address _votingToken);

    /// @notice Emitted when a vote is retracted
    event VoteRetracted(
        address indexed voter, bytes32 choiceId, uint256 amount, Metadata _reason, address _votingToken
    );

    /// ===============================
    /// ========== Storage ============
    /// ===============================

    /// @notice The name and version of the module
    string public constant MODULE_NAME = "DualTokenTimed_v0.2.0";

    /// @notice The type of module
    ModuleType public constant MODULE_TYPE = ModuleType.Votes;

    /// @notice DAO token contract address
    address public daoToken;

    /// @notice Context token contract address
    address public contextToken;

    /// @notice Reference to the point module
    /// @dev This point module must implement DualTokenPointsV0
    DualTokenPointsV0 public pointModule;

    /// @notice Reference to the contest contract
    Contest public contest;

    /// @notice The start time of the voting period
    uint256 public startTime;

    /// @notice The end time of the voting period
    uint256 public endTime;

    /// @notice The duration of the voting period
    uint256 public duration;

    /// @notice Mapping of choiceId to voter to vote amount
    /// @dev choiceId => voter => amount
    mapping(bytes32 => mapping(address => uint256)) public contextVotes;

    /// @notice Mapping of choiceId to voter to vote amount
    /// @dev choiceId => voter => amount
    mapping(bytes32 => mapping(address => uint256)) public daoVotes;

    /// @notice Mapping of voter to total amount of votes
    /// @dev voter => totalVotes
    /// @notice inelegant, but necessary --researching a better solution
    mapping(address => uint256) public daoVotesForVoter;

    /// @notice Mapping of voter to total amount of votes
    /// @dev voter => totalVotes
    /// @notice inelegant, but necessary --researching a better solution
    mapping(address => uint256) public contextVotesForVoter;

    /// @notice Mapping of choiceId to total votes for that choice
    /// @dev choiceId => totalVotes
    mapping(bytes32 => uint256) public totalContextVotesForChoice;

    /// @notice Mapping of choiceId to total votes for that choice
    /// @dev choiceId => totalVotes
    mapping(bytes32 => uint256) public totalDaoVotesForChoice;

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
        (uint256 _duration, address _daoToken, address _contextToken) =
            abi.decode(_initParams, (uint256, address, address));

        contest = Contest(_contest);
        duration = _duration;

        daoToken = _daoToken;
        contextToken = _contextToken;

        emit Initialized(_contest, _duration, _daoToken, _contextToken);
    }

    /// ===============================
    /// ========== Setters ============
    /// ===============================

    /// @notice Sets the start time of the voting period, links points module
    /// @param _startTime The start time of the voting period
    function setupVoting(uint256 _startTime, address _pointModule) public {
        require(contest.isStatus(ContestStatus.Voting), "Contest is not in voting state");

        require(startTime == 0, "Voting has already started");

        require(_pointModule != address(0), "Invalid point module");

        pointModule = DualTokenPointsV0(_pointModule);

        if (_startTime == 0) {
            startTime = block.timestamp;
        } else {
            require(_startTime > block.timestamp, "Start time must be in the future");

            startTime = _startTime;
        }

        endTime = startTime + duration;

        emit VotingStarted(startTime, endTime, _pointModule);
    }

    /// @notice Finalizes the voting period
    function finalizeVoting() public {
        require(contest.isStatus(ContestStatus.Voting), "Contest is not in voting state");
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
        (Metadata memory _reason, address _votingToken) = abi.decode(_data, (Metadata, address));

        require(isAcceptedToken(_votingToken), "Invalid voting token");

        if (_votingToken == daoToken) {
            uint256 votedAmount = daoVotesForVoter[_voter];

            require(pointModule.getDaoVotingPower(_voter) - votedAmount >= _amount, "Insufficient voting power");

            daoVotes[_choiceId][_voter] += _amount;
            totalDaoVotesForChoice[_choiceId] += _amount;
            daoVotesForVoter[_voter] += _amount;
        } else {
            uint256 votedAmount = contextVotesForVoter[_voter];

            require(pointModule.getContextVotingPower(_voter) - votedAmount >= _amount, "Insufficient voting power");

            contextVotes[_choiceId][_voter] += _amount;
            totalContextVotesForChoice[_choiceId] += _amount;
            contextVotesForVoter[_voter] += _amount;
        }

        emit VoteCast(_voter, _choiceId, _amount, _reason, _votingToken);
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
        (Metadata memory _reason, address _votingToken) = abi.decode(_data, (Metadata, address));

        require(isAcceptedToken(_votingToken), "Invalid voting token");

        if (_votingToken == daoToken) {
            require(daoVotesForVoter[_voter] >= _amount, "Insufficient votes");

            daoVotes[_choiceId][_voter] -= _amount;
            totalDaoVotesForChoice[_choiceId] -= _amount;
        } else {
            require(contextVotesForVoter[_voter] >= _amount, "Insufficient votes");

            contextVotes[_choiceId][_voter] -= _amount;
            totalContextVotesForChoice[_choiceId] -= _amount;
        }

        emit VoteRetracted(_voter, _choiceId, _amount, _reason, _votingToken);
    }

    /// ===============================
    /// ========== Getters ============
    /// ===============================

    function isAcceptedToken(address _token) public view returns (bool) {
        return _token == daoToken || _token == contextToken;
    }

    /// @notice Gets the total votes for a choice
    /// @param _choiceId The unique identifier for the choice
    /// @return The total votes for the choice
    function getTotalVotesForChoice(bytes32 _choiceId) public view returns (uint256) {
        return totalDaoVotesForChoice[_choiceId] + totalContextVotesForChoice[_choiceId];
    }

    /// @notice Gets the votes for a choice by a voter
    /// @param _choiceId The unique identifier for the choice
    /// @param voter The address of the voter
    /// @param tokenAddress The address of the voting token
    function getChoiceVotesByVoter(bytes32 _choiceId, address voter, address tokenAddress)
        public
        view
        returns (uint256)
    {
        require(isAcceptedToken(tokenAddress), "Invalid voting token");

        if (tokenAddress == daoToken) {
            return daoVotes[_choiceId][voter];
        } else {
            return contextVotes[_choiceId][voter];
        }
    }
}
