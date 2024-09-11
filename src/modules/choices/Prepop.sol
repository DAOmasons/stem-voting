// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import "../../interfaces/IChoices.sol";
import {BasicChoice} from "../../core/Choice.sol";
import {ModuleType} from "../../core/ModuleType.sol";
import {Contest} from "../../Contest.sol";

contract Prepop is IChoices, Initializable {
    /// ===============================
    /// ========== Events =============
    /// ===============================
    /// @notice Emitted when the contract is initialized
    event Initialized(address contest);

    /// @notice Emitted when a choice is registered
    event Registered(bytes32 choiceId, BasicChoice choiceData, address contest);

    /// ===============================
    /// ========== Storage ============
    /// ===============================

    /// @notice The name and version of the module
    string public constant MODULE_NAME = "PrePop_v0.0.1";

    /// @notice The type of module
    ModuleType public constant MODULE_TYPE = ModuleType.Choices;

    /// @notice This maps the data for each choice to its choiceId
    /// @dev choiceId => BasicChoice
    mapping(bytes32 => BasicChoice) public choices;

    /// @notice The contest that this module belongs to
    Contest public contest;

    constructor() {}

    /// ===============================
    /// ========== Init ===============
    /// ===============================

    /// @notice Initializes the choices module
    /// @param _contest The contest that this module belongs to
    /// @param _initData The data for the choices
    function initialize(address _contest, bytes calldata _initData) external initializer {
        require(_contest != address(0), "Prepop requires a valid contest");
        (BasicChoice[] memory _choices, bytes32[] memory _choiceIds) = abi.decode(_initData, (BasicChoice[], bytes32[]));

        contest = Contest(_contest);

        require(_choices.length > 1, "Prepop requires at least 2 choices");
        require(_choiceIds.length == _choices.length, "Array lengths do not match");

        emit Initialized(_contest);

        for (uint256 i = 0; i < _choices.length; i++) {
            choices[_choiceIds[i]] = _choices[i];

            emit Registered(_choiceIds[i], _choices[i], _contest);
        }

        contest.finalizeChoices();
    }

    /// ===============================
    /// ========== Setters ============
    /// ===============================

    /// @notice Registers a choice with the contract. NOT USED in this contract.
    function registerChoice(bytes32, bytes memory) external pure {
        revert("Prepop does not implement registerChoice");
    }

    /// @notice Removes a choice from the contract. NOT USED in this contract.
    function removeChoice(bytes32, bytes memory) external pure {
        revert("Prepop does not implement removeChoice");
    }

    /// ===============================
    /// ========== Getters ============
    /// ===============================

    function isValidChoice(bytes32 _choiceId) external view returns (bool) {
        return choices[_choiceId].exists;
    }
}
