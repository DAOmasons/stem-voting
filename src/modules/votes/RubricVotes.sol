// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {IVotes} from "../../interfaces/IVotes.sol";
import {Contest} from "../../Contest.sol";
import {ModuleType} from "../../core/ModuleType.sol";

enum TimerType {
    None, // not timed
    Auto, // timer starts automatically on init
    Lazy, // timer starts from an external contract call, usually finalize choices in choice module
    Preset // preset time start at advance point in time (used for continuous and when choices are also timed)

}

abstract contract ConditionalTimer {
    /// @notice The start time of the voting period
    uint256 public startTime;

    /// @notice The end time of the voting period
    uint256 public endTime;

    /// @notice The duration of the voting period
    uint256 public duration;

    /// @notice The type of timer
    TimerType public timerType;

    modifier votingPeriod() {
        if (timerType == TimerType.None) {
            _;
        } else {
            require(block.timestamp >= startTime && block.timestamp <= endTime, "Not voting period");
            _;
        }
    }

    function _timerInit(TimerType _timerType, uint256 _startTime, uint256 _duration) internal {
        timerType = _timerType;
        duration = _duration;

        if (_timerType == TimerType.Auto) {
            require(_startTime == 0, "Auto timer cannot init start time");

            startTime = block.timestamp;
            endTime = startTime + _duration;
        }
        if (_timerType == TimerType.Preset) {
            startTime = _startTime;
            endTime = _startTime + _duration;
        }
    }

    function _startTimer() internal {
        require(timerType == TimerType.Lazy, "Invalid timer type");

        startTime = block.timestamp;
        endTime = startTime + duration;
    }
}

contract RubricVotes is ConditionalTimer, IVotes, Initializable {
    /// @notice Reference to the contest contract
    Contest public contest;
    /// @notice The name and version of the module
    string public constant MODULE_NAME = "TimedVotes_v0.2.0";

    /// @notice The type of module
    ModuleType public constant MODULE_TYPE = ModuleType.Votes;

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

    /// ===============================
    /// ========== Init ===============
    /// ===============================

    constructor() {}

    /// @notice Initializes the timed voting module
    /// @param _contest The address of the contest contract
    /// @param _initParams The initialization data
    /// @dev Bytes data includes the duration of the voting period
    function initialize(address _contest, bytes memory _initParams) public initializer {
        (uint256 _duration, uint256 _startTime, TimerType _timerType) =
            abi.decode(_initParams, (uint256, uint256, TimerType));

        contest = Contest(_contest);

        _timerInit(_timerType, _startTime, _duration);
    }

    function vote(address voter, bytes32 choiceId, uint256 amount, bytes memory data) external onlyContest {}

    function retractVote(address voter, bytes32 choiceId, uint256 amount, bytes memory data) external onlyContest {}

    function setTimer() external {
        _startTimer();
    }

    function finalizeVotes() external {}

    function getTotalVotesForChoice(bytes32 choiceId) external view returns (uint256) {}
}
