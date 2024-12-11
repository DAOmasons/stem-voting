// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {IPoints} from "../../interfaces/IPoints.sol";
import {ModuleType} from "../../core/ModuleType.sol";
import {IHats} from "hats-protocol/Interfaces/IHats.sol";
import {ConditionalAllocator} from "./utils/ConditionalAllocator.sol";
import {IHatsPoints} from "../../interfaces/IHatsPoints.sol";

contract HatsPoints is ConditionalAllocator, IPoints, IHatsPoints, Initializable {
    /// ===============================
    /// ========== Events =============
    /// ===============================

    event Initialized(
        address contest, uint256[] hatIds, uint256[] hatPoints, uint256 adminHatId, address hats, bool shouldAccumulate
    );

    /// ===============================
    /// ========== Storage ============
    /// ===============================

    /// @notice The name and version of the module
    string public constant MODULE_NAME = "HatsPoints_v0.2.0";

    /// @notice The type of module
    ModuleType public constant MODULE_TYPE = ModuleType.Points;

    /// @notice mapping of hat id to points allocated
    mapping(uint256 => uint256) public hatPoints;

    /// @notice Reference to the contest contract
    address public contest;

    /// @notice Reference to the Hats Protocol contract
    IHats public hats;

    /// @notice The admin hat id
    uint256 public adminHatId;

    /// @notice Only the contest contract can call this function
    /// @dev The caller must be the contest contract
    modifier onlyContest() {
        require(msg.sender == contest, "Only contest");
        _;
    }

    /// @notice Only the wearer of the admin hat can call this function
    /// @dev The caller must be the wearer of the admin hat
    modifier onlyAdmin() {
        require(
            hats.isWearerOfHat(msg.sender, adminHatId) && hats.isInGoodStanding(msg.sender, adminHatId), "Only wearer"
        );
        _;
    }

    /// ===============================
    /// ========== Init ===============
    /// ===============================

    constructor() {}

    /// @notice Initializes the points module
    /// @param _contest The contest that this module belongs to
    /// @param _initData The data for the points module
    function initialize(address _contest, bytes calldata _initData) external initializer {
        (
            uint256[] memory _hatIds,
            uint256[] memory _hatPoints,
            uint256 _adminHatId,
            address _hats,
            bool _shouldAccumulate
        ) = abi.decode(_initData, (uint256[], uint256[], uint256, address, bool));

        require(_hats != address(0), "Zero address");

        require(_hatIds.length == _hatPoints.length, "hatIds and hatPoints must be the same length");
        for (uint256 i = 0; i < _hatIds.length; i++) {
            hatPoints[_hatIds[i]] = _hatPoints[i];
        }

        hats = IHats(_hats);
        adminHatId = _adminHatId;
        shouldAccumulate = _shouldAccumulate;
        contest = _contest;

        emit Initialized(_contest, _hatIds, _hatPoints, _adminHatId, _hats, _shouldAccumulate);
    }

    /// ===============================
    /// ========== Setters ============
    /// ===============================

    /// @notice Claims points from the user
    /// @dev This contract does not require users to claim points. Will revert if called.
    function claimPoints(address, bytes memory) public pure {
        revert("This contract does not require users to claim points.");
    }

    /// @notice This function checks if the user has enough voting power and records the amount spent
    /// @param _voter who is allocating their funds
    /// @param _amount of token allocated
    function allocatePoints(address _voter, uint256 _amount, bytes memory) external onlyContest {
        _allocatePoints(_voter, _amount);
    }

    /// @notice This function checks if the user has enough allocated points and subtracts them from allocation
    /// @param _voter who is releasing their funds
    /// @param _amount of token released
    function releasePoints(address _voter, uint256 _amount, bytes memory) external onlyContest {
        _releasePoints(_voter, _amount);
    }

    /// ===============================
    /// ========== Getters ============
    /// ===============================

    /// @notice This function returns the voting power of the user
    /// @param _voter who is checking their voting power
    /// @param _amount of token to be allocated
    function hasVotingPoints(address _voter, uint256 _amount, bytes memory _data) external view returns (bool) {
        (uint256 _hatId) = abi.decode(_data, (uint256));

        require(isValidWearer(_voter, _hatId), "Caller is not wearer or in good standing");

        require(hatPoints[_hatId] > 0, "Invalid hat id");

        return hatPoints[_hatId] >= _amount + points[_voter];
    }

    /// @notice This function returns the allocated points of the user
    /// @param _voter who is checking their allocated points
    /// @param _amount of token to be allocated
    function hasAllocatedPoints(address _voter, uint256 _amount, bytes memory _data) external view returns (bool) {
        (uint256 _hatId) = abi.decode(_data, (uint256));

        require(isValidWearer(_voter, _hatId), "Caller is not wearer or in good standing");

        return hatPoints[_hatId] + points[_voter] >= _amount;
    }

    function isValidWearer(address _voter, uint256 _hatId) public view returns (bool) {
        return hats.isWearerOfHat(_voter, _hatId) && hats.isInGoodStanding(_voter, _hatId);
    }

    function getPointsByHat(uint256 _hatId) external view returns (uint256) {
        return hatPoints[_hatId];
    }
}
