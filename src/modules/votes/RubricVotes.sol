// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {IVotes} from "../../interfaces/IVotes.sol";
import {Contest} from "../../Contest.sol";
import {ModuleType} from "../../core/ModuleType.sol";
import {VoteTimer, TimerType} from "./utils/VoteTimer.sol";
import {Metadata} from "../../core/Metadata.sol";
import {IHatsPoints} from "../../interfaces/IHatsPoints.sol";
import {IHats} from "lib/hats-protocol/src/Interfaces/IHats.sol";

contract RubricVotes is VoteTimer, IVotes, Initializable {
    /// @notice Emitted when the contract is initialized
    event Initialized(address _contest, uint256 _startTime, TimerType _timerType, uint256 _adminHatId);

    /// @notice Emitted when a vote is cast
    event VoteCast(address voter, bytes32 choiceId, uint256 amount, Metadata _reason);

    /// @notice Emitted when a vote is retracted
    event VoteRetracted(address voter, bytes32 choiceId, uint256 amount, Metadata _reason);

    /// @notice Reference to the contest contract
    Contest public contest;

    /// @notice The name and version of the module
    string public constant MODULE_NAME = "RubricVotes_v0.2.0";

    /// @notice The type of module
    ModuleType public constant MODULE_TYPE = ModuleType.Votes;

    /// @notice Mapping of choiceId to voter to vote amount
    /// @dev choiceId => voter => amount
    mapping(bytes32 => mapping(address => uint256)) public votes;

    /// @notice Mapping of choiceId to total votes for that choice
    /// @dev choiceId => totalVotes
    mapping(bytes32 => uint256) public totalVotesForChoice;

    /// @notice points module address
    address pointsModule;

    /// @notice admin hat id
    uint256 adminHatId;

    /// @notice Reference to the Hats Protocol contract
    IHats hats;

    /// ===============================
    /// ========== Modifiers ==========
    /// ===============================

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

    /// ===============================
    /// ========== Init ===============
    /// ===============================

    constructor() {}

    /// @notice Initializes the timed voting module
    /// @param _contest The address of the contest contract
    /// @param _initParams The initialization data
    /// @dev Bytes data includes the duration of the voting period
    function initialize(address _contest, bytes memory _initParams) public initializer {
        (uint256 _duration, uint256 _startTime, TimerType _timerType, uint256 _adminHatId, address _hats) =
            abi.decode(_initParams, (uint256, uint256, TimerType, uint256, address));

        hats = IHats(_hats);

        contest = Contest(_contest);

        adminHatId = _adminHatId;

        _timerInit(_timerType, _startTime, _duration);

        emit Initialized(_contest, _startTime, _timerType, _adminHatId);
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
        (uint256[] memory hatIds, Metadata memory _reason) = abi.decode(_data, (uint256[], Metadata));

        uint256 amountAlreadyVoted = votes[_choiceId][_voter];

        uint256 totalHatsAllowance;

        if (pointsModule == address(0)) {
            address _pointsModule = address(contest.pointsModule());

            if (_pointsModule == address(0)) {
                revert("Points module not initialized");
            }

            pointsModule = _pointsModule;
        }

        for (uint256 i = 0; i < hatIds.length; i++) {
            try IHatsPoints(pointsModule).getPointsByHat(hatIds[i]) returns (uint256 points) {
                totalHatsAllowance += points;
            } catch {
                revert("Points module not support IHatsPoints");
            }
        }

        require(_amount <= totalHatsAllowance - amountAlreadyVoted, "Insufficient voting power");

        votes[_choiceId][_voter] += _amount;
        totalVotesForChoice[_choiceId] += _amount;

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
        (, Metadata memory _reason) = abi.decode(_data, (uint256[], Metadata));
        uint256 votedAmount = votes[_choiceId][_voter];
        require(votedAmount >= _amount, "Retracted amount exceeds vote amount");

        votes[_choiceId][_voter] -= _amount;
        totalVotesForChoice[_choiceId] -= _amount;

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
