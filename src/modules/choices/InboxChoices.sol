// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IHats} from "hats-protocol/Interfaces/IHats.sol";
import {IChoices} from "../../interfaces/IChoices.sol";
import {Initializable} from "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {Contest} from "../../Contest.sol";
import {ContestStatus} from "../../core/ContestStatus.sol";
import {BasicChoice} from "../../core/Choice.sol";
import {ModuleType} from "../../core/ModuleType.sol";
import {Metadata} from "../../core/Metadata.sol";
import {ChoiceCollector} from "./utils/ChoiceCollector.sol";

contract InboxChoices is ChoiceCollector, IChoices, Initializable {
    /// ===============================
    /// ========== Events =============
    /// ===============================

    /// @notice Emitted when the contract is initialized
    event Initialized(address contest, address hatsAddress, uint256 adminHatId);

    /// @notice Emitted when a choice is registered
    event Registered(bytes32 choiceId, BasicChoice choiceData, address contest);

    /// @notice Emitted when a choice is removed
    event Removed(bytes32 choiceId, address contest);

    /// @notice The name and version of the module
    string public constant MODULE_NAME = "InboxChoices_v0.1.0";

    /// @notice The type of module
    ModuleType public constant MODULE_TYPE = ModuleType.Choices;

    /// @notice The admin hat id
    uint256 public adminHatId;

    /// @notice Reference to the Contest contract
    Contest public contest;

    /// @notice Reference to the Hats Protocol contract
    IHats public hats;

    /// ===============================
    /// ========== Modifiers ==========
    /// ===============================

    /// @notice Ensures the caller is the wearer of the admin hat and in good standing
    modifier onlyAdmin() {
        require(
            hats.isWearerOfHat(msg.sender, adminHatId) && hats.isInGoodStanding(msg.sender, adminHatId),
            "Caller is not wearer or in good standing"
        );
        _;
    }

    /// @notice Ensures the contest is in the populating state
    modifier onlyContestPopulating() {
        require(contest.isStatus(ContestStatus.Populating), "Contest is not in populating state");
        _;
    }

    constructor() {}

    /// ===============================
    /// ========== Init ===============
    /// ===============================

    /// @notice Initializes the choices module
    /// @param _contest The contest that this module belongs to
    /// @param _initData The data for the module
    /// @dev Bytes data includes the hats address, admin hat id
    function initialize(address _contest, bytes calldata _initData) public initializer {
        (address _hatsAddress, uint256 _adminHatId) = abi.decode(_initData, (address, uint256));

        hats = IHats(_hatsAddress);
        contest = Contest(_contest);
        adminHatId = _adminHatId;

        emit Initialized(_contest, _hatsAddress, _adminHatId);
    }

    /// ===============================
    /// ========== Setters ============
    /// ===============================

    /// @notice Registers a choice with the contract
    /// @param _choiceId The unique identifier for the choice
    /// @param _data The data for the choice
    /// @dev Bytes data includes the metadata and choice data
    function registerChoice(bytes32 _choiceId, bytes memory _data) external onlyContestPopulating {
        (Metadata memory _metadata, bytes memory _bytes) = abi.decode(_data, (Metadata, bytes));

        _registerChoice(_choiceId, BasicChoice(_metadata, _bytes, true, msg.sender));

        emit Registered(_choiceId, choices[_choiceId], address(contest));
    }

    /// @notice Removes a choice from the contract
    /// @param _choiceId The unique identifier for the choice
    function removeChoice(bytes32 _choiceId, bytes calldata) external onlyAdmin onlyContestPopulating {
        _removeChoice(_choiceId);

        emit Removed(_choiceId, address(contest));
    }

    /// @notice Finalizes the choices for the contest
    function finalizeChoices() external onlyContestPopulating onlyAdmin {
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
