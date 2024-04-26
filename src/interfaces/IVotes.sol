// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IVotes {
    function vote(bytes32 choiceId, uint256 amount) external;

    function retractVote(bytes32 choiceId, uint256 amount) external;

    function getTotalVotesForChoice(
        bytes32 choiceId
    ) external view returns (uint256);
}
