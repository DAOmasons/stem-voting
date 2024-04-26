// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Libs
import "forge-std/Test.sol";

// Core
import {Contest} from "../../src/Contest.sol";

// Modules

import {AllowList} from "../../src/modules/choices/AllowList.sol";
import {ERC20Balance} from "../../src/modules/points/ERC20Balance.sol";
import {BaseVotes} from "../../src/modules/votes/BaseVotes.sol";

contract ContestTest is Test {
    Contest internal _contest;

    // MODULES
    AllowList internal _allowList;
    ERC20Balance internal _erc20Balance;
    BaseVotes internal _votes;

    // USERS 
    address internal _admin1;
    address internal _admin2;
    address internal _admin3;

    address internal _




    function setUp() public {

        // Deploy modules
        // Todo Refactor modules to be initialized after deployment with a factory 



        Contest contest = new Contest(
            
        );
    }
}
