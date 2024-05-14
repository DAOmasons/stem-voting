// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IPoints {
    /**
     * @dev Event emitted when a user claims voting points.
     * @param user The address of the user claiming the points.
     * @param amount The number of points claimed.
     */
    event PointsClaimed(address indexed user, uint256 amount);

    /**
     * @dev Event emitted when voting points are allocated for a user.
     * @param user The address of the user for whom points are allocated.
     * @param amount The amount of points allocated.
     */
    event PointsAllocated(address indexed user, uint256 amount);

    /**
     * @dev Event emitted when voting points are released for a user.
     * @param user The address of the user for whom points are released.
     * @param amount The amount of points released.
     */
    event PointsReleased(address indexed user, uint256 amount);

    /**
     * @dev Users claim their voting points based on their current token balance.
     * Points are calculated as the total token balance minus any already allocated points.
     */
    function claimPoints() external;

    /**
     * @dev Allocate points for voting, reducing the available points and increasing the allocated points.
     * @param voter The address of the voter who is allocating points.
     * @param amount The number of points to allocate.
     */
    function allocatePoints(address voter, uint256 amount) external;

    /**
     * @dev Release points after voting, moving them from allocated to available.
     * @param voter The address of the voter who is releasing points.
     * @param amount The number of points to release.
     */
    function releasePoints(address voter, uint256 amount) external;

    /**
     * @dev Retrieve the current available voting points for a user.
     * @param user The address of the user to query voting points.
     * @return The current number of available voting points for the user.
     */
    function getPoints(address user) external view returns (uint256);

    function hasVotingPoints(address user, uint256 amount) external view returns (bool);

    function hasAllocatedPoints(address user, uint256 amount) external view returns (bool);
}
