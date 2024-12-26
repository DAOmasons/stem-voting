// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console} from "forge-std/Test.sol";
import {GGSetup} from "../setup/GGSetup.t.sol";

contract GGElections is GGSetup {
    function setUp() public {
        __deployGGElections();
    }

    function test() public {}
}
