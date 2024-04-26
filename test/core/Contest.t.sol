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
        // _votes = new BaseVotes();
        // _admins[0] = admin1();
        // Deploy modules
        // Todo Refactor modules to be initialized after deployment with a factory
        // _admins[0] = admin1();
        // _admins[1] = admin2();
        // _allowList = new AllowList(_admins);
        // Contest contest = new Contest(
        // );
    }

    // function test_Increment() public {}

    function test() public {}
}
