// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IContest {
    function getTotalVotesForChoice(bytes32 choiceId) external view returns (uint256);

    function getChoices() external view returns (bytes32[] memory);

    function isFinalized() external view returns (bool);

    function claimPoints() external;

    function vote(bytes32 choiceId, uint256 amount, bytes memory data) external;

    function retractVote(bytes32 choiceId, uint256 amount, bytes memory data) external;

    function finalize() external;
}
