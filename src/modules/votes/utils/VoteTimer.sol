// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

enum TimerType {
    None, // not timed
    Auto, // timer starts automatically on init
    Lazy, // timer starts from an external contract call, usually finalize choices in choice module
    Preset // preset time start at advance point in time (used for continuous and when choices are also timed)

}

abstract contract VoteTimer {
    /// @notice Emitted when the timer is set
    event TimerSet(uint256 startTime, uint256 endTime);

    /// @notice The start time of the voting period
    uint256 public startTime;

    /// @notice The end time of the voting period
    uint256 public endTime;

    /// @notice The duration of the voting period
    uint256 public duration;

    /// @notice The type of timer
    TimerType public timerType;

    /// @notice Whether the timer has been set
    bool public timerSet;

    /// @notice The caller must be in the voting period. If no timer is used this passes.
    modifier onlyVotingPeriod() {
        if (timerType == TimerType.None) {
            _;
        } else {
            require(block.timestamp >= startTime && block.timestamp <= endTime, "Not voting period");
            _;
        }
    }

    /// @notice Only passes if the module is timed, voting is set, and voting is complete
    modifier onlyVoteCompleted() {
        if (timerType == TimerType.None) {
            _;
        } else {
            require(hasVoteCompleted(), "Voting period not completed");
            _;
        }
    }

    /// @notice Initializes the voting period timer
    /// @param _timerType The type of timer
    /// @param _startTime The start time of the voting period
    /// @param _duration The duration of the voting period
    function _timerInit(TimerType _timerType, uint256 _startTime, uint256 _duration) internal {
        timerType = _timerType;
        duration = _duration;

        if (_timerType == TimerType.Auto) {
            require(_startTime == 0, "Auto timer cannot init start time");

            startTime = block.timestamp;
            endTime = startTime + _duration;
            timerSet = true;
            emit TimerSet(startTime, endTime);
        }
        if (_timerType == TimerType.Preset) {
            startTime = _startTime;
            endTime = _startTime + _duration;
            timerSet = true;
            emit TimerSet(startTime, endTime);
        }
    }

    /// @notice Starts the voting period timer
    /// @dev Only usable for lazy timers
    function _startTimer() internal {
        require(timerType == TimerType.Lazy, "Invalid timer type");

        startTime = block.timestamp;
        endTime = startTime + duration;
        timerSet = true;
        emit TimerSet(startTime, endTime);
    }

    /// @notice Returns whether the timer has been set and voting period has completed
    function hasVoteCompleted() internal view returns (bool) {
        return block.timestamp >= endTime && timerSet;
    }
}
