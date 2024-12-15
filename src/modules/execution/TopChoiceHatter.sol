// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {ModuleType} from "../../core/ModuleType.sol";
import {IExecution} from "../../interfaces/IExecution.sol";
import {Contest} from "../../Contest.sol";
import {ChoiceCollector} from "../choices/utils/ChoiceCollector.sol";
import {BasicChoice} from "../../core/Choice.sol";
import {IVotes} from "../../interfaces/IVotes.sol";
import {IHats} from "lib/hats-protocol/src/Interfaces/IHats.sol";

struct ChoiceWithVotes {
    bytes32 choiceId;
    uint256 voteCount;
    BasicChoice choice;
}

abstract contract TopChoicePicker {
    /// @notice The name and version of the module
    uint256 public winnerAmt;

    /// @notice Reference to Choice Collector
    ChoiceCollector public choiceCollection;

    /// @notice Reference to Contest
    Contest public contest;

    /// @notice Reference to Votes
    IVotes public votesModule;

    /// @notice Internal function to get active choice count
    function _getActiveChoiceCount() internal view returns (uint256) {
        uint256 totalChoices = choiceCollection.choiceCount();

        uint256 activeCount = 0;
        for (uint256 i = 0; i < totalChoices; i++) {
            bytes32 choiceId = choiceCollection.choiceIds(i);
            BasicChoice memory choice = choiceCollection.getChoice(choiceId);

            if (choice.exists) {
                activeCount++;
            }
        }

        return activeCount;
    }

    /// @notice Internal function to derive top choices from the contest based on module data
    function _getTopChoices() internal view returns (BasicChoice[] memory) {
        // Get active choice count
        uint256 activeChoiceCount = _getActiveChoiceCount();

        // Check if there are enough active choices
        require(activeChoiceCount >= winnerAmt, "Not enough active choices");

        // Create array of exactly the right size for active choices
        ChoiceWithVotes[] memory choicesWithVotes = new ChoiceWithVotes[](activeChoiceCount);
        uint256 activeIndex = 0;

        // Populate array only with active choices
        for (uint256 i = 0; i < choiceCollection.choiceCount(); i++) {
            bytes32 choiceId = choiceCollection.choiceIds(i);
            BasicChoice memory choice = choiceCollection.getChoice(choiceId);

            if (choice.exists) {
                choicesWithVotes[activeIndex] = ChoiceWithVotes({
                    choiceId: choiceId,
                    voteCount: votesModule.getTotalVotesForChoice(choiceId),
                    choice: choice
                });
                activeIndex++;
            }
        }

        // Sort choices by vote count (using bubble sort as amount of choices are generally expected to range from 5-30)
        for (uint256 i = 0; i < activeChoiceCount - 1; i++) {
            for (uint256 j = 0; j < activeChoiceCount - i - 1; j++) {
                if (choicesWithVotes[j].voteCount < choicesWithVotes[j + 1].voteCount) {
                    ChoiceWithVotes memory temp = choicesWithVotes[j];
                    choicesWithVotes[j] = choicesWithVotes[j + 1];
                    choicesWithVotes[j + 1] = temp;
                }
            }
        }

        // Create array for top choices
        BasicChoice[] memory topChoices = new BasicChoice[](winnerAmt);

        // Fill top choices array with BasicChoice objects
        for (uint256 i = 0; i < winnerAmt; i++) {
            topChoices[i] = choicesWithVotes[i].choice;
        }

        return topChoices;
    }
}

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
