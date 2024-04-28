// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {HatsAllowList} from "../../../src/modules/choices/HatsAllowList.sol";
import {HatsSetup} from "../../setup/hatsSetup.sol";

contract HatsAllowListTest is HatsSetup, Test {
    HatsAllowList hatsAllowList;

    function setUp() public {
        hatsAllowList = new HatsAllowList();
        __setupHats();
    }

    function test() public {}
}
