// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ContestStatus} from "../../src/core/ContestStatus.sol";

contract MockContest {
    ContestStatus public contestStatus;

    constructor(ContestStatus _status) {
        contestStatus = _status;
    }

    function cheatStatus(ContestStatus _status) public {
        contestStatus = _status;
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
        contestStatus = ContestStatus.Finalized;
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
