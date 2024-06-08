// SPDX-License-Identifier: MIT
import "forge-std/Test.sol";

pragma solidity ^0.8.13;

import {IVotes} from "openzeppelin-contracts/contracts/governance/utils/IVotes.sol";
import {IPoints} from "../../interfaces/IPoints.sol";
import {ModuleType} from "../../core/ModuleType.sol";

/// @title ERC20VotesPoints
/// @author @jord<https://github.com/jordanlesich>, @dekanbro<https://github.com/dekanbro>
/// @notice Points module that uses ERC20Votes to allocate points to voters based on their delegated voting balance at particular checkpoints
contract ERC20VotesPoints is IPoints {
    /// ===============================
    /// ========== Events =============
    /// ===============================

    /// @notice Emitted once the points module is initialized
    event Initialized(address contest, address token, uint256 votingCheckpoint);

    /// ===============================
    /// ========== Storage ============
    /// ===============================

    /// @notice The name and version of the module
    string public constant MODULE_NAME = "ERC20VotesPoints_v0.1.1";

    /// @notice The type of module
    ModuleType public constant MODULE_TYPE = ModuleType.Execution;

    /// @notice Reference to the voting token contract
    /// @dev This voting token must implement IVotes
    IVotes public voteToken;

    /// @notice The block checkpoint to use for voting balances
    uint256 public votingCheckpoint;

    /// @notice Reference to the contest contract
    address public contest;

    /// @notice Mapping of user to allocated points
    /// @dev voterAddress => allocated points
    mapping(address => uint256) public allocatedPoints;

    /// ===============================
    /// ========== Modifiers ==========
    /// ===============================

    /// @notice Only the contest contract can call this function
    /// @dev The caller must be the contest contract
    modifier onlyContest() {
        require(msg.sender == contest, "Only contest");
        _;
    }

    /// ===============================
    /// ========== Init ===============
    /// ===============================

    constructor() {}

    /// @notice Initializes the points module
    /// @param _contest The address of the contest contract
    /// @param _initData The initialization data
    /// @dev Bytes data includes the address of the voting token and the voting checkpoint
    function initialize(address _contest, bytes calldata _initData) public {
        (address _token, uint256 _votingCheckpoint) = abi.decode(_initData, (address, uint256));

        votingCheckpoint = _votingCheckpoint;
        voteToken = IVotes(_token);
        contest = _contest;

        emit Initialized(_contest, _token, _votingCheckpoint);
    }

    /// ===============================
    /// ========== Setters ============
    /// ===============================

    /// @notice Allocates points to a user to track the amount voted
    /// @param _user The address of the user
    /// @param _amount The amount of points to allocate
    function allocatePoints(address _user, uint256 _amount) external onlyContest {
        require(_amount > 0, "Amount must be greater than 0");
        require(hasVotingPoints(_user, _amount), "Insufficient points available");

        allocatedPoints[_user] += _amount;

        emit PointsAllocated(_user, _amount);
    }

    /// @notice Releases points from a user
    /// @param _user The address of the user
    /// @param _amount The amount of points to release
    function releasePoints(address _user, uint256 _amount) external onlyContest {
        require(_amount > 0, "Amount must be greater than 0");
        require(allocatedPoints[_user] >= _amount, "Insufficient points allocated");

        allocatedPoints[_user] -= _amount;

        emit PointsReleased(_user, _amount);
    }

    /// @notice Claims points from the user
    /// @dev This contract does not require users to claim points. Will revert if called.
    function claimPoints() public pure {
        revert("This contract does not require users to claim points.");
    }

    /// ===============================
    /// ========== Getters ============
    /// ===============================

    /// @notice Gets the allocated points for a user
    /// @param _user The address of the user
    function getAllocatedPoints(address _user) public view returns (uint256) {
        return allocatedPoints[_user];
    }

    /// @notice Gets the available points for a user
    /// @param _user The address of the user
    function getPoints(address _user) public view returns (uint256) {
        uint256 totalVotingPoints = voteToken.getPastVotes(_user, votingCheckpoint);

        uint256 allocatedVotingPoints = allocatedPoints[_user];

        return totalVotingPoints - allocatedVotingPoints;
    }

    /// @notice Checks if a user has the specified voting points
    /// @param _user The address of the user
    /// @param _amount The amount of points to check
    function hasVotingPoints(address _user, uint256 _amount) public view returns (bool) {
        return getPoints(_user) >= _amount;
    }

    /// @notice Checks if a user has allocated the specified amount
    /// @param _user The address of the user
    /// @param _amount The amount of points to check
    function hasAllocatedPoints(address _user, uint256 _amount) public view returns (bool) {
        return getAllocatedPoints(_user) >= _amount;
    }
}
