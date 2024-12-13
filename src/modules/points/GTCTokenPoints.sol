// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {ModuleType} from "../../core/ModuleType.sol";
import {IPoints} from "../../interfaces/IPoints.sol";
import {IGTC} from "../../interfaces/IGTC.sol";

contract GTCTokenPoints is IPoints, Initializable {
    /// ===============================
    /// =========== Events ============
    /// ===============================
    /// @notice Emitted once the points module is initialized
    event Initialized(address contest, address tokenAddress, uint256 votingCheckpoint);

    /// ===============================
    /// =========== Storage ===========
    /// ===============================

    /// @notice The name and version of the module
    string public constant MODULE_NAME = "GTCTokenPoints_v0.2.0";

    /// @notice The type of module
    ModuleType public constant MODULE_TYPE = ModuleType.Points;

    /// @notice Reference to the contest contract
    address public contest;

    /// @notice The block checkpoint to use for voting balances
    uint256 public votingCheckpoint;

    /// @notice Mapping of user to allocated points
    /// @dev voterAddress => allocated points
    mapping(address => uint256) public allocatedPoints;

    /// @notice Reference to the voting token contract
    /// @dev This is the governance token for Gitcoin DAO
    IGTC public voteToken;

    /// @notice Only the contest contract can call this function
    /// @dev The caller must be the contest contract
    modifier onlyContest() {
        require(msg.sender == contest, "Only contest");
        _;
    }

    /// ===============================
    /// =========== init ==============
    /// ===============================

    constructor() {}

    function initialize(address _contest, bytes memory _data) public initializer {
        (address _tokenAddress, uint256 _votingCheckpoint) = abi.decode(_data, (address, uint256));

        contest = _contest;

        emit Initialized(_contest, _tokenAddress, _votingCheckpoint);
    }

    /// ===============================
    /// ========== Setters ============
    /// ===============================

    /// @notice Allocates points to a user to track the amount voted
    /// @param _user The address of the user
    /// @param _amount The amount of points to allocate
    function allocatePoints(address _user, uint256 _amount, bytes memory) external onlyContest {
        require(_amount > 0, "Amount must be greater than 0");

        // Note: This check is not needed when using the contest contract
        // require(hasVotingPoints(_user, _amount, _data), "Insufficient points available");

        allocatedPoints[_user] += _amount;
    }

    /// @notice Releases points from a user
    /// @param _user The address of the user
    /// @param _amount The amount of points to release
    function releasePoints(address _user, uint256 _amount, bytes memory) external onlyContest {
        require(_amount > 0, "Amount must be greater than 0");
        require(allocatedPoints[_user] >= _amount, "Insufficient points allocated");

        allocatedPoints[_user] -= _amount;
    }

    /// @notice Claims points from the user
    /// @dev This contract does not require users to claim points. Will revert if called.
    function claimPoints(address, bytes memory) public pure {
        revert("This contract does not require users to claim points.");
    }

    /// ===============================
    /// ========== Getters ============
    /// ===============================

    /// @notice Checks if a user has the specified voting points
    /// @param _user The address of the user
    /// @param _amount The amount of points to check
    function hasVotingPoints(address _user, uint256 _amount, bytes memory) public view returns (bool) {
        return voteToken.getPriorVotes(_user, votingCheckpoint) - allocatedPoints[_user] >= _amount;
    }

    /// @notice Checks if a user has allocated the specified amount
    /// @param _user The address of the user
    /// @param _amount The amount of points to check
    function hasAllocatedPoints(address _user, uint256 _amount, bytes memory) public view returns (bool) {
        return allocatedPoints[_user] >= _amount;
    }
}
