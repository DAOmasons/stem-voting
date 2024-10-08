// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {IVotes} from "openzeppelin-contracts/contracts/governance/utils/IVotes.sol";
import {IPoints} from "../../interfaces/IPoints.sol";
import {ModuleType} from "../../core/ModuleType.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// REFERENCE CONTRACT ONLY.

// An improved version of this contract is implemented as DualRegistryPointsV0

// Why?
// - New standards implement the IVotes interface
// - New standards implement the Contest interface
// - A better pattern and more pure pattern can be implemented with these new interfaces.

/// @title DualTokenPoints
/// @author @jord<https://github.com/jordanlesich>
/// @notice Points module that tests a Dual Token voting strategy between a core DAO and a smaller community DAO (context token).
contract DualTokenPointsV0 is IPoints, Initializable {
    /// ===============================
    /// ========== Events =============
    /// ===============================

    /// @notice Emitted once the points module is initialized
    event Initialized(address contest, address daoToken, address contextToken, uint256 votingCheckpoint);

    /// ===============================
    /// ========== Storage ============
    /// ===============================

    /// @notice The name and version of the module
    string public constant MODULE_NAME = "DualTokenPoints_v0.2.0";

    /// @notice The type of module
    ModuleType public constant MODULE_TYPE = ModuleType.Points;

    /// @notice Reference to the voting token contract
    /// @dev This voting token must implement IVotes
    IVotes public voteToken;

    /// @notice The soul-bound token for community context voting points
    /// @dev Since this voting token is soul-bound, it can collect voting power from Balance
    IERC20 public contextToken;

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
    function initialize(address _contest, bytes calldata _initData) public initializer {
        (address _daoToken, address _contextToken, uint256 _votingCheckpoint) =
            abi.decode(_initData, (address, address, uint256));

        votingCheckpoint = _votingCheckpoint;
        voteToken = IVotes(_daoToken);
        contextToken = IERC20(_contextToken);
        contest = _contest;

        emit Initialized(_contest, _daoToken, _contextToken, _votingCheckpoint);
    }

    /// ===============================
    /// ========== Setters ============
    /// ===============================

    /// @notice Allocates points to a user to track the amount voted
    /// @param _user The address of the user
    /// @param _amount The amount of points to allocate
    function allocatePoints(address _user, uint256 _amount, bytes memory _data) external onlyContest {
        require(_amount > 0, "Amount must be greater than 0");
        require(hasVotingPoints(_user, _amount, _data), "Insufficient points available");

        allocatedPoints[_user] += _amount;

        emit PointsAllocated(_user, _amount);
    }

    /// @notice Releases points from a user
    /// @param _user The address of the user
    /// @param _amount The amount of points to release
    function releasePoints(address _user, uint256 _amount, bytes memory) external onlyContest {
        require(_amount > 0, "Amount must be greater than 0");
        require(allocatedPoints[_user] >= _amount, "Insufficient points allocated");

        allocatedPoints[_user] -= _amount;

        emit PointsReleased(_user, _amount);
    }

    /// @notice Claims points from the user
    /// @dev This contract does not require users to claim points. Will revert if called.
    function claimPoints(address, bytes memory) public pure {
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

    /// @notice Gets a user's voting power for the DAO token
    /// @param _user The address of the user
    function getDaoVotingPower(address _user) public view returns (uint256) {
        return voteToken.getPastVotes(_user, votingCheckpoint);
    }

    /// @notice Gets a user's voting power for the context token
    /// @param _user The address of the user
    function getContextVotingPower(address _user) public view returns (uint256) {
        return contextToken.balanceOf(_user);
    }

    /// @notice Gets the aggregate voting power for a user, between the DAO token and context token
    /// @param _user The address of the user
    function getAggregateVotingPower(address _user) public view returns (uint256) {
        uint256 daoVotingPower = voteToken.getPastVotes(_user, votingCheckpoint);
        uint256 contextVotingPower = contextToken.balanceOf(_user);
        return daoVotingPower + contextVotingPower;
    }

    /// @notice Gets the available points for a user
    /// @param _user The address of the user
    function getPoints(address _user) public view returns (uint256) {
        uint256 totalVotingPoints = getAggregateVotingPower(_user);

        uint256 allocatedVotingPoints = allocatedPoints[_user];

        return totalVotingPoints - allocatedVotingPoints;
    }

    /// @notice Checks if a user has the specified voting points
    /// @param _user The address of the user
    /// @param _amount The amount of points to check
    function hasVotingPoints(address _user, uint256 _amount, bytes memory) public view returns (bool) {
        return getPoints(_user) >= _amount;
    }

    /// @notice Checks if a user has allocated the specified amount
    /// @param _user The address of the user
    /// @param _amount The amount of points to check
    function hasAllocatedPoints(address _user, uint256 _amount, bytes memory) public view returns (bool) {
        return getAllocatedPoints(_user) >= _amount;
    }
}
