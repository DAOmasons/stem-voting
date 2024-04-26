// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../interfaces/IFinalizationStrategy.sol";

import "../Contest.sol";

contract TopChoiceStrategy is IFinalizationStrategy {
    function finalize(
        address contestAddress,
        bytes32[] calldata choices
    ) external view override returns (bytes32[] memory winningChoices) {
        Contest contest = Contest(contestAddress);
        uint256 highestVotes = 0;
        winningChoices = new bytes32[](choices.length);

        for (uint i = 0; i < choices.length; i++) {
            uint256 votes = contest.getTotalVotesForChoice(choices[i]);
            if (votes > highestVotes) {
                highestVotes = votes;
                winningChoices[i] = choices[i];
            }
        }
        return winningChoices;
    }
}
