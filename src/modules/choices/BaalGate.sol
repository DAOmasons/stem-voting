// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import "lib/Baal/contracts/interfaces/IBaal.sol";
import "lib/Baal/contracts/interfaces/IBaalToken.sol";
import "../../interfaces/IChoices.sol";

import {console} from "forge-std/Test.sol";

import {Metadata} from "../../core/Metadata.sol";
import {ContestStatus} from "../../core/ContestStatus.sol";
import {ModuleType} from "../../core/ModuleType.sol";
import {Contest} from "../../Contest.sol";
import {HolderType} from "../../core/BaalUtils.sol";
import {BasicChoice} from "../../core/Choice.sol";

contract BaalGateV0 is IChoices, Initializable {
    /// ===============================
    /// ========== Events =============
    /// ===============================

    // @notice Emitted when the contract is initialized
    event Initialized(
        address contest,
        address daoAddress,
        address lootToken,
        address sharesToken,
        HolderType holderType,
        uint256 holderThreshold,
        bool timed,
        uint256 startTime,
        uint256 endTime
    );

    // @notice Emitted when a choice is registered
    event Registered(bytes32 choiceId, BasicChoice choiceData, address contest);

    // @notice Emitted when a choice is removed
    event Removed(bytes32 choiceId, address contest);

    /// ===============================
    /// ========== Storage ============
    /// ===============================

    /// @notice The name and version of the module
    string public constant MODULE_NAME = "BaalGate_v0.2.0";

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

    /// @notice is the population round timed
    bool public timed;

    /// @notice This maps the data for each choice to its choiceId
    /// @dev choiceId => BasicChoice
    mapping(bytes32 => BasicChoice) public choices;

    /// @notice Ensures the contest is in the populating state
    /// @dev The contest must be in the populating state
    modifier onlyContestPopulating() {
        require(contest.isStatus(ContestStatus.Populating), "Contest is not in populating state");
        _;
    }

    /// @notice Ensures the block timestamp is during the population period
    /// @dev The block timestamp must be during the population period
    modifier onlyValidTime() {
        require(!timed || block.timestamp >= startTime && block.timestamp <= endTime, "Not during population period");
        _;
    }

    /// @notice Ensures the holder is allowed to manage choices
    /// @dev The holder must be allowed to manage choices
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

        holderThreshold = _holderThreshold;

        if (_duration == 0 && _startTime == 0) {
            timed = false;
        } else if (_startTime == 0) {
            startTime = block.timestamp;
            timed = true;
        } else {
            require(_startTime > block.timestamp, "Start time must be in the future");
            startTime = _startTime;
            timed = true;
        }

        endTime = startTime + _duration;

        emit Initialized(
            _contest,
            _daoAddress,
            address(lootToken),
            address(sharesToken),
            holderType,
            holderThreshold,
            timed,
            startTime,
            endTime
        );
    }

    /// ===============================
    /// ========== Setters ============
    /// ===============================

    /// @notice Registers a choice with the contract
    /// @param _choiceId The unique identifier for the choice
    /// @param _data The data for the choice
    /// @dev Bytes data includes the metadata and choice data
    function registerChoice(bytes32 _choiceId, bytes memory _data)
        external
        onlyValidTime
        onlyContestPopulating
        onlyHolder
    {
        (bytes memory _choiceData, Metadata memory _metadata) = abi.decode(_data, (bytes, Metadata));

        choices[_choiceId] = BasicChoice(_metadata, _choiceData, true);

        emit Registered(_choiceId, choices[_choiceId], address(contest));
    }

    /// @notice Removes a choice from the contract
    /// @param _choiceId The unique identifier for the choice
    function removeChoice(bytes32 _choiceId, bytes memory) external onlyValidTime onlyContestPopulating onlyHolder {
        require(isValidChoice(_choiceId), "Choice does not exist");

        delete choices[_choiceId];

        emit Removed(_choiceId, address(contest));
    }

    /// @notice Finalizes the choices for the contest
    function finalizeChoices() external onlyContestPopulating {
        require(block.timestamp >= endTime, "Population period has not ended");
        contest.finalizeChoices();
    }

    /// ===============================
    /// ========== Getters ============
    /// ===============================

    /// @notice Checks if a choice is valid
    /// @param _choiceId The unique identifier for the choice
    function isValidChoice(bytes32 _choiceId) public view returns (bool) {
        return choices[_choiceId].exists;
    }
}
