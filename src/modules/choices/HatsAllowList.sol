// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../../interfaces/IChoices.sol";

contract HatsAllowList is IChoices {
    constructor() {
        // do nothing
    }

    function initialize(address contest, bytes calldata _initData) external override {
        // do nothing
    }

    function registerChoice(bytes32 choiceId, bytes calldata _data) external {
        // do nothing
    }

    function removeChoice(bytes32 choiceId, bytes calldata _data) external {
        // do nothing
    }
}
