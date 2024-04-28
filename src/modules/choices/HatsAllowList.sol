// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../../interfaces/IChoices.sol";

import {IHats} from "hats-protocol/Interfaces/IHats.sol"; // Path: node_modules/@hats-finance/hats-protocol/contracts/Hats.sol

contract HatsAllowList is IChoices {
    IHats public hats;
    uint256 public facilitatorHatId;

    modifier onlyTrustedFacilitator() {
        require(
            hats.isWearerOfHat(msg.sender, facilitatorHatId) && hats.isInGoodStanding(msg.sender, facilitatorHatId),
            "Caller is not facilitator or in good standing"
        );
        _;
    }

    constructor() {
        // do nothing
    }

    function initialize(address contest, bytes calldata _initData) external override {
        // do nothing
    }

    function registerChoice(bytes32 choiceId, bytes calldata _data) external onlyTrustedFacilitator {
        // do nothing
    }

    function removeChoice(bytes32 choiceId, bytes calldata _data) external onlyTrustedFacilitator {
        // do nothing
    }
}
