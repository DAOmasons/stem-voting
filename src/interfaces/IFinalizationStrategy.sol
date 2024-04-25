// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFinalizationStrategy {
    function finalize(address contestAddress, bytes32[] calldata choices) external returns (bytes32[] memory winningChoices);

}