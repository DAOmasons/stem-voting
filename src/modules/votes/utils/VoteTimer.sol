// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

enum TimerType {
    None, // not timed
    Auto, // timer starts automatically on init
    Lazy, // timer starts from an external contract call, usually finalize choices in choice module
    Preset // preset time start at advance point in time (used for continuous and when choices are also timed)

}

abstract contract VoteTimer {
    event TimerSet(uint256 startTime, uint256 endTime);

    /// @notice The start time of the voting period
    uint256 public startTime;

    /// @notice The end time of the voting period
    uint256 public endTime;

    /// @notice The duration of the voting period
    uint256 public duration;

    /// @notice The type of timer
    TimerType public timerType;

    bool public timerSet;

    modifier onlyVotingPeriod() {
        if (timerType == TimerType.None) {
            _;
        } else {
            require(block.timestamp >= startTime && block.timestamp <= endTime, "Not voting period");
            _;
        }
    }

    modifier onlyVoteCompleted() {
        if (timerType == TimerType.None) {
            _;
        } else {
            require(hasVoteCompleted(), "Voting period not completed");
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

    function _startTimer() internal {
        require(timerType == TimerType.Lazy, "Invalid timer type");

        startTime = block.timestamp;
        endTime = startTime + duration;
        timerSet = true;
        emit TimerSet(startTime, endTime);
    }

    function hasVoteCompleted() internal view returns (bool) {
        return block.timestamp >= endTime && timerSet;
    }
}
