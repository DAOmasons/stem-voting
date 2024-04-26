// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../interfaces/IERC20.sol";
import "../../interfaces/IPoints.sol";

// ERC20 balanceOf Points contract
contract Points is IPoints {
    IERC20 public token;
    uint256 public claimEndTime;
    address public contest;
    mapping(address => uint256) public totalVotingPoints; // Total points that a user can use for voting
    mapping(address => uint256) public allocatedPoints; // Points currently allocated for voting

    //TODO initializer, should take bytes to destructure
    function setUp(address _contest, IERC20 _token, uint256 duration) public {
        contest = _contest;
        token = _token;
        claimEndTime = block.timestamp + duration;
    }

    modifier onlyContest() {
        require(msg.sender == contest, "Only contest");
        _;
    }

    // Users claim their voting points based on their current token balance
    // TODO: this needs to prevent double vote
    // TODO: keep track of claims so they only happen once
    function claimPoints() public onlyContest {
        uint256 balance = token.balanceOf(msg.sender);
        uint256 claimablePoints = balance - allocatedPoints[msg.sender];
        require(claimablePoints > 0, "No points available to claim");
        totalVotingPoints[msg.sender] = claimablePoints;
        emit PointsClaimed(msg.sender, claimablePoints);
    }

    function allocatePoints(address voter, uint256 amount) public onlyContest {
        require(
            totalVotingPoints[voter] >= amount,
            "Insufficient points available"
        );
        totalVotingPoints[voter] -= amount;
        allocatedPoints[voter] += amount;
    }

    function releasePoints(address voter, uint256 amount) public onlyContest {
        require(
            allocatedPoints[voter] >= amount,
            "Insufficient points allocated"
        );
        allocatedPoints[voter] -= amount;
        totalVotingPoints[voter] += amount;
    }

    // Retrieve the current available voting points for a user
    function getPoints(address user) external view override returns (uint256) {
        return totalVotingPoints[user];
    }
}
