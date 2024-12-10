// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {IPoints} from "../../interfaces/IPoints.sol";
import {ModuleType} from "../../core/ModuleType.sol";
import {IHats} from "hats-protocol/Interfaces/IHats.sol";

contract HatsPoints is IPoints, Initializable {
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

    modifier onlyAdmin() {
        require(
            hats.isWearerOfHat(msg.sender, adminHatId) && hats.isInGoodStanding(msg.sender, adminHatId), "Only wearer"
        );
        _;
    }

    function initialize(address _contest, bytes calldata initData) external initializer {
        (uint256[] memory _hatIds, uint256[] memory _hatPoints, uint256 _adminHatId, address _hats) =
            abi.decode(initData, (uint256[], uint256[], uint256, address));

        require(_hats != address(0), "Zero address");

        hats = IHats(_hats);
        adminHatId = _adminHatId;

        for (uint256 i = 0; i < _hatIds.length; i++) {
            hatPoints[_hatIds[i]] = _hatPoints[i];
        }

        contest = _contest;
    }

    /// @notice Claims points from the user
    /// @dev This contract does not require users to claim points. Will revert if called.
    function claimPoints(address, bytes memory) public pure {
        revert("This contract does not require users to claim points.");
    }

    function allocatePoints(address voter, uint256 amount, bytes memory data) external {}

    function releasePoints(address voter, uint256 amount, bytes memory data) external {}

    function hasVotingPoints(address voter, uint256 amount, bytes memory data) external view returns (bool) {}

    function hasAllocatedPoints(address voter, uint256 amount, bytes memory data) external view returns (bool) {}
}
