// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVotes} from "../../interfaces/IVotes.sol";
import {ModuleType} from "../../core/ModuleType.sol";
import {Contest} from "../../Contest.sol";
import {Metadata} from "../../core/Metadata.sol";
import {Initializable} from "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {VoteTimer, TimerType} from "./utils/VoteTimer.sol";
import {IHats} from "lib/hats-protocol/src/Interfaces/IHats.sol";
import {ContestStatus} from "../../core/ContestStatus.sol";

contract TimedVotesV1 is VoteTimer, IVotes, Initializable {
    /// @notice Emitted when the contract is initialized
    event Initialized(address _contest, uint256 _duration, TimerType _timerType, uint256 _adminHatId);

    /// @notice Emitted when the contract is initialized
    event Initialized(address contest, uint256 duration);

    /// @notice Emitted when a vote is cast
    event VoteCast(address indexed voter, bytes32 choiceId, uint256 amount, Metadata _reason);

    /// @notice Emitted when a vote is retracted
    event VoteRetracted(address indexed voter, bytes32 choiceId, uint256 amount, Metadata _reason);

    /// @notice The name and version of the module
    string public constant MODULE_NAME = "TimedVotes_v1.0.0";

    /// @notice The type of module
    ModuleType public constant MODULE_TYPE = ModuleType.Votes;

    /// @notice Reference to the contest contract
    Contest public contest;

    /// @notice admin hat id
    uint256 public adminHatId;

    /// @notice Reference to the Hats Protocol contract
    IHats hats;

    /// @notice Mapping of choiceId to voter to vote amount
    /// @dev choiceId => voter => amount
    mapping(bytes32 => mapping(address => uint256)) public votes;

    /// @notice Mapping of choiceId to total votes for that choice
    /// @dev choiceId => totalVotes
    mapping(bytes32 => uint256) public totalVotesForChoice;

    /// @notice Only the contest contract can call this function
    /// @dev The caller must be the contest contract
    modifier onlyContest() {
        require(msg.sender == address(contest), "Only contest");
        _;
    }

    modifier onlyAdmin() {
        require(
            hats.isWearerOfHat(msg.sender, adminHatId) && hats.isInGoodStanding(msg.sender, adminHatId), "Only wearer"
        );
        _;
    }

    /// @notice Initializes the timed voting module
    /// @param _contest The address of the contest contract
    /// @param _initParams The initialization data
    /// @dev Bytes data includes the duration of the voting period
    function initialize(address _contest, bytes memory _initParams) public initializer {
        (uint256 _duration, uint256 _startTime, TimerType _timerType, uint256 _adminHatId, address _hats) =
            abi.decode(_initParams, (uint256, uint256, TimerType, uint256, address));

        // We have the option to bypass admin permissions and make module management permissionless
        // but this will not work for lazy timers, as that will allow anyone to set voting times
        // therefore we require the admin hat for lazy timers
        if (_adminHatId == 0) {
            require(_timerType != TimerType.Lazy, "Lazy timer requires admin hat");
        }

        hats = IHats(_hats);

        contest = Contest(_contest);

        adminHatId = _adminHatId;

        _timerInit(_timerType, _startTime, _duration);

        emit Initialized(_contest, _duration, _timerType, _adminHatId);
    }

    /// @notice Casts a vote for a choice based on the total voting power of all hats referenced in the Hats Points contract
    /// @param _voter The address of the voter
    /// @param _choiceId The unique identifier for the choice
    /// @param _amount The amount of votes to cast
    function vote(address _voter, bytes32 _choiceId, uint256 _amount, bytes memory _data)
        external
        onlyContest
        onlyVotingPeriod
    {
        votes[_choiceId][_voter] += _amount;
        totalVotesForChoice[_choiceId] += _amount;

        // This module does not check for duplicate votes, as that is handled by the Points contract and the Contest

        (bytes memory _votesData,) = abi.decode(_data, (bytes, bytes));

        (Metadata memory _reason) = abi.decode(_votesData, (Metadata));

        emit VoteCast(_voter, _choiceId, _amount, _reason);
    }

    /// @notice Retracts a vote for a choice
    /// @param _voter The address of the voter
    /// @param _choiceId The unique identifier for the choice
    /// @param _amount The amount of votes to retract
    function retractVote(address _voter, bytes32 _choiceId, uint256 _amount, bytes memory _data)
        external
        onlyContest
        onlyVotingPeriod
    {
        uint256 votedAmount = votes[_choiceId][_voter];
        require(votedAmount >= _amount, "Retracted amount exceeds vote amount");

        votes[_choiceId][_voter] -= _amount;
        totalVotesForChoice[_choiceId] -= _amount;

        (bytes memory _votesData,) = abi.decode(_data, (bytes, bytes));

        (Metadata memory _reason) = abi.decode(_votesData, (Metadata));

        emit VoteRetracted(_voter, _choiceId, _amount, _reason);
    }

    /// @notice Starts the voting period for lazy initialized voting periods
    function startTimer() external onlyAdmin {
        _startTimer();
    }

    /// @notice Finalizes the voting period
    function finalizeVotes() external onlyVoteCompleted onlyAdmin {
        contest.finalizeVoting();
    }

    /// @notice Gets the total votes for a choice
    /// @param _choiceId The unique identifier for the choice
    /// @return The total votes for the choice
    function getTotalVotesForChoice(bytes32 _choiceId) external view returns (uint256) {
        return totalVotesForChoice[_choiceId];
    }
}
