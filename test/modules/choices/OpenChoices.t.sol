// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Accounts} from "../../setup/Accounts.t.sol";
import {Test, console} from "forge-std/Test.sol";
import {Hats} from "lib/hats-protocol/src/Hats.sol";
import {OpenChoices} from "../../../src/modules/choices/OpenChoices.sol";
import {BasicChoice} from "../../../src/core/Choice.sol";
import {Metadata} from "../../../src/core/Metadata.sol";
import {MockContestSetup} from "../../setup/MockContest.sol";
import {ContestStatus} from "../../../src/core/ContestStatus.sol";

contract OpenChoicesTest is Accounts, Test, MockContestSetup {
    event Initialized(address contest, address hatsAddress, uint256 adminHatId, bool canNominate);
    event Registered(bytes32 choiceId, BasicChoice choiceData, address contest);
    event Removed(bytes32 choiceId, address contest);

    error InvalidInitialization();

    OpenChoices openChoices;
    Hats hats;

    uint256 topHatId;
    uint256 adminHatId;
    address[] admins;

    Metadata dummyMetadata1 = Metadata(1, "metadata1");

    function setUp() public {
        openChoices = new OpenChoices();
        __setupMockContest();
        _setupHats();

        mockContest().cheatStatus(ContestStatus.Populating);
    }

    /////////////////////////////
    // Basic Functionality Tests
    /////////////////////////////

    function testInitialize_self() public {
        _initialize_self();

        assertEq(address(openChoices.contest()), address(mockContest()));
        assertEq(openChoices.adminHatId(), adminHatId);
        assertEq(adminHatId, openChoices.adminHatId());
        assertEq(address(openChoices.hats()), address(hats));
        assertFalse(openChoices.canNominate());
    }

    function testInitialize_nominate() public {
        _initialize_nominate();

        assertEq(address(openChoices.contest()), address(mockContest()));
        assertEq(openChoices.adminHatId(), adminHatId);
        assertEq(adminHatId, openChoices.adminHatId());
        assertEq(address(openChoices.hats()), address(hats));
        assertTrue(openChoices.canNominate());
    }

    function testRegisterChoice_self() public {
        _initialize_self();

        _registerChoice_self();

        BasicChoice memory choice = openChoices.getChoice(choice1());

        assertEq(choice.metadata.protocol, dummyMetadata1.protocol);
        assertEq(choice.metadata.pointer, dummyMetadata1.pointer);
        assertEq(choice.data, "");
        assertEq(choice.registrar, nominee1());
        assertEq(choice.exists, true);
    }

    function testRegisterChoice_nominate() public {
        _initialize_nominate();

        _registerChoice_nominate();

        BasicChoice memory choice = openChoices.getChoice(choice1());

        assertEq(choice.metadata.protocol, dummyMetadata1.protocol);
        assertEq(choice.metadata.pointer, dummyMetadata1.pointer);
        assertEq(choice.data, "");
        assertEq(choice.registrar, nominee2());
        assertEq(choice.exists, true);
    }

    function testRemoveChoice() public {
        _initialize_self();
        _registerChoice_self();

        BasicChoice memory choice = openChoices.getChoice(choice1());

        assertEq(choice.metadata.protocol, dummyMetadata1.protocol);
        assertEq(choice.metadata.pointer, dummyMetadata1.pointer);
        assertEq(choice.data, "");
        assertEq(choice.registrar, nominee1());
        assertEq(choice.exists, true);

        _removeChoice(choice1());

        choice = openChoices.getChoice(choice1());

        assertEq(choice.metadata.protocol, dummyMetadata1.protocol);
        assertEq(choice.metadata.pointer, dummyMetadata1.pointer);
        assertEq(choice.data, "");
        assertEq(choice.registrar, nominee1());
        assertEq(choice.exists, false);
    }

    function testRemoveChoice_nominate() public {
        _initialize_nominate();
        _registerChoice_nominate();

        BasicChoice memory choice = openChoices.getChoice(choice1());

        assertEq(choice.metadata.protocol, dummyMetadata1.protocol);
        assertEq(choice.metadata.pointer, dummyMetadata1.pointer);
        assertEq(choice.data, "");
        assertEq(choice.registrar, nominee2());
        assertEq(choice.exists, true);

        _removeChoice(choice1());

        choice = openChoices.getChoice(choice1());

        assertEq(choice.metadata.protocol, dummyMetadata1.protocol);
        assertEq(choice.metadata.pointer, dummyMetadata1.pointer);
        assertEq(choice.data, "");
        assertEq(choice.registrar, nominee2());
        assertEq(choice.exists, false);
    }

    function testFinalize() public {
        _initialize_self();
        _registerChoice_self();

        _finalize();

        assertEq(uint8(openChoices.contest().contestStatus()), uint8(ContestStatus.Voting));
    }

    function testRetractChoice_afterFinalize() public {
        _initialize_self();
        _registerChoice_self();
        _finalize();

        _removeChoice(choice1());
    }

    /////////////////////////////
    // Reverts
    /////////////////////////////

    function testInitializeTwice() public {
        _initialize_self();

        bytes memory initData = abi.encode(address(hats), adminHatId, false);

        vm.expectRevert(InvalidInitialization.selector);
        openChoices.initialize(address(mockContest()), initData);
    }

    function testRegisterNotPopulating() public {
        _initialize_self();

        bytes memory choiceData = abi.encode("", dummyMetadata1, nominee1());

        vm.startPrank(nominee1());

        mockContest().cheatStatus(ContestStatus.Voting);
        vm.expectRevert("Contest is not in populating state");
        openChoices.registerChoice(choice1(), choiceData);

        mockContest().cheatStatus(ContestStatus.None);
        vm.expectRevert("Contest is not in populating state");
        openChoices.registerChoice(choice1(), choiceData);

        mockContest().cheatStatus(ContestStatus.None);
        vm.expectRevert("Contest is not in populating state");
        openChoices.registerChoice(choice1(), choiceData);

        mockContest().cheatStatus(ContestStatus.Finalized);
        vm.expectRevert("Contest is not in populating state");
        openChoices.registerChoice(choice1(), choiceData);

        mockContest().cheatStatus(ContestStatus.Continuous);
        vm.expectRevert("Contest is not in populating state");
        openChoices.registerChoice(choice1(), choiceData);

        vm.stopPrank();
    }

    function testRevert_self_cannotNominate() public {
        _initialize_self();

        bytes memory choiceData = abi.encode("", dummyMetadata1, nominee2());

        vm.expectRevert("Cannot nominate others");

        vm.startPrank(nominee1());
        openChoices.registerChoice(choice1(), choiceData);
    }

    function testRevert_choiceDoesNotExist() public {
        _initialize_self();
        vm.expectRevert("Choice does not exist");

        vm.startPrank(admin1());
        openChoices.removeChoice(choice2(), "");
    }

    function testRevert_registerChoice_zero() public {
        _initialize_nominate();

        vm.expectRevert("Registrar must not be zero");

        bytes memory choiceData = abi.encode("", dummyMetadata1, address(0));

        vm.startPrank(nominee1());
        openChoices.registerChoice(choice1(), choiceData);
    }

    function testRevert_finalize_notAdmin() public {
        _initialize_self();

        vm.expectRevert("Caller is not wearer or in good standing");

        vm.startPrank(someGuy());
        openChoices.finalizeChoices();
    }

    function testRevert_removeChoice_notAdmin() public {
        _initialize_self();
        _registerChoice_self();

        vm.expectRevert("Caller is not wearer or in good standing");

        vm.startPrank(someGuy());
        openChoices.removeChoice(choice1(), "");
    }

    function testRevert_finalize_alreadyFinalized() public {
        _initialize_self();
        _registerChoice_self();
        _finalize();

        vm.expectRevert("Contest is not in populating state");

        vm.startPrank(admin1());
        openChoices.finalizeChoices();
    }

    function testRevert_register_afterFinalize() public {
        _initialize_self();
        _registerChoice_self();
        _finalize();

        vm.expectRevert("Contest is not in populating state");

        vm.startPrank(nominee1());
        openChoices.registerChoice(choice1(), "");
    }

    /////////////////////////////
    // Adversarial
    /////////////////////////////

    function testAttack_Resubmit() public {
        // contract initializes
        _initialize_self();

        // malicious user registers choice
        _registerChoice_self();

        // admins remove choice

        _removeChoice(choice1());

        // user can just simply resubmit choice
        _registerChoice_self();

        // If this happens, the admin can lock submissions at the end of the submission round.
        vm.startPrank(admin1());

        openChoices.lock();
        openChoices.removeChoice(choice1(), "");
        vm.stopPrank();

        // then once the user resubmits, it should revert

        vm.expectRevert("Locked");
        openChoices.registerChoice(choice1(), "");

        // attacker cannot unlock

        vm.expectRevert("Caller is not wearer or in good standing");
        vm.prank(nominee1());
        openChoices.lock();

        // then admin can finalize the module

        vm.prank(admin1());
        openChoices.finalizeChoices();

        // and the user can resubmit

        vm.expectRevert("Contest is not in populating state");
        vm.prank(nominee1());
        openChoices.registerChoice(choice1(), "");
    }

    function testAttack_manipulate() public {
        // contract initializes

        _initialize_self();

        // regular user registers choice
        _registerChoice_self();

        // other malicious user mutates their choice so that they are the registrar
        vm.startPrank(nominee2());

        bytes memory choiceData = abi.encode("", dummyMetadata1, nominee2());

        // user tries to mutate another user's choice
        vm.expectRevert("Only registrar can edit");
        openChoices.registerChoice(choice1(), choiceData);
    }

    /////////////////////////////
    // Helpers
    /////////////////////////////

    function _initialize_self() public {
        bytes memory initData = abi.encode(address(hats), adminHatId, false);

        vm.expectEmit(true, false, false, true);
        emit Initialized(address(mockContest()), address(hats), adminHatId, false);
        openChoices.initialize(address(mockContest()), initData);
    }

    function _initialize_nominate() public {
        bytes memory initData = abi.encode(address(hats), adminHatId, true);

        vm.expectEmit(true, false, false, true);
        emit Initialized(address(mockContest()), address(hats), adminHatId, true);
        openChoices.initialize(address(mockContest()), initData);
    }

    function _registerChoice_self() private {
        bytes memory choiceData = abi.encode("", dummyMetadata1, nominee1());

        BasicChoice memory _choice = BasicChoice(dummyMetadata1, "", true, nominee1());

        vm.expectEmit(true, false, false, true);
        emit Registered(choice1(), _choice, address(mockContest()));

        vm.prank(nominee1());
        openChoices.registerChoice(choice1(), choiceData);
    }

    function _registerChoice_nominate() private {
        bytes memory choiceData = abi.encode("", dummyMetadata1, nominee2());

        BasicChoice memory _choice = BasicChoice(dummyMetadata1, "", true, nominee2());

        vm.expectEmit(true, false, false, true);
        emit Registered(choice1(), _choice, address(mockContest()));

        vm.prank(nominee1());
        openChoices.registerChoice(choice1(), choiceData);
    }

    function _removeChoice(bytes32 _choiceId) private {
        vm.expectEmit(true, false, false, true);
        emit Removed(_choiceId, address(mockContest()));

        vm.prank(admin1());
        openChoices.removeChoice(_choiceId, "");
    }

    function _finalize() private {
        vm.prank(admin1());
        openChoices.finalizeChoices();
    }

    function _setupHats() private {
        hats = new Hats("", "");

        topHatId = hats.mintTopHat(dummyDao(), "", "");

        vm.prank(dummyDao());
        adminHatId = hats.createHat(topHatId, "admin", 100, address(13), address(13), true, "");

        admins.push(admin1());
        admins.push(admin2());

        uint256[] memory adminIds = new uint256[](admins.length);

        adminIds[0] = adminHatId;
        adminIds[1] = adminHatId;

        vm.prank(dummyDao());

        hats.batchMintHats(adminIds, admins);
    }
}
