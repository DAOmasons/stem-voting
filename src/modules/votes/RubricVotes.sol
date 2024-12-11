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

    address pointsModule;

    uint256 adminHatId;

    IHats private _hats;

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
            _hats.isWearerOfHat(msg.sender, adminHatId) && _hats.isInGoodStanding(msg.sender, adminHatId), "Only wearer"
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
        (uint256 _duration, uint256 _startTime, TimerType _timerType, uint256 _adminHatId) =
            abi.decode(_initParams, (uint256, uint256, TimerType, uint256));

        contest = Contest(_contest);

        adminHatId = _adminHatId;

        _timerInit(_timerType, _startTime, _duration);
    }

    function vote(address voter, bytes32 choiceId, uint256 amount, bytes memory data)
        external
        onlyContest
        onlyVotingPeriod
    {
        (uint256[] memory hatIds, Metadata memory _reason) = abi.decode(data, (uint256[], Metadata));

        uint256 amountAlreadyVoted = votes[choiceId][voter];

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

        require(amount <= totalHatsAllowance - amountAlreadyVoted, "Insufficient voting power");

        votes[choiceId][voter] += amount;
        totalVotesForChoice[choiceId] += amount;
    }

    function retractVote(address voter, bytes32 choiceId, uint256 amount, bytes memory data)
        external
        onlyContest
        onlyVotingPeriod
    {
        uint256 votedAmount = votes[choiceId][voter];
        require(votedAmount >= amount, "Retracted amount exceeds vote amount");

        votes[choiceId][voter] -= amount;
        totalVotesForChoice[choiceId] -= amount;
    }

    function startTimer() external onlyAdmin {
        _startTimer();
    }

    function finalizeVotes() external onlyVoteCompleted onlyAdmin {
        contest.finalizeVoting();
    }

    function getTotalVotesForChoice(bytes32 choiceId) external view returns (uint256) {
        return totalVotesForChoice[choiceId];
    }
}
