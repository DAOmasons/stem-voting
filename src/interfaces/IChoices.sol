// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IChoices {
    function registerChoice(
        bytes32 choiceId,
        string calldata uri,
        bytes calldata data
    ) external;

    function getChoice(
        bytes32 choiceId
    ) external view returns (string memory uri, bytes memory data);
}
