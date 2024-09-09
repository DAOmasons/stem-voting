// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IFinalizationStrategy {
    function execute(address contestAddress, bytes32[] calldata choices)
        external
        returns (bytes32[] memory winningChoices);
}
