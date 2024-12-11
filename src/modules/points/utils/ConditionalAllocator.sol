// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

abstract contract ConditionalAllocator {
    /// @notice mapping of voter to points
    /// @dev voter => points
    mapping(address => uint256) public points;

    /// @notice whether to accumulate points
    bool public shouldAccumulate;

    /// @notice Allocates points to the user
    /// @param _voter who is allocating their points
    /// @param _amount of points allocated
    function _allocatePoints(address _voter, uint256 _amount) internal {
        if (shouldAccumulate) {
            points[_voter] += _amount;
        }
    }

    /// @notice Releases points for the user
    /// @param _voter who is releasing their points
    /// @param _amount of points released
    function _releasePoints(address _voter, uint256 _amount) internal {
        if (shouldAccumulate) {
            require(points[_voter] >= _amount, "Not enough points");
            points[_voter] -= _amount;
        }
    }
}
