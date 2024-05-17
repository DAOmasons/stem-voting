// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../../interfaces/IChoices.sol";

import {IHats} from "hats-protocol/Interfaces/IHats.sol"; // Path: node_modules/@hats-finance/hats-protocol/contracts/Hats.sol
import {Contest} from "../../Contest.sol";
import {ContestStatus} from "../../core/ContestStatus.sol";

/// @title HatsAllowList
/// @author @jord<https://github.com/jordanlesich>
/// @notice Uses Hats to permission the selection of choices for a contest
contract HatsAllowList is IChoices {
    /// ===============================
    /// ========== Events =============
    /// ===============================

    /// @notice Emitted when the contract is initialized
    event Initialized(address contest, address hatsAddress, uint256 hatId);

    /// @notice Emitted when a choice is registered
    event Registered(bytes32 choiceId, ChoiceData choiceData);

    /// @notice Emitted when a choice is removed
    event Removed(bytes32 choiceId);

    /// ===============================
    /// ========== Struct =============
    /// ===============================

    /// @notice Struct to hold the metadata and bytes data of a choice
    struct ChoiceData {
        Metadata metadata;
        bytes data;
        bool exists;
    }

    /// ===============================
    /// ========== Storage ============
    /// ===============================

    /// @notice Reference to the Hats Protocol contract
    IHats public hats;

    /// @notice The hatId of the hat that is allowed to make choices
    uint256 public hatId;

    /// @notice Reference to the Contest contract
    Contest public contest;

    /// @notice This maps the data for each choice to its choiceId
    /// @dev choiceId => ChoiceData
    mapping(bytes32 => ChoiceData) public choices;

    /// ===============================
    /// ========== Modifiers ==========
    /// ===============================

    /// Review: It is likely that this check is redundant, as the caller must be in good standing to be a wearer, but need to test more

    /// @notice Ensures the caller is the wearer of the hat and in good standing
    /// @dev The caller must be the wearer of the hat and in good standing
    modifier onlyTrustedWearer() {
        require(
            hats.isWearerOfHat(msg.sender, hatId) && hats.isInGoodStanding(msg.sender, hatId),
            "Caller is not wearer or in good standing"
        );
        _;
    }

    /// @notice Ensures the contest is in the populating state
    /// @dev The contest must be in the populating state
    modifier onlyContestPopulating() {
        require(contest.isStatus(ContestStatus.Populating), "Contest is not in populating state");
        _;
    }

    /// ===============================
    /// ========== Init ===============
    /// ===============================

    constructor() {}

    /// @notice Initializes the contract with the contest, hats, and hatId
    /// @param _contest The address of the Contest contract
    /// @param _initData The initialization data for the contract
    /// @dev Bytes data includes the hats address, hatId, and prepopulated choices
    function initialize(address _contest, bytes calldata _initData) external override {
        (address _hats, uint256 _hatId, bytes[] memory _prepopulatedChoices) =
            abi.decode(_initData, (address, uint256, bytes[]));

        contest = Contest(_contest);

        hats = IHats(_hats);
        hatId = _hatId;

        if (_prepopulatedChoices.length > 0) {
            for (uint256 i = 0; i < _prepopulatedChoices.length;) {
                (bytes32 choiceId, bytes memory _data) = abi.decode(_prepopulatedChoices[i], (bytes32, bytes));
                _registerChoice(choiceId, _data);

                unchecked {
                    i++;
                }
            }
        }

        emit Initialized(_contest, _hats, _hatId);
    }

    /// ===============================
    /// ========== Setters ============
    /// ===============================

    /// @notice Registers a choice with the contract
    /// @param _choiceId The unique identifier for the choice
    /// @param _data The data for the choice
    /// @dev Bytes data includes the metadata and choice data
    function registerChoice(bytes32 _choiceId, bytes memory _data) external onlyTrustedWearer onlyContestPopulating {
        _registerChoice(_choiceId, _data);
    }

    /// @notice Internal function to register a choice
    /// @param _choiceId The unique identifier for the choice
    /// @param _data The data for the choice
    /// @dev Bytes data includes the metadata and choice data
    function _registerChoice(bytes32 _choiceId, bytes memory _data) private {
        (bytes memory _choiceData, Metadata memory _metadata) = abi.decode(_data, (bytes, Metadata));

        choices[_choiceId] = ChoiceData(_metadata, _choiceData, true);

        emit Registered(_choiceId, choices[_choiceId]);
    }

    /// @notice Removes a choice from the contract
    /// @param _choiceId The unique identifier for the choice
    function removeChoice(bytes32 _choiceId, bytes calldata) external onlyTrustedWearer onlyContestPopulating {
        require(isValidChoice(_choiceId), "Choice does not exist");

        delete choices[_choiceId];

        emit Removed(_choiceId);
    }

    /// @notice Finalizes the choices for the contest
    function finalizeChoices() external onlyTrustedWearer onlyContestPopulating {
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
