// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {HatsAllowList} from "../../../src/modules/choices/HatsAllowList.sol";
import {HatsSetup} from "../../setup/hatsSetup.sol";
import {Metadata} from "../../../src/core/Metadata.sol";

contract HatsAllowListTest is HatsSetup {
    event Initialized(address contest, address hatsAddress, uint256 hatId);

    event Registered(bytes32 choiceId, HatsAllowList.ChoiceData choiceData);

    event Removed(bytes32 choiceId);

    HatsAllowList hatsAllowList;

    Metadata metadata = Metadata(1, "QmWmyoMoctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWeVdD");
    Metadata metadata2 = Metadata(2, "QmBa4oMoctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWe2zF");
    Metadata metadata3 = Metadata(3, "QmHi23fctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWzt32");

    bytes choiceData = "choice1";
    bytes choiceData2 = "choice2";
    bytes choiceData3 = "choice3";

    function setUp() public {
        hatsAllowList = new HatsAllowList();
        __setupHats();
    }

    // -[x] test hats permissions
    // -[ ] test correct status Todo: Implement after status discussion
    // -[x] test does choice exist

    //////////////////////////////
    // Base Functionality Tests
    //////////////////////////////

    function test_initialize() public {
        _initialize();

        assertEq(address(hats()), address(hatsAllowList.hats()));
        assertEq(facilitator1().id, hatsAllowList.hatId());
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

    function test_init_and_prepopulate() public {
        _initialize_and_populate_choices();

        (Metadata memory _metadata1, bytes memory _choiceData1, bool _1exists) = hatsAllowList.choices(choice1());
        (Metadata memory _metadata2, bytes memory _choiceData2, bool _2exists) = hatsAllowList.choices(choice2());
        (Metadata memory _metadata3, bytes memory _choiceData3, bool _3exists) = hatsAllowList.choices(choice3());

        assertEq(address(hats()), address(hatsAllowList.hats()));
        assertEq(facilitator1().id, hatsAllowList.hatId());
        assertEq(address(this), address(hatsAllowList.contest()));

        assertEq(_metadata1.protocol, metadata.protocol);
        assertEq(_metadata1.pointer, metadata.pointer);
        assertEq(_choiceData1, choiceData);
        assertTrue(_1exists);

        assertEq(_metadata2.protocol, metadata2.protocol);
        assertEq(_metadata2.pointer, metadata2.pointer);
        assertEq(_choiceData2, choiceData2);
        assertTrue(_2exists);

        assertEq(_metadata3.protocol, metadata3.protocol);
        assertEq(_metadata3.pointer, metadata3.pointer);
        assertEq(_choiceData3, choiceData3);
        assertTrue(_3exists);
    }

    //////////////////////////////
    // Reverts
    //////////////////////////////

    function testRevert_register_notFacilitator() public {
        _initialize();

        vm.startPrank(facilitator1().wearer);
        hatsAllowList.registerChoice(choice1(), abi.encode(choiceData, metadata));
        vm.stopPrank();

        vm.expectRevert("Caller is not wearer or in good standing");

        vm.startPrank(someGuy());
        hatsAllowList.registerChoice(choice2(), abi.encode(choiceData, metadata));
        vm.stopPrank();
    }

    function testRevert_remove_notFacilitator() public {
        _register_choice();

        vm.expectRevert("Caller is not wearer or in good standing");

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
        vm.expectRevert("Caller is not wearer or in good standing");
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
        vm.expectRevert("Caller is not wearer or in good standing");
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
        vm.expectRevert("Caller is not wearer or in good standing");
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
        vm.expectRevert("Caller is not wearer or in good standing");
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

    function test_isValidChoice() public {
        _initialize_and_populate_choices();

        assertTrue(hatsAllowList.isValidChoice(choice1()));
        assertTrue(hatsAllowList.isValidChoice(choice2()));
        assertTrue(hatsAllowList.isValidChoice(choice3()));
        assertFalse(hatsAllowList.isValidChoice(choice4()));

        _remove_choice();

        assertFalse(hatsAllowList.isValidChoice(choice1()));
    }

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

        vm.expectEmit(true, false, false, true);
        emit Registered(choice1(), HatsAllowList.ChoiceData(metadata, choiceData, true));

        vm.startPrank(facilitator1().wearer);
        hatsAllowList.registerChoice(choice1(), abi.encode(choiceData, metadata));
        vm.stopPrank();
    }

    function _initialize_and_populate_choices() internal {
        bytes[] memory prePopChoiceData = new bytes[](3);

        prePopChoiceData[0] = abi.encode(choice1(), abi.encode(choiceData, metadata));
        prePopChoiceData[1] = abi.encode(choice2(), abi.encode(choiceData2, metadata2));
        prePopChoiceData[2] = abi.encode(choice3(), abi.encode(choiceData3, metadata3));

        bytes memory data = abi.encode(address(hats()), facilitator1().id, prePopChoiceData);
        hatsAllowList.initialize(address(this), data);
    }

    function _initialize() internal {
        vm.expectEmit(true, false, false, true);
        emit Initialized(address(this), address(hats()), facilitator1().id);

        bytes memory data = abi.encode(address(hats()), facilitator1().id, "");

        hatsAllowList.initialize(address(this), data);
    }
}
