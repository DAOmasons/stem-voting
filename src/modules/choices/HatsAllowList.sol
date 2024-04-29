// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../../interfaces/IChoices.sol";

import {IHats} from "hats-protocol/Interfaces/IHats.sol"; // Path: node_modules/@hats-finance/hats-protocol/contracts/Hats.sol
import {IContest} from "../../interfaces/IContest.sol";

contract HatsAllowList is IChoices {
    struct ChoiceData {
        Metadata metadata;
        bytes data;
        bool exists;
    }

    IHats public hats;
    uint256 public facilitatorHatId;

    IContest public contest;

    mapping(bytes32 => ChoiceData) public choices;

    modifier onlyTrustedFacilitator() {
        require(
            hats.isWearerOfHat(msg.sender, facilitatorHatId) && hats.isInGoodStanding(msg.sender, facilitatorHatId),
            "Caller is not facilitator or in good standing"
        );
        _;
    }

    constructor() {}

    function initialize(address _contest, bytes calldata _initData) external override {
        (address _hats, uint256 _facilitatorHatId, bytes[] memory _prepopulatedChoices) =
            abi.decode(_initData, (address, uint256, bytes[]));

        contest = IContest(_contest);

        hats = IHats(_hats);
        facilitatorHatId = _facilitatorHatId;

        if (_prepopulatedChoices.length > 0) {
            for (uint256 i = 0; i < _prepopulatedChoices.length;) {
                (bytes32 choiceId, bytes memory _data) = abi.decode(_prepopulatedChoices[i], (bytes32, bytes));
                registerChoice(choiceId, _data);

                unchecked {
                    i++;
                }
            }
        }
    }

    function registerChoice(bytes32 choiceId, bytes memory _data) public onlyTrustedFacilitator {
        (bytes memory _choiceData, Metadata memory _metadata) = abi.decode(_data, (bytes, Metadata));

        choices[choiceId] = ChoiceData(_metadata, _choiceData, true);
    }

    function removeChoice(bytes32 choiceId, bytes calldata) external onlyTrustedFacilitator {
        // Review Any consequences to deleting like this?

        require(isValidChoice(choiceId), "Choice does not exist");

        delete choices[choiceId];
    }

    function getChoice(bytes32 choiceId) external view returns (ChoiceData memory) {
        require(isValidChoice(choiceId), "Choice does not exist");

        return choices[choiceId];
    }

    function isValidChoice(bytes32 choiceId) public view returns (bool) {
        return choices[choiceId].exists;
    }
}
