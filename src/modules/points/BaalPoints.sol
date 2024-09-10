// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import "../../interfaces/IPoints.sol";

import {IBaalToken} from "lib/Baal/contracts/interfaces/IBaalToken.sol";
import {IBaal} from "lib/Baal/contracts/interfaces/IBaal.sol";
import {Contest} from "../../Contest.sol";
import {ModuleType} from "../../core/ModuleType.sol";
import {HolderType} from "../../core/BaalUtils.sol";

contract BaalPoints is IPoints, Initializable {
    event Initialized(
        address contest, address dao, address sharesToken, address lootToken, uint256 checkpoint, HolderType holderType
    );

    /// @notice The name and version of the module
    string public constant MODULE_NAME = "BaalPoints_v0.0.1";

    /// @notice The type of module
    ModuleType public constant MODULE_TYPE = ModuleType.Choices;

    address public dao;

    IBaalToken public sharesToken;
    IBaalToken public lootToken;
    Contest public contest;

    uint256 public checkpoint;

    HolderType public holderType;

    mapping(address => uint256) public allocatedPoints;

    constructor() {}

    function initialize(address _contest, bytes memory _initData) public initializer {
        (address _daoAddress, uint256 _checkpoint, HolderType _holderType) =
            abi.decode(_initData, (address, uint256, HolderType));

        require(_daoAddress != address(0), "Invalid DAO address");
        require(_holderType != HolderType.None, "Invalid holder type");

        IBaal _baal = IBaal(_daoAddress);
        dao = _daoAddress;
        holderType = _holderType;
        checkpoint = _checkpoint;

        sharesToken = IBaalToken(_baal.sharesToken());
        lootToken = IBaalToken(_baal.lootToken());
        contest = Contest(_contest);

        emit Initialized(_contest, _daoAddress, _baal.sharesToken(), _baal.lootToken(), _checkpoint, _holderType);
    }

    function getPoints(address voter) public view returns (uint256) {
        if (holderType == HolderType.Loot) {
            return lootToken.getPastVotes(voter, checkpoint);
        } else if (holderType == HolderType.Share) {
            return sharesToken.getPastVotes(voter, checkpoint);
        } else {
            return lootToken.getPastVotes(voter, checkpoint) + sharesToken.getPastVotes(voter, checkpoint);
        }
    }

    function allocatePoints(address _voter, uint256 _amount, bytes memory _data) public {
        require(_amount > 0, "Amount must be greater than 0");
        require(hasVotingPoints(_voter, _amount, _data), "Insufficient points available");
        allocatedPoints[_voter] += _amount;

        emit PointsAllocated(_voter, _amount);
    }

    function releasePoints(address _voter, uint256 _amount, bytes memory _data) public {
        require(_amount > 0, "Amount must be greater than 0");
        require(hasAllocatedPoints(_voter, _amount, _data), "Insufficient points allocated");
        allocatedPoints[_voter] -= _amount;

        emit PointsReleased(_voter, _amount);
    }

    function claimPoints(address, bytes memory) public pure {
        revert("This contract does not require users to claim points.");
    }

    function hasVotingPoints(address _voter, uint256 _amount, bytes memory) public view returns (bool) {
        return getPoints(_voter) + allocatedPoints[_voter] >= _amount;
    }

    function hasAllocatedPoints(address _voter, uint256 _amount, bytes memory) public view returns (bool) {
        return allocatedPoints[_voter] >= _amount;
    }
}
