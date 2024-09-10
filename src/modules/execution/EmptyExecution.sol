// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

import {ContestStatus} from "../../core/ContestStatus.sol";
import {Contest} from "../../Contest.sol";
import {IExecution} from "../../interfaces/IExecution.sol";
import {ModuleType} from "../../core/ModuleType.sol";

contract EmptyExecution is IExecution, Initializable {
    string public constant MODULE_NAME = "EmptyExecution_v0.1.1";

    ModuleType public constant MODULE_TYPE = ModuleType.Execution;

    Contest public contest;

    function initialize(address _contest, bytes memory) public initializer {
        contest = Contest(_contest);
    }

    function execute(bytes memory) public {
        require(contest.getStatus() == ContestStatus.Finalized, "Contest is not finalized");
        contest.execute();
    }
}
