// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ContestStatus} from "../../src/core/ContestStatus.sol";

contract MockContest {
    ContestStatus public contestStatus;

    bool public isContinuous;

    constructor(ContestStatus _status) {
        contestStatus = _status;
    }

    function cheatStatus(ContestStatus _status) public {
        contestStatus = _status;
    }

    function cheatContinuous(bool _isContinuous) public {
        isContinuous = _isContinuous;
    }

    function getStatus() public view returns (ContestStatus) {
        return contestStatus;
    }

    function isStatus(ContestStatus _status) public view returns (bool) {
        return contestStatus == _status;
    }

    function finalizeVoting() external {
        contestStatus = ContestStatus.Finalized;
    }

    function finalizeChoices() external {
        contestStatus = ContestStatus.Voting;
    }
}

contract MockContestSetup {
    MockContest public _mockContest;

    function __setupMockContest() public {
        _mockContest = new MockContest(ContestStatus.None);
    }

    function mockContest() public view returns (MockContest) {
        return _mockContest;
    }
}
