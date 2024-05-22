// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ContestStatus} from "../../core/ContestStatus.sol";
import {Contest} from "../../Contest.sol";

contract EmptyExecution {
    Contest public contest;

    function initialize(address _contest, bytes memory) public {
        contest = Contest(_contest);
    }

    function execute() public {
        require(contest.getStatus() == ContestStatus.Finalized, "Contest is not finalized");
        contest.execute();
    }
}
