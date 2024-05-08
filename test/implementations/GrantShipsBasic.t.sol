// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {GrantShipsSetup} from "../setup/GrantShipsSetup.t.sol";
import {ContestStatus} from "../../src/core/ContestStatus.sol";
import {Metadata} from "../../src/core/Metadata.sol";
import {HatsAllowList} from "../../src/modules/choices/HatsAllowList.sol";

contract GrantShipsBasic is GrantShipsSetup {
    Metadata metadata = Metadata(1, "QmWmyoMoctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWeVdD");
    Metadata metadata2 = Metadata(2, "QmBa4oMoctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWe2zF");
    Metadata metadata3 = Metadata(3, "QmHi23fctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWzt32");

    bytes choiceData = "choice1";
    bytes choiceData2 = "choice2";
    bytes choiceData3 = "choice3";

    function setUp() public {
        __setupGrantShipsBasic();
    }

    function test_setup() public view {
        // Check that the votes module is set up correctly

        assertEq(address(votesModule().contest()), address(contest()));
        assertEq(votesModule().duration(), TWO_WEEKS);

        // Check that the choices module is set up correctly

        assertEq(address(choicesModule().contest()), address(contest()));
        assertEq(address(choicesModule().hats()), address(hats()));
        assertEq(choicesModule().hatId(), facilitator1().id);

        // Check that the points module is set up correctly

        assertEq(pointsModule().votingCheckpoint(), SNAPSHOT_BLOCK);
        assertEq(address(pointsModule().voteToken()), address(arbToken()));
        assertEq(address(pointsModule().contest()), address(contest()));

        // Check that the contest is set up correctly

        assertEq(address(contest().votesModule()), address(votesModule()));
        assertEq(address(contest().pointsModule()), address(pointsModule()));
        assertEq(address(contest().choicesModule()), address(choicesModule()));
        assertEq(contest().executionContract(), signalOnly);
        assertEq(contest().isContinuous(), false);
        assertEq(contest().isRetractable(), false);

        assertEq(uint8(contest().contestStatus()), uint8(ContestStatus.Populating));
    }

    function test_populate() public {
        _populate();

        (Metadata memory choice1Metadata, bytes memory choice1bytesData, bool choice1exists) =
            choicesModule().choices(choice1());

        (Metadata memory choice2Metadata, bytes memory choice2bytesData, bool choice2exists) =
            choicesModule().choices(choice2());

        (Metadata memory choice3Metadata, bytes memory choice3bytesData, bool choice3exists) =
            choicesModule().choices(choice3());

        assertEq(choice1Metadata.protocol, metadata.protocol);
        assertEq(choice1Metadata.pointer, metadata.pointer);
        assertEq(choice1bytesData, choiceData);
        assertTrue(choice1exists);

        assertEq(choice2Metadata.protocol, metadata2.protocol);
        assertEq(choice2Metadata.pointer, metadata2.pointer);
        assertEq(choice2bytesData, choiceData2);
        assertTrue(choice2exists);

        assertEq(choice3Metadata.protocol, metadata3.protocol);
        assertEq(choice3Metadata.pointer, metadata3.pointer);
        assertEq(choice3bytesData, choiceData3);
        assertTrue(choice3exists);
    }

    function _populate() internal {
        vm.prank(facilitator1().wearer);
        choicesModule().registerChoice(choice1(), abi.encode(choiceData, metadata));

        vm.prank(facilitator2().wearer);
        choicesModule().registerChoice(choice2(), abi.encode(choiceData2, metadata2));

        vm.prank(facilitator3().wearer);
        choicesModule().registerChoice(choice3(), abi.encode(choiceData3, metadata3));
    }
}
