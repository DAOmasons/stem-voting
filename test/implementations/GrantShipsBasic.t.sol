// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {GrantShipsSetup} from "../setup/GrantShipsSetup.t.sol";

contract GrantShipsBasic is GrantShipsSetup {
    function setUp() public {
        __setupGrantShips();
    }

    function test() public {
        console.log("GrantShipsBasic.test");
    }
}
