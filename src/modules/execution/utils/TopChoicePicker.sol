// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BasicChoice} from "../../../core/Choice.sol";
import {ChoiceCollector} from "../../choices/utils/ChoiceCollector.sol";
import {Contest} from "../../../Contest.sol";
import {IVotes} from "../../../interfaces/IVotes.sol";

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
