// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Accounts} from "../../setup/Accounts.t.sol";
import {Test, console} from "forge-std/Test.sol";
import {Hats} from "lib/hats-protocol/src/Hats.sol";
import {InboxChoices} from "../../../src/modules/choices/InboxChoices.sol";
import {BasicChoice} from "../../../src/core/Choice.sol";
import {Metadata} from "../../../src/core/Metadata.sol";

contract InboxChoicesTest is Accounts, Test {
    event Initialized(address contest, address hatsAddress, uint256 adminHatId);
    event Registered(bytes32 choiceId, BasicChoice choiceData, address contest);
    event Removed(bytes32 choiceId, address contest);

    InboxChoices inboxChoices;
    Hats hats;

    uint256 topHatId;
    uint256 adminHatId;
    address[] public admins;

    BasicChoice dummyChoice = BasicChoice(Metadata(1, "Dummy Metadata"), "", false, makeAddr("FAKE"));

    function setUp() public {
        inboxChoices = new InboxChoices();
        _setupHats();
    }

    /////////////////////////////
    // Basic Functionality Tests
    /////////////////////////////

    function testInitialize() public {
        _initialize();

        assertEq(address(inboxChoices.contest()), address(this));
        assertEq(inboxChoices.adminHatId(), adminHatId);
        assertEq(adminHatId, inboxChoices.adminHatId());
        assertEq(address(inboxChoices.hats()), address(hats));
    }

    function testRegisterChoice() public {
        _initialize();
    }

    /////////////////////////////
    // Reverts
    /////////////////////////////

    /////////////////////////////
    // Helpers
    /////////////////////////////

    function _initialize() public {
        bytes memory initData = abi.encode(address(hats), adminHatId);

        vm.expectEmit(true, false, false, true);
        emit Initialized(address(this), address(hats), adminHatId);
        inboxChoices.initialize(address(this), initData);
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
