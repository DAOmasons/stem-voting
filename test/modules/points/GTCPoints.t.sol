// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Accounts} from "../../setup/Accounts.t.sol";
import {GTCTokenPoints} from "../../../src/modules/points/GTCTokenPoints.sol";
import {GTCTokenSetup} from "../../setup/GTCSetup.t.sol";

contract GTCPointsTest is Test, Accounts, GTCTokenSetup {
    uint256 constant START_BLOCK = 285113002;

    function setUp() public {
        __setupGTCToken();
    }

    function test() public {
        vm.createSelectFork({blockNumber: START_BLOCK, urlOrAlias: "arbitrumOne"});
    }
}
