// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

abstract contract ConditionalAllocator {
    mapping(address => uint256) public points;

    bool public shouldAccumulate;

    function _allocatePoints(address _voter, uint256 _amount) internal {
        if (shouldAccumulate) {
            points[_voter] += _amount;
        }
    }

    function _releasePoints(address _voter, uint256 _amount) internal {
        if (shouldAccumulate) {
            require(points[_voter] >= _amount, "Not enough points");
            points[_voter] -= _amount;
        }
    }
}
