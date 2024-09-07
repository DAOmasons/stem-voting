// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import {Test, console} from "forge-std/Test.sol";

import {IVotes} from "openzeppelin-contracts/contracts/governance/utils/IVotes.sol";
import {IPoints} from "../../interfaces/IPoints.sol";
import {ModuleType} from "../../core/ModuleType.sol";
import {Metadata} from "../../core/Metadata.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/// @title ContextPoints
/// @author @jord<https://github.com/jordanlesich>
/// @notice Points module that tests a Dual Token voting strategy between a core DAO and a smaller community DAO (context token).
contract ContextPointsV0 is IPoints {
    /// ===============================
    /// ========== Events =============
    /// ===============================

    /// @notice Emitted when a user allocates points
    event PointsAllocated(address indexed user, uint256 amount, address token);

    /// @notice Emitted when a user releases points
    event PointsReleased(address indexed user, uint256 amount, address token);

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
    mapping(address => uint256) public daoTokenPoints;

    /// @notice Mapping of user to allocated points
    /// @dev voterAddress => allocated points
    mapping(address => uint256) public contextPoints;

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

        require(
            _daoToken != address(0) && _contextToken != address(0) && _contest != address(0) && _votingCheckpoint > 0,
            "Invalid init param"
        );

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

        (, address votingToken) = abi.decode(_data, (Metadata, address));
        require(isValidToken(votingToken), "Invalid token");

        if (votingToken == address(daoToken)) {
            daoTokenPoints[_user] += _amount;
        } else {
            contextPoints[_user] += _amount;
        }

        emit PointsAllocated(_user, _amount, votingToken);
    }

    /// @notice Releases points from a user
    /// @param _user The address of the user
    /// @param _amount The amount of points to release
    /// @param _data The voting token
    function releasePoints(address _user, uint256 _amount, bytes memory _data) external onlyContest {
        require(_amount > 0, "Amount must be greater than 0");

        (, address votingToken) = abi.decode(_data, (Metadata, address));

        require(isValidToken(votingToken), "Invalid token");

        if (votingToken == address(daoToken)) {
            require(daoTokenPoints[_user] >= _amount, "Insufficient points allocated");
            daoTokenPoints[_user] -= _amount;
        } else {
            require(contextPoints[_user] >= _amount, "Insufficient points allocated");
            contextPoints[_user] -= _amount;
        }

        emit PointsReleased(_user, _amount, votingToken);
    }

    /// @notice Claims points from the user
    /// @dev This contract does not require users to claim points. Will revert if called.
    function claimPoints(address, bytes memory) public pure {
        revert("This contract does not require users to claim points.");
    }

    /// @notice Gets the total available points for a user
    /// @param user The address of the user
    /// @param votingToken The voting token address
    function getPoints(address user, address votingToken) public view returns (uint256) {
        require(isValidToken(votingToken), "Invalid token");
        if (votingToken == address(daoToken)) {
            return daoToken.getPastVotes(user, votingCheckpoint);
        } else {
            return contextToken.balanceOf(user);
        }
    }

    /// @notice Checks if a user has the specified voting points
    /// @param _user The address of the user
    /// @param _amount The amount of points to check
    function hasVotingPoints(address _user, uint256 _amount, bytes memory _data) public view returns (bool) {
        (, address votingToken) = abi.decode(_data, (Metadata, address));

        uint256 totalVotingPoints = getPoints(_user, votingToken);

        if (votingToken == address(daoToken)) {
            return totalVotingPoints - daoTokenPoints[_user] >= _amount;
        } else {
            return totalVotingPoints - contextPoints[_user] >= _amount;
        }
    }

    /// @notice Checks if a user has allocated the specified amount
    /// @param _user The address of the user
    /// @param _amount The amount of points to check
    /// @param _data The voting token
    function hasAllocatedPoints(address _user, uint256 _amount, bytes memory _data) public view returns (bool) {
        (, address votingToken) = abi.decode(_data, (Metadata, address));

        require(isValidToken(votingToken), "Invalid token");

        if (votingToken == address(daoToken)) {
            return daoTokenPoints[_user] >= _amount;
        } else {
            return contextPoints[_user] >= _amount;
        }
    }

    /// @notice Checks if a token is valid
    /// @param _token The address of the token
    function isValidToken(address _token) public view returns (bool) {
        return _token == address(daoToken) || _token == address(contextToken);
    }
}
