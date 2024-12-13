// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoints} from "../../interfaces/IPoints.sol";
import {Initializable} from "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ModuleType} from "../../core/ModuleType.sol";

contract MerklePoints is IPoints, Initializable {
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
    }

    function claimPoints(address, bytes memory) external {}

    function allocatePoints(address _voter, uint256 _amount, bytes memory _data) external onlyContest {}

    function releasePoints(address _voter, uint256 _amount, bytes memory _data) external onlyContest {}

    ///@notice Verifies if a user has the claimed points using OpenZeppelin's MerkleProof
    ///@param _user The address of the user
    ///@param _points The number of points claimed
    ///@param _proof The Merkle proof as an array of bytes32
    function verifyPoints(address _user, uint256 _points, bytes32[] calldata _proof) public view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(_user, _points));
        return MerkleProof.verify(_proof, leaf, merkleRoot);
    }

    function hasVotingPoints(address _voter, uint256 _amount, bytes memory _data) external view returns (bool) {}

    function hasAllocatedPoints(address _voter, uint256 _amount, bytes memory _data) external view returns (bool) {}
}
