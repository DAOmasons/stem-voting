// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../../interfaces/IERC20.sol";
import "../../interfaces/IPoints.sol";
import "../../core/ModuleType.sol";

// ERC20 balanceOf Points contract
contract ERC20Balance is IPoints {
    /// @notice The name and version of the module
    string public constant MODULE_NAME = "ERC20Balance_v0.2.0";

    /// @notice The type of module
    ModuleType public constant MODULE_TYPE = ModuleType.Choices;

    IERC20 public token;
    uint256 public claimEndTime;
    address public contest;
    mapping(address => uint256) public totalVotingPoints; // Total points that a user can use for voting
    mapping(address => uint256) public allocatedPoints; // Points currently allocated for voting

    //TODO initializer, should take bytes to destructure
    function initialize(address _contest, bytes memory _initData) public {
        (address _tokenAddress, uint256 duration) = abi.decode(_initData, (address, uint256));
        contest = _contest;
        token = IERC20(_tokenAddress);
        claimEndTime = block.timestamp + duration;
    }

    modifier onlyContest() {
        require(msg.sender == contest, "Only contest");
        _;
    }

    // Users claim their voting points based on their current token balance
    // TODO: this needs to prevent double vote
    // TODO: keep track of claims so they only happen once
    function claimPoints(address _voter, bytes memory) public onlyContest {
        uint256 balance = token.balanceOf(_voter);
        uint256 claimablePoints = balance - allocatedPoints[_voter];
        require(claimablePoints > 0, "No points available to claim");
        totalVotingPoints[_voter] = claimablePoints;
        emit PointsClaimed(_voter, claimablePoints);
    }

    function allocatePoints(address voter, uint256 amount, bytes memory) public onlyContest {
        require(totalVotingPoints[voter] >= amount, "Insufficient points available");
        totalVotingPoints[voter] -= amount;
        allocatedPoints[voter] += amount;
    }

    function releasePoints(address voter, uint256 amount, bytes memory) public onlyContest {
        require(allocatedPoints[voter] >= amount, "Insufficient points allocated");
        allocatedPoints[voter] -= amount;
        totalVotingPoints[voter] += amount;
    }

    // Retrieve the current available voting points for a user
    function getPoints(address user) external view returns (uint256) {
        return totalVotingPoints[user];
    }

    function hasAllocatedPoints(address user, uint256 amount, bytes memory) external view returns (bool) {
        return allocatedPoints[user] >= amount;
    }

    function hasVotingPoints(address user, uint256 amount, bytes memory) external view override returns (bool) {
        return totalVotingPoints[user] >= amount;
    }
}
