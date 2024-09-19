// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {AskHausSetupLive} from "./../setup/AskHausSetup.t.sol";
import {HolderType} from "../../src/core/BaalUtils.sol";

contract AskHausSignalSessionsTest is Test, AskHausSetupLive {
    function setUp() public {
        vm.createSelectFork({blockNumber: START_BLOCK, urlOrAlias: "sepolia"});
        __setupAskHausSignalSession(HolderType.Both);
    }

    function test() public {}
}
