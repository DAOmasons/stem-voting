// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IModule} from "./IModule.sol";

interface IPoints is IModule {
    event PointsAllocated(address indexed user, uint256 amount);

    event PointsReleased(address indexed user, uint256 amount);

    event PointsClaimed(address indexed user, uint256 amount);

    function claimPoints(address voter, bytes memory data) external;

    function allocatePoints(address voter, uint256 amount, bytes memory data) external;

    function releasePoints(address voter, uint256 amount, bytes memory data) external;

    function getPoints(address voter) external view returns (uint256);

    function hasVotingPoints(address voter, uint256 amount) external view returns (bool);

    function hasAllocatedPoints(address voter, uint256 amount) external view returns (bool);
}
