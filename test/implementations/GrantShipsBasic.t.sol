// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {GrantShipsSetup} from "../setup/GrantShipsSetup.t.sol";
import {ContestStatus} from "../../src/core/ContestStatus.sol";

contract GrantShipsBasic is GrantShipsSetup {
    function setUp() public {
        __setupGrantShips();
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
}
