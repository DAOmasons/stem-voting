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

abstract contract ChoiceCollector {
    mapping(bytes32 => BasicChoice) public choices;

    bytes32[] public choiceIds;

    function _registerChoice(bytes32 _choiceId, BasicChoice memory _choice) internal {
        choices[_choiceId] = _choice;
        choiceIds.push(_choiceId);
    }

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

contract InboxChoices is ChoiceCollector, IChoices, Initializable {
    /// @notice The name and version of the module
    string public constant MODULE_NAME = "InboxChoices_v0.1.1";

    /// @notice The type of module
    ModuleType public constant MODULE_TYPE = ModuleType.Choices;

    uint256 public adminHatId;

    /// @notice Reference to the Contest contract
    Contest public contest;

    /// @notice Reference to the Hats Protocol contract
    IHats public hats;

    modifier onlyAdmin() {
        require(
            hats.isWearerOfHat(msg.sender, adminHatId) && hats.isInGoodStanding(msg.sender, adminHatId),
            "Caller is not wearer or in good standing"
        );
        _;
    }

    constructor() {}

    modifier onlyContestPopulating() {
        require(contest.isStatus(ContestStatus.Populating), "Contest is not in populating state");
        _;
    }

    function initialize(address _contest, bytes calldata _initData) public initializer {
        (address _hatsAddress, uint256 _adminHatId) = abi.decode(_initData, (address, uint256));

        hats = IHats(_hatsAddress);
        contest = Contest(_contest);
        adminHatId = _adminHatId;
    }

    function registerChoice(bytes32 _choiceId, bytes memory _data) external {
        (Metadata memory _metadata) = abi.decode(_data, (Metadata));

        _registerChoice(_choiceId, BasicChoice(_metadata, "", true, msg.sender));
    }

    function removeChoice(bytes32 _choiceId, bytes calldata) external onlyAdmin {
        _removeChoice(_choiceId);
    }

    function finalizeChoices() external onlyContestPopulating {
        contest.finalizeChoices();
    }

    /// @notice Checks if a choice is valid
    /// @param _choiceId The unique identifier for the choice
    function isValidChoice(bytes32 _choiceId) public view returns (bool) {
        return choices[_choiceId].exists;
    }
}
