// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import "lib/Baal/contracts/interfaces/IBaal.sol";
import "lib/Baal/contracts/interfaces/IBaalToken.sol";
import "../../interfaces/IChoices.sol";

import {Metadata} from "../../core/Metadata.sol";
import {ContestStatus} from "../../core/ContestStatus.sol";
import {ModuleType} from "../../core/ModuleType.sol";
import {Contest} from "../../Contest.sol";

/// @notice Struct to hold the metadata and bytes data of a choice
struct ChoiceData {
    Metadata metadata;
    bytes data;
    bool exists;
}

enum HolderType {
    None,
    Share,
    Loot,
    Both
}

contract BaalAllowList is IChoices, Initializable {
    /// ===============================
    /// ========== Events =============
    /// ===============================

    // /// @notice Emitted when the contract is initialized
    // event Initialized(address contest, address hatsAddress, uint256 hatId);

    // /// @notice Emitted when a choice is registered
    // event Registered(bytes32 choiceId, ChoiceData choiceData, address contest);

    // /// @notice Emitted when a choice is removed
    // event Removed(bytes32 choiceId, address contest);

    /// ===============================
    /// ========== Storage ============
    /// ===============================

    /// @notice The name and version of the module
    string public constant MODULE_NAME = "BaalAllowList_v0.0.1";

    /// @notice The type of module
    ModuleType public constant MODULE_TYPE = ModuleType.Choices;

    /// @notice Reference to the DAO contract
    IBaal public dao;

    /// @notice Reference to the DAO loot token contract
    IBaalToken public lootToken;

    /// @notice Reference to the DAO shares token contract
    IBaalToken public sharesToken;

    /// @notice Reference to the Contest contract
    Contest public contest;

    /// @notice Type of holder allowed to manage choices
    HolderType public holderType;

    /// @notice The threshold of the holder
    uint256 holderThreshold;

    /// @notice start time of the population period
    uint256 public startTime;

    /// @notice end time of the population period
    uint256 public endTime;

    /// @notice This maps the data for each choice to its choiceId
    /// @dev choiceId => ChoiceData
    mapping(bytes32 => ChoiceData) public choices;

    /// @notice Ensures the contest is in the populating state
    /// @dev The contest must be in the populating state
    modifier onlyContestPopulating() {
        require(contest.isStatus(ContestStatus.Populating), "Contest is not in populating state");
        _;
    }

    modifier onlyValidTime() {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Not during population period");
        _;
    }

    modifier onlyHolder() {
        if (holderType == HolderType.None) {
            _;
        } else if (holderType == HolderType.Share) {
            require(sharesToken.balanceOf(msg.sender) >= holderThreshold, "Insufficient share balance");
            _;
        } else if (holderType == HolderType.Loot) {
            require(lootToken.balanceOf(msg.sender) >= holderThreshold, "Insufficient loot balance");
            _;
        } else if (holderType == HolderType.Both) {
            require(
                sharesToken.balanceOf(msg.sender) >= holderThreshold
                    || lootToken.balanceOf(msg.sender) >= holderThreshold,
                "Insufficient balance"
            );
            _;
        }
    }

    /// ===============================
    /// ========== Init ===============
    /// ===============================

    constructor() {}

    /// @notice Initializes the contract with the contest, hats, and hatId
    /// @param _contest The address of the Contest contract
    /// @param _initData The initialization data for the contract
    /// @dev Bytes data includes the hats address, hatId, and prepopulated choices
    function initialize(address _contest, bytes calldata _initData) external override initializer {
        (address _daoAddress, uint256 _startTime, uint256 _duration, HolderType _holderType, uint256 _holderThreshold) =
            abi.decode(_initData, (address, uint256, uint256, HolderType, uint256));

        contest = Contest(_contest);

        require(_daoAddress != address(0), "Invalid DAO address");

        dao = IBaal(_daoAddress);

        lootToken = IBaalToken(dao.lootToken());

        sharesToken = IBaalToken(dao.sharesToken());

        holderType = _holderType;

        if (_startTime == 0) {
            startTime = block.timestamp;
        } else {
            require(_startTime > block.timestamp, "Start time must be in the future");

            startTime = _startTime;
        }

        endTime = startTime + _duration;
    }

    function registerChoice(bytes32 choiceId, bytes memory data)
        external
        onlyValidTime
        onlyContestPopulating
        onlyHolder
    {}

    function removeChoice(bytes32 choiceId, bytes memory data)
        external
        onlyValidTime
        onlyContestPopulating
        onlyHolder
    {}

    function isValidChoice(bytes32 choiceId) public view returns (bool) {
        return true;
    }

    function finalizeVoting() public onlyDuringPopulation {}
}
