// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IVotes} from "openzeppelin-contracts/contracts/governance/utils/IVotes.sol";
import {IPoints} from "../../interfaces/IPoints.sol";

contract ERC20VotesPoints is IPoints {
    IVotes public voteToken;
    uint256 public votingCheckpoint;
    address public contest;

    mapping(address => uint256) public allocatedPoints;

    modifier onlyContest() {
        require(msg.sender == contest, "Only contest");
        _;
    }

    constructor() {}

    function initialize(address _contest, bytes calldata _initData) public {
        (address _token, uint256 _votingCheckpoint) = abi.decode(_initData, (address, uint256));

        votingCheckpoint = _votingCheckpoint;
        voteToken = IVotes(_token);
        contest = _contest;
    }

    function getAllocatedPoints(address _user) public view returns (uint256) {
        return allocatedPoints[_user];
    }

    function getPoints(address _user) public view returns (uint256) {
        uint256 totalVotingPoints = voteToken.getPastVotes(_user, votingCheckpoint);
        uint256 allocatedVotingPoints = allocatedPoints[_user];

        return totalVotingPoints - allocatedVotingPoints;
    }

    function hasVotingPoints(address _user, uint256 _amount) public view returns (bool) {
        return getPoints(_user) >= _amount;
    }

    function allocatePoints(address _user, uint256 _amount) external onlyContest {
        require(_amount > 0, "Amount must be greater than 0");
        require(hasVotingPoints(_user, _amount), "Insufficient points available");

        allocatedPoints[_user] += _amount;
    }

    function releasePoints(address _user, uint256 _amount) external onlyContest {
        require(_amount > 0, "Amount must be greater than 0");
        require(allocatedPoints[_user] >= _amount, "Insufficient points allocated");

        allocatedPoints[_user] -= _amount;
    }

    function claimPoints() public pure {
        revert("This contract does not require users to claim points.");
    }
}
