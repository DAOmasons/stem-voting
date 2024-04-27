// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// Libs
import "forge-std/Test.sol";

// Setup
import {Accounts} from "../setup/Accounts.t.sol";

// Core
import {Contest} from "../../src/Contest.sol";

// Modules
import {AllowList} from "../../src/modules/choices/AllowList.sol";
import {ERC20Balance} from "../../src/modules/points/ERC20Balance.sol";
import {BaseVotes} from "../../src/modules/votes/BaseVotes.sol";
import {Counter} from "../../src/Counter.sol";

contract ContestTest is Test, Accounts {
    Contest public _contest;

    // MODULES
    AllowList internal _allowList;
    ERC20Balance internal _erc20Balance;
    BaseVotes internal _votes;
    Counter public counter;
    // USERS
    address[] internal _admins;

    function setUp() public {
        // Set up stuff here
    }

    function test() public {}
}
