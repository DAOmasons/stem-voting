// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoints} from "../../interfaces/IPoints.sol";
import {Initializable} from "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ModuleType} from "../../core/ModuleType.sol";

contract MerklePoints is IPoints, Initializable {
    /// @notice Emitted once the points module is initialized
    event Initialized(address contest, bytes32 merkleRoot);

    /// @notice The root of the merkle tree
    bytes32 public merkleRoot;

    /// @notice The name and version of the module
    string public constant MODULE_NAME = "MerklePoints_v0.2.0";

    /// @notice The type of module
    ModuleType public constant MODULE_TYPE = ModuleType.Points;

    /// @notice Reference to the contest contract
    address public contest;

    /// @notice Mapping of user to allocated points
    /// @dev voterAddress => allocated points
    mapping(address => uint256) public allocatedPoints;

    /// @notice Only the contest contract can call this function
    /// @dev The caller must be the contest contract
    modifier onlyContest() {
        require(msg.sender == contest, "Only contest");
        _;
    }

    constructor() {}

    function initialize(address _contest, bytes memory _data) public initializer {
        (bytes32 _merkleRoot) = abi.decode(_data, (bytes32));

        contest = _contest;
        merkleRoot = _merkleRoot;

        emit Initialized(_contest, _merkleRoot);
    }

    function claimPoints(address, bytes memory) external pure {
        revert("Claim points disabled");
    }

    /// @notice Allocates points to a user to track the amount voted
    /// @param _voter The address of the user
    /// @param _amount The amount of points to allocate
    /// @param _data contains proof and user total vote amount
    function allocatePoints(address _voter, uint256 _amount, bytes memory _data) external onlyContest {
        require(_amount > 0, "Amount must be greater than 0");
        require(hasVotingPoints(_voter, _amount, _data), "Insufficient points available");

        allocatedPoints[_voter] += _amount;
    }

    /// @notice Releases points from a user
    /// @param _voter The address of the user
    /// @param _amount The amount of points to release
    function releasePoints(address _voter, uint256 _amount, bytes memory) external onlyContest {
        require(_amount > 0, "Amount must be greater than 0");

        // If this contract is not going to be used with the contest contract, use this check
        // require(allocatedPoints[_voter] >= _amount, "Insufficient points allocated");

        allocatedPoints[_voter] -= _amount;
    }

    ///@notice Verifies if a user has the claimed points using OpenZeppelin's MerkleProof
    ///@param _user The address of the user
    ///@param _points The number of points claimed
    ///@param _proof The Merkle proof as an array of bytes32
    function verifyPoints(address _user, uint256 _points, bytes32[] memory _proof) public view returns (bool) {
        // Change to match StandardMerkleTree's leaf encoding
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(_user, _points))));
        return MerkleProof.verify(_proof, merkleRoot, leaf);
    }

    /// @notice Checks if a user has the specified voting points
    /// @param _voter The address of the user
    /// @param _amount The amount of points to check
    /// @param _data contains proof and user total vote amount
    function hasVotingPoints(address _voter, uint256 _amount, bytes memory _data) public view returns (bool) {
        (bytes32[] memory _proof, uint256 _totalUserVotes) = abi.decode(_data, (bytes32[], uint256));

        require(verifyPoints(_voter, _totalUserVotes, _proof), "User input data does not match merkle proof");

        return _totalUserVotes - allocatedPoints[_voter] >= _amount;
    }

    /// @notice Checks if a user has allocated the specified amount
    /// @param _voter The address of the user
    /// @param _amount The amount of points to check
    function hasAllocatedPoints(address _voter, uint256 _amount, bytes memory) external view returns (bool) {
        return allocatedPoints[_voter] >= _amount;
    }
}
