// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {AskHausSetupLive} from "./../setup/AskHausSetup.t.sol";
import {HolderType} from "../../src/core/BaalUtils.sol";
import {ContestStatus} from "../../src/core/ContestStatus.sol";
import {Metadata} from "../../src/core/Metadata.sol";

contract AskHausPollTest is Test, AskHausSetupLive {
    function setUp() public {
        vm.createSelectFork({blockNumber: START_BLOCK, urlOrAlias: "sepolia"});
        __setupAskHausPoll(HolderType.Both);
    }

    //////////////////////////////
    // Init
    //////////////////////////////

    function test_init() public view {
        // contest params
        assertEq(uint8(contest().contestStatus()), uint8(ContestStatus.Voting));
        assertTrue(contest().isRetractable());
        assertFalse(contest().isContinuous());
        assertEq(address(contest().votesModule()), address(baalVotes()));
        assertEq(address(contest().choicesModule()), address(prepop()));
        assertEq(address(contest().pointsModule()), address(baalPoints()));
        assertEq(address(contest().executionModule()), address(execution()));

        // votes params
        assertEq(baalVotes().duration(), TWO_WEEKS);

        assertEq(address(baalVotes().contest()), address(contest()));

        // points params
        assertEq(baalPoints().dao(), address(dao()));
        assertEq(uint8(baalPoints().holderType()), uint8(HolderType.Both));
        assertEq(baalPoints().checkpoint(), snapshotTimestamp);
        assertEq(address(baalPoints().sharesToken()), address(shares()));
        assertEq(address(baalPoints().lootToken()), address(loot()));
        assertEq(address(baalPoints().contest()), address(contest()));

        // choices params
        assertEq(address(prepop().contest()), address(contest()));

        (Metadata memory choice1Metadata, bytes memory choice1Bytes, bool choice1Exists, address choice1Registrar) =
            prepop().choices(choice1());
        (Metadata memory choice2Metadata, bytes memory choice2Bytes, bool choice2Exists, address choice2Registrar) =
            prepop().choices(choice2());
        (Metadata memory choice3Metadata, bytes memory choice3Bytes, bool choice3Exists, address choice3Registrar) =
            prepop().choices(choice3());

        assertEq(choice1Metadata.protocol, _mockMetadata.protocol);
        assertEq(choice1Metadata.pointer, _mockMetadata.pointer);
        assertEq(choice1Bytes, "1");
        assertEq(choice1Exists, true);
        assertEq(choice1Registrar, address(1));

        assertEq(choice2Metadata.protocol, _mockMetadata.protocol);
        assertEq(choice2Metadata.pointer, _mockMetadata.pointer);
        assertEq(choice2Bytes, "2");
        assertEq(choice2Exists, true);
        assertEq(choice2Registrar, address(2));

        assertEq(choice3Metadata.protocol, _mockMetadata.protocol);
        assertEq(choice3Metadata.pointer, _mockMetadata.pointer);
        assertEq(choice3Bytes, "3");
        assertEq(choice3Exists, true);
        assertEq(choice3Registrar, address(3));

        // execution params
        assertEq(address(execution().contest()), address(contest()));
    }

    function test_vote() public {
        _vote(voter1(), choice1(), 1);
    }

    //////////////////////////////
    // Unit Tests
    //////////////////////////////

    //////////////////////////////
    // Compound Tests
    //////////////////////////////

    //////////////////////////////
    // Reverts
    //////////////////////////////

    //////////////////////////////
    // Helpers
    //////////////////////////////

    function _retract() public {}

    function _vote(address _voter, bytes32 _choice, uint256 _amount) public {
        vm.startPrank(_voter);
        contest().vote(_choice, _amount, "");
        vm.stopPrank();
    }
}
