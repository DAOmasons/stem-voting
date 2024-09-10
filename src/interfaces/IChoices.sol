// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Metadata} from "../core/Metadata.sol";
import {IModule} from "./IModule.sol";

interface IChoices is IModule {
    // Note: Edited to remove uri as we can incorporate that into data param

    function registerChoice(bytes32 choiceId, bytes memory data) external;

    function removeChoice(bytes32 choiceId, bytes memory data) external;

    function isValidChoice(bytes32 choiceId) external view returns (bool);
}
