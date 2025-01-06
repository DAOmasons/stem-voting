// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoints} from "../../interfaces/IPoints.sol";
import {ModuleType} from "../../core/ModuleType.sol";

contract EmptyPoints is IPoints {
    string public constant MODULE_NAME = "EmptyPoints_v0.1.0";

    ModuleType public constant MODULE_TYPE = ModuleType.Points;

    function initialize(address _contest, bytes calldata initData) external {}

    function claimPoints(address, bytes memory) external pure {
        revert("This contract does not require users to claim points.");
    }

    function allocatePoints(address, uint256, bytes memory) external {}

    function releasePoints(address, uint256, bytes memory) external {}

    function hasVotingPoints(address, uint256, bytes memory) external pure returns (bool) {
        return true;
    }

    function hasAllocatedPoints(address, uint256, bytes memory) external pure returns (bool) {
        return true;
    }
}
