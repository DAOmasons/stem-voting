// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BasicChoice} from "../../../core/Choice.sol";

abstract contract ChoiceCollector {
    ///@notice Mapping of choiceIds to BasicChoice
    mapping(bytes32 => BasicChoice) public choices;

    ///@notice Array of choiceIds
    bytes32[] public choiceIds;

    /// @notice Registers a choice with to the mapping and list
    /// @param _choiceId The unique identifier for the choice
    /// @param _choice The choice
    function _registerChoice(bytes32 _choiceId, BasicChoice memory _choice) internal {
        choices[_choiceId] = _choice;
        choiceIds.push(_choiceId);
    }

    /// @notice Removes a choice from the mapping and list
    /// @param _choiceId The unique identifier for the choice
    function _removeChoice(bytes32 _choiceId) internal {
        require(choices[_choiceId].exists, "Choice does not exist");

        bool found = false;
        uint256 index;

        // Find the index of the element to remove
        for (uint256 i = 0; i < choiceIds.length; i++) {
            if (choiceIds[i] == _choiceId) {
                index = i;
                found = true;
                break;
            }
        }

        require(found, "Choice not found");

        // Swap with the last element and pop
        if (index != choiceIds.length - 1) {
            choiceIds[index] = choiceIds[choiceIds.length - 1];
        }

        choiceIds.pop();
        delete choices[_choiceId];
    }
}
