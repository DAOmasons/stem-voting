// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ContestStatus} from "../../core/ContestStatus.sol";
import {Contest} from "../../Contest.sol";
import {IExecution} from "../../interfaces/IExecution.sol";

contract EmptyExecution is IExecution {
    string public constant MODULE_NAME = "EmptyExecution_v0.1.1";

    Contest public contest;

    function initialize(address _contest, bytes memory) public {
        contest = Contest(_contest);
    }

    function execute(bytes memory) public {
        require(contest.getStatus() == ContestStatus.Finalized, "Contest is not finalized");
        contest.execute();
    }
}
