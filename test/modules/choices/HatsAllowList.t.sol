// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {HatsAllowList} from "../../../src/modules/choices/HatsAllowList.sol";
import {HatsSetup} from "../../setup/hatsSetup.sol";
import {Metadata} from "../../../src/core/Metadata.sol";

contract HatsAllowListTest is HatsSetup {
    HatsAllowList hatsAllowList;

    Metadata metadata = Metadata(1, "QmWmyoMoctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWeVdD");
    bytes choiceData = "choice1";

    function setUp() public {
        hatsAllowList = new HatsAllowList();
        __setupHats();
    }

    // -[ ] test hats permissions
    // -[ ] test correct status
    // -[ ] test does choice exist

    //////////////////////////////
    // Base Functionality Tests
    //////////////////////////////

    function test_initialize() public {
        _initialize();

        assertEq(address(hats()), address(hatsAllowList.hats()));
        assertEq(facilitator1().id, hatsAllowList.facilitatorHatId());
        assertEq(address(this), address(hatsAllowList.contest()));
    }

    function test_register_choice() public {
        _register_choice();

        (Metadata memory _metadata, bytes memory _choiceData, bool _exists) = hatsAllowList.choices(choice1());

        assertEq(_metadata.protocol, metadata.protocol);
        assertEq(_metadata.pointer, metadata.pointer);
        assertEq(_choiceData, choiceData);
        assertTrue(_exists);
    }

    function test_remove_choice() public {
        _remove_choice();

        (Metadata memory _metadata, bytes memory _choiceData, bool _exists) = hatsAllowList.choices(choice1());

        assertEq(_metadata.protocol, 0);
        assertEq(_metadata.pointer, "");
        assertEq(_choiceData, "");
        assertFalse(_exists);
    }

    //////////////////////////////
    // Reverts
    //////////////////////////////

    //////////////////////////////
    // Getters
    //////////////////////////////

    //////////////////////////////
    // Helpers
    //////////////////////////////

    function _remove_choice() internal {
        _register_choice();

        vm.startPrank(facilitator1().wearer);
        hatsAllowList.removeChoice(choice1(), "");
        vm.stopPrank();
    }

    function _register_choice() internal {
        _initialize();

        vm.startPrank(facilitator1().wearer);

        hatsAllowList.registerChoice(choice1(), abi.encode(choiceData, metadata));
        vm.stopPrank();
    }

    function _initialize() internal {
        bytes memory data = abi.encode(address(hats()), facilitator1().id);
        hatsAllowList.initialize(address(this), data);
    }
}
