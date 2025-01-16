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

contract OpenChoices is ChoiceCollector, IChoices, Initializable {
    /// ===============================
    /// ========== Events =============
    /// ===============================

    /// @notice Emitted when the contract is initialized
    event Initialized(address contest, address hatsAddress, uint256 adminHatId, bool canNominate);

    /// @notice Emitted when a choice is registered
    event Registered(bytes32 choiceId, BasicChoice choiceData, address contest);

    /// @notice Emitted when a choice is removed
    event Removed(bytes32 choiceId, address contest);

    /// @notice The name and version of the module
    string public constant MODULE_NAME = "OpenChoices_v0.1.0";

    /// @notice The type of module
    ModuleType public constant MODULE_TYPE = ModuleType.Choices;

    /// @notice The admin hat id
    uint256 public adminHatId;

    /// @notice Reference to the Contest contract
    Contest public contest;

    /// @notice Reference to the Hats Protocol contract
    IHats public hats;

    /// @notice Whether or not choices must be unique
    bool public canNominate;

    /// @notice Whether or not submissions are locked
    bool public lockSubmissions;

    /// ===============================
    /// ========== Modifiers ==========
    /// ===============================

    /// @notice Ensures the caller is the wearer of the admin hat and in good standing
    modifier onlyAdmin() virtual {
        require(
            hats.isWearerOfHat(msg.sender, adminHatId) && hats.isInGoodStanding(msg.sender, adminHatId),
            "Caller is not wearer or in good standing"
        );
        _;
    }

    /// @notice Ensures the contest is in the populating state
    modifier onlyContestPopulating() virtual {
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
    function initialize(address _contest, bytes calldata _initData) public virtual initializer {
        (address _hatsAddress, uint256 _adminHatId, bool _canNominate) = abi.decode(_initData, (address, uint256, bool));

        hats = IHats(_hatsAddress);
        contest = Contest(_contest);
        adminHatId = _adminHatId;
        canNominate = _canNominate;

        emit Initialized(_contest, _hatsAddress, _adminHatId, _canNominate);
    }

    /// ===============================
    /// ========== Setters ============
    /// ===============================

    /// @notice Registers a choice with the contract
    /// @param _choiceId The unique identifier for the choice
    /// @param _data The data struct for the Basic Choice struct
    /// @dev Bytes data includes the metadata and choice data
    function registerChoice(bytes32 _choiceId, bytes memory _data) external virtual onlyContestPopulating {
        registerChoiceGuard(_choiceId, _data);

        // Ensure the choice registration is not locked
        require(!lockSubmissions, "Locked");

        (bytes memory _choiceData, Metadata memory _metadata, address _registrar) =
            abi.decode(_data, (bytes, Metadata, address));

        // Ensure the proposed registrar is not zero
        require(_registrar != address(0), "Registrar must not be zero");

        // Check to see if there is an existing choice registered
        if (choices[_choiceId].registrar != address(0)) {
            // if so, ensure that the editor can only be edited by the registrar
            require(msg.sender == choices[_choiceId].registrar, "Only registrar can edit");
        }

        // Check to see if addresses can be nominated by another user
        if (!canNominate) {
            // if not, ensure that the editor can only be edited by the registrar
            require(_registrar == msg.sender, "Cannot nominate others");
        }

        BasicChoice memory _choice = BasicChoice(_metadata, _choiceData, true, _registrar);

        _registerChoice(_choiceId, _choice);

        emit Registered(_choiceId, _choice, address(contest));
    }

    /// @notice Removes a choice from the contract
    /// @param _choiceId The unique identifier for the choice
    function removeChoice(bytes32 _choiceId, bytes calldata _data) external onlyAdmin {
        removeChoiceGuard(_choiceId, _data);
        _removeChoice(_choiceId);

        emit Removed(_choiceId, address(contest));
    }

    /// @notice Finalizes the choices for the contest
    function finalizeChoices() external onlyContestPopulating onlyAdmin {
        contest.finalizeChoices();
    }

    /// @notice Locks submissions; used in the case of a spam or repeat submission
    function lock() external onlyAdmin {
        lockSubmissions = lockSubmissions ? false : true;
    }

    /// ===============================
    /// ========== Getters ============
    /// ===============================

    /// @notice Checks if a choice is valid
    /// @param _choiceId The unique identifier for the choice
    function isValidChoice(bytes32 _choiceId) public view returns (bool) {
        return choices[_choiceId].exists;
    }

    /// ===============================
    /// ========== Guards =============
    /// ===============================

    function registerChoiceGuard(bytes32, bytes memory) internal virtual {}
    function removeChoiceGuard(bytes32, bytes memory) internal virtual {}
}
