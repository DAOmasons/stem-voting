// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BasicChoice} from "../../../core/Choice.sol";

abstract contract ChoiceCollector {
    ///@notice Mapping of choiceIds to BasicChoice
    mapping(bytes32 => BasicChoice) public choices;

    ///@notice Array of choiceIds
    bytes32[] public choiceIds;

    ///@notice The number of choices
    uint256 public choiceCount;

    /// @notice Registers a choice with to the mapping and list
    /// @param _choiceId The unique identifier for the choice
    /// @param _choice The choice
    function _registerChoice(bytes32 _choiceId, BasicChoice memory _choice) internal {
        choices[_choiceId] = _choice;
        choiceIds.push(_choiceId);
        choiceCount++;
    }

    /// @notice Removes a choice from the mapping and list
    /// @param _choiceId The unique identifier for the choice
    function _removeChoice(bytes32 _choiceId) internal {
        require(choices[_choiceId].exists, "Choice does not exist");

        BasicChoice storage choice = choices[_choiceId];

        choice.exists = false;
    }

    function getChoice(bytes32 _choiceId) public view returns (BasicChoice memory) {
        return choices[_choiceId];
    }
}
