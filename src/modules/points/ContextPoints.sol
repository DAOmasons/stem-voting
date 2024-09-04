// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IVotes} from "openzeppelin-contracts/contracts/governance/utils/IVotes.sol";
import {IPoints} from "../../interfaces/IPoints.sol";
import {ModuleType} from "../../core/ModuleType.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/// @title ContextPoints
/// @author @jord<https://github.com/jordanlesich>
/// @notice Points module that tests a Dual Token voting strategy between a core DAO and a smaller community DAO (context token).
contract ContextPoints is IPoints {
    /// ===============================
    /// ========== Events =============
    /// ===============================

    /// @notice Emitted once the points module is initialized
    event Initialized(address contest, address daoToken, address contextToken, uint256 votingCheckpoint);

    /// ===============================
    /// ========== Storage ============
    /// ===============================

    /// @notice The name and version of the module
    string public constant MODULE_NAME = "DualTokenPoints_v0.0.1";

    /// @notice The type of module
    ModuleType public constant MODULE_TYPE = ModuleType.Points;

    /// @notice Reference to the voting token contract
    /// @dev This voting token must implement IVotes
    IVotes public daoToken;

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

    function initialize(address _contest, bytes calldata _initData) public {
        (address _daoToken, address _contextToken, uint256 _votingCheckpoint) =
            abi.decode(_initData, (address, address, uint256));

        votingCheckpoint = _votingCheckpoint;
        daoToken = IVotes(_daoToken);
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

    function releasePoints(address _user, uint256 _amount, bytes memory) external onlyContest {
        // require(_amount > 0, "Amount must be greater than 0");
        // require(allocatedPoints[_user] >= _amount, "Insufficient points allocated");

        // allocatedPoints[_user] -= _amount;

        // emit PointsReleased(_user, _amount);
    }

    function claimPoints(address, bytes memory) public pure {
        revert("This contract does not require users to claim points.");
    }

    /// @notice Checks if a user has the specified voting points
    /// @param _user The address of the user
    /// @param _amount The amount of points to check
    function hasVotingPoints(address _user, uint256 _amount, bytes memory _data) public view returns (bool) {
        (, address votingToken) = abi.decode(_data, (uint8, address));

        require(isValidToken(votingToken), "Invalid voting token");

        if (votingToken == address(daoToken)) {
            return daoToken.getPastVotes(_user, votingCheckpoint) >= _amount;
        } else {
            return contextToken.balanceOf(_user) >= _amount;
        }

        // return getPoints(_user) >= _amount;
    }

    function hasAllocatedPoints(address _user, uint256 _amount, bytes memory) public view returns (bool) {
        // return getAllocatedPoints(_user) >= _amount;
    }

    function isValidToken(address _token) public view returns (bool) {
        return _token == address(daoToken) || _token == address(contextToken);
    }
}
