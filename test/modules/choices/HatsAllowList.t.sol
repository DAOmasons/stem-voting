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

    // -[x] test hats permissions
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

    function test_overwrite_choice() public {
        _register_choice();

        (Metadata memory _metadata, bytes memory _choiceData, bool _exists) = hatsAllowList.choices(choice1());

        assertEq(_metadata.protocol, metadata.protocol);
        assertEq(_metadata.pointer, metadata.pointer);
        assertEq(_choiceData, choiceData);
        assertTrue(_exists);

        Metadata memory newMetadata = Metadata(2, "QmBa4oMoctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWe2zF");
        bytes memory newChoiceData = "choice2";

        vm.startPrank(facilitator1().wearer);
        hatsAllowList.registerChoice(choice1(), abi.encode(newChoiceData, newMetadata));
        vm.stopPrank();

        (Metadata memory _newMetadata, bytes memory _newChoiceData, bool _newExists) = hatsAllowList.choices(choice1());

        assertEq(_newMetadata.protocol, newMetadata.protocol);
        assertEq(_newMetadata.pointer, newMetadata.pointer);
        assertEq(_newChoiceData, newChoiceData);
        assertTrue(_newExists);
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

    function testRevert_register_notFacilitator() public {
        _initialize();

        vm.startPrank(facilitator1().wearer);
        hatsAllowList.registerChoice(choice1(), abi.encode(choiceData, metadata));
        vm.stopPrank();

        vm.expectRevert("Caller is not facilitator or in good standing");

        vm.startPrank(someGuy());
        hatsAllowList.registerChoice(choice2(), abi.encode(choiceData, metadata));
        vm.stopPrank();
    }

    function testRevert_remove_notFacilitator() public {
        _register_choice();

        vm.expectRevert("Caller is not facilitator or in good standing");

        vm.startPrank(someGuy());
        hatsAllowList.removeChoice(choice1(), "");
        vm.stopPrank();

        vm.startPrank(facilitator1().wearer);
        hatsAllowList.removeChoice(choice1(), "");
        vm.stopPrank();
    }

    function testRevert_register_notGoodStanding() public {
        _initialize();

        // Top Hat sets ineligible
        vm.startPrank(topHat().wearer);
        eligibility().setStanding(facilitator1().id, facilitator1().wearer, false);
        vm.stopPrank();

        // Facilitator should fail to register choice when ineligible
        vm.expectRevert("Caller is not facilitator or in good standing");
        vm.startPrank(facilitator1().wearer);
        hatsAllowList.registerChoice(choice1(), abi.encode(choiceData, metadata));
        vm.stopPrank();

        // Top Hat sets eligible && mints a new Hat for Facilitator
        vm.startPrank(topHat().wearer);
        eligibility().setStanding(facilitator1().id, facilitator1().wearer, true);
        hats().mintHat(facilitator1().id, facilitator1().wearer);
        vm.stopPrank();

        // Facilitator should succeed in registering choice
        vm.startPrank(facilitator1().wearer);
        hatsAllowList.registerChoice(choice1(), abi.encode(choiceData, metadata));
        vm.stopPrank();
    }

    function testRevert_remove_notGoodStanding() public {
        _register_choice();

        // Top Hat sets ineligible
        vm.startPrank(topHat().wearer);
        eligibility().setStanding(facilitator1().id, facilitator1().wearer, false);
        vm.stopPrank();

        // Facilitator should fail to remove choice when ineligible
        vm.expectRevert("Caller is not facilitator or in good standing");
        vm.startPrank(facilitator1().wearer);
        hatsAllowList.removeChoice(choice1(), "");
        vm.stopPrank();

        // Top Hat sets eligible && mints a new Hat for Facilitator
        vm.startPrank(topHat().wearer);
        eligibility().setStanding(facilitator1().id, facilitator1().wearer, true);
        hats().mintHat(facilitator1().id, facilitator1().wearer);
        vm.stopPrank();

        // Facilitator should succeed in removing choice
        vm.startPrank(facilitator1().wearer);
        hatsAllowList.removeChoice(choice1(), "");
        vm.stopPrank();
    }

    function testRevert_register_notWearer() public {
        _initialize();

        // Top Hat gives removes facilitator's hat and gives it to some guy
        vm.startPrank(topHat().wearer);
        hats().transferHat(facilitator1().id, facilitator1().wearer, someGuy());
        vm.stopPrank();

        // some guy should be able to register choice
        vm.startPrank(someGuy());
        hatsAllowList.registerChoice(choice2(), abi.encode(choiceData, metadata));
        vm.stopPrank();

        // Facilitator should fail when registering choice since they do not have the hat
        vm.expectRevert("Caller is not facilitator or in good standing");
        vm.prank(facilitator1().wearer);
        hatsAllowList.registerChoice(choice2(), abi.encode(choiceData, metadata));
        vm.stopPrank();
    }

    function testRevert_remove_notWearer() public {
        _register_choice();

        // Top Hat gives removes facilitator's hat and gives it to some guy
        vm.startPrank(topHat().wearer);
        hats().transferHat(facilitator1().id, facilitator1().wearer, someGuy());
        vm.stopPrank();

        // some guy should be able to remove choice
        vm.startPrank(someGuy());
        hatsAllowList.removeChoice(choice1(), "");
        vm.stopPrank();

        // Facilitator should fail when removing choice since they do not have the hat
        vm.expectRevert("Caller is not facilitator or in good standing");
        vm.prank(facilitator1().wearer);
        hatsAllowList.removeChoice(choice1(), "");
        vm.stopPrank();
    }

    function testRevert_choiceDoesNotExist() public {
        _register_choice();

        vm.expectRevert("Choice does not exist");
        vm.startPrank(facilitator1().wearer);
        hatsAllowList.removeChoice(choice2(), "");
        vm.stopPrank();
    }

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
