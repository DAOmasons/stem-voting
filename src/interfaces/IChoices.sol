// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Metadata} from "../core/Metadata.sol";

interface IChoices {
    // Note: Edited to remove uri as we can incorporate that into data param

    function registerChoice(bytes32 choiceId, bytes memory data) external;

    function removeChoice(bytes32 choiceId, bytes memory data) external;

    function initialize(address _contest, bytes calldata initData) external;
    // Note: Thinking that we should allow the module author to decide how to return the data
    // as the structure of it may differ between modules
    // function getChoice(bytes32 choiceId) external view returns (string memory uri, bytes memory data);
}
