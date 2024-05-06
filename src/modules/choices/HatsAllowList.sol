// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../../interfaces/IChoices.sol";

import {IHats} from "hats-protocol/Interfaces/IHats.sol"; // Path: node_modules/@hats-finance/hats-protocol/contracts/Hats.sol
import {Contest} from "../../Contest.sol";
import {ContestStatus} from "../../core/ContestStatus.sol";

// Todo
// - [] Wrap that check in a modifier and apply to write functions except initialize

// Not continuous enabled
contract HatsAllowList is IChoices {
    /// ===============================
    /// ========== Events =============
    /// ===============================

    event Initialized(address contest, address hatsAddress, uint256 hatId);

    event Registered(bytes32 choiceId, ChoiceData choiceData);

    event Removed(bytes32 choiceId);

    /// ===============================
    /// ========== Struct =============
    /// ===============================

    struct ChoiceData {
        Metadata metadata;
        bytes data;
        bool exists;
    }

    /// ===============================
    /// ========== Storage ============
    /// ===============================

    IHats public hats;

    uint256 public hatId;

    Contest public contest;

    // choiceId => ChoiceData
    mapping(bytes32 => ChoiceData) public choices;

    /// ===============================
    /// ========== Modifiers ==========
    /// ===============================

    modifier onlyTrustedWearer() {
        require(
            hats.isWearerOfHat(msg.sender, hatId) && hats.isInGoodStanding(msg.sender, hatId),
            "Caller is not wearer or in good standing"
        );
        _;
    }

    modifier onlyContestPopulating() {
        require(contest.isStatus(ContestStatus.Populating), "Contest is not in populating state");
        _;
    }

    /// ===============================
    /// ========== Init ===============
    /// ===============================

    constructor() {}

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

    function registerChoice(bytes32 choiceId, bytes memory _data) external onlyTrustedWearer onlyContestPopulating {
        _registerChoice(choiceId, _data);
    }

    function _registerChoice(bytes32 choiceId, bytes memory _data) private {
        (bytes memory _choiceData, Metadata memory _metadata) = abi.decode(_data, (bytes, Metadata));

        choices[choiceId] = ChoiceData(_metadata, _choiceData, true);

        emit Registered(choiceId, choices[choiceId]);
    }

    function removeChoice(bytes32 choiceId, bytes calldata) external onlyTrustedWearer onlyContestPopulating {
        require(isValidChoice(choiceId), "Choice does not exist");

        delete choices[choiceId];

        emit Removed(choiceId);
    }

    function finalizeChoices() external onlyTrustedWearer onlyContestPopulating {
        contest.finalizeChoices();
    }

    /// ===============================
    /// ========== Getters ============
    /// ===============================

    function isValidChoice(bytes32 choiceId) public view returns (bool) {
        return choices[choiceId].exists;
    }
}
