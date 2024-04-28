// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IVotes {
    function initialize(address contest, bytes calldata initData) external;

    function vote(address voter, bytes32 choiceId, uint256 amount, bytes memory data) external;

    function retractVote(address voter, bytes32 choiceId, uint256 amount, bytes memory data) external;

    function getTotalVotesForChoice(bytes32 choiceId) external view returns (uint256);
}
