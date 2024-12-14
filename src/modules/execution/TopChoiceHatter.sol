// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {ModuleType} from "../../core/ModuleType.sol";
import {IExecution} from "../../interfaces/IExecution.sol";
import {Contest} from "../../Contest.sol";
import {ChoiceCollector} from "../choices/utils/ChoiceCollector.sol";

abstract contract TopChoicePicker {
    Contest public contest;
    ChoiceCollector public choiceCollection;
    uint256 public winnerAmt;

    function _initTopChoicePicker(address _contest, address _choiceCollection, uint256 _winnerAmt) internal {
        contest = Contest(_contest);
        choiceCollection = ChoiceCollector(_choiceCollection);
        winnerAmt = _winnerAmt;
    }

    function _getTopChoices() internal {
        require(address(choiceCollection) != address(0) && address(contest) != address(0), "Invalid Address");
    }
}

contract TopChoiceHatter is IExecution, Initializable {
    /// @notice The name and version of the module
    string public constant MODULE_NAME = "TopChoiceHatter_v0.2.0";

    /// @notice The type of module
    ModuleType public constant MODULE_TYPE = ModuleType.Points;

    function execute(bytes memory _data) external {}

    function initialize(address _contest, bytes memory _data) public initializer {}
}
