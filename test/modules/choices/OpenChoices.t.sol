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
    address[] public admins;

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

    function testInitialize() public {
        _initialize_self();

        assertEq(address(openChoices.contest()), address(mockContest()));
        assertEq(openChoices.adminHatId(), adminHatId);
        assertEq(adminHatId, openChoices.adminHatId());
        assertEq(address(openChoices.hats()), address(hats));
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

    function _removeChoice(bytes32 _choiceId) private {
        vm.expectEmit(true, false, false, true);
        emit Removed(_choiceId, address(mockContest()));

        vm.prank(admin1());
        openChoices.removeChoice(_choiceId, "");
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
