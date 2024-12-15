// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {ModuleType} from "../../core/ModuleType.sol";
import {IExecution} from "../../interfaces/IExecution.sol";
import {Contest} from "../../Contest.sol";
import {ChoiceCollector} from "../choices/utils/ChoiceCollector.sol";
import {BasicChoice} from "../../core/Choice.sol";
import {IVotes} from "../../interfaces/IVotes.sol";
import {TopChoicePicker} from "./utils/TopChoicePicker.sol";
import {IHats} from "lib/hats-protocol/src/Interfaces/IHats.sol";

contract TopChoiceHatter is TopChoicePicker, IExecution, Initializable {
    /// ===============================
    /// ========== Events =============
    /// ===============================

    /// @notice Emitted when the contract is initialized
    event Initialized(address contest, uint256 winnerAmt, uint256 winnerHatId, uint256 adminHatId);

    event Executed();

    event Hatted(address wearer, uint256 hatId);

    /// ===============================
    /// ========== Storage ============
    /// ===============================

    /// @notice The name and version of the module
    string public constant MODULE_NAME = "TopChoiceHatter_v0.2.0";

    /// @notice The type of module
    ModuleType public constant MODULE_TYPE = ModuleType.Execution;

    /// @notice The hat Id that winners will receive on execution
    uint256 public winnerHatId;

    /// @notice The admin hat id
    uint256 public adminHatId;

    /// @notice Reference to Hats Protocol
    IHats hats;

    /// @notice Whether the module has been executed
    bool public executed;

    function initialize(address _contest, bytes memory _data) public initializer {
        (uint256 _winnerHatId, uint256 _adminHatId, uint256 _winnerAmt, address _hats) =
            abi.decode(_data, (uint256, uint256, uint256, address));

        hats = IHats(_hats);
        winnerAmt = _winnerAmt;
        contest = Contest(_contest);
        winnerHatId = _winnerHatId;
        adminHatId = _adminHatId;

        emit Initialized(_contest, _winnerAmt, _winnerHatId, _adminHatId);
    }

    /// ===============================
    /// ========== Setters ============
    /// ===============================

    /// @notice Executes the module
    function execute(bytes memory) external {
        require(!executed, "Already executed");

        _linkModules();

        require(
            hats.isWearerOfHat(address(msg.sender), adminHatId)
                && hats.isInGoodStanding(address(msg.sender), adminHatId),
            "This contract must be a wearer"
        );

        require(
            hats.isWearerOfHat(address(this), adminHatId) && hats.isInGoodStanding(address(this), adminHatId),
            "This contract must be a wearer"
        );

        require(
            address(choiceCollection) != address(0) || address(votesModule) != address(0), "Modules not initialized"
        );

        BasicChoice[] memory _topChoices = _getTopChoices();

        for (uint256 i = 0; i < _topChoices.length; i++) {
            hats.mintHat(winnerHatId, _topChoices[i].registrar);
            emit Hatted(_topChoices[i].registrar, winnerHatId);
        }

        executed = true;

        emit Executed();
    }

    function _linkModules() private {
        require(address(contest) != address(0) || address(votesModule) != address(0), "incorrect initialization");
        votesModule = IVotes(contest.votesModule());
        choiceCollection = ChoiceCollector(address(contest.choicesModule()));
    }
}
