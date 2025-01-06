// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console} from "forge-std/Test.sol";
import {RubricVotesSetup} from "../setup/RubricVotesSetup.t.sol";
import {Metadata} from "../../src/core/Metadata.sol";
import {ContestStatus} from "../../src/core/ContestStatus.sol";
import {BasicChoice} from "../../src/core/Choice.sol";

contract ReviewVotesTest is RubricVotesSetup {
    bytes choiceData1 = "choice1";
    bytes choiceData2 = "choice2";
    bytes choiceData3 = "choice3";

    Metadata metadata1 = Metadata(1, "QmWmyoMoctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWeVdD");
    Metadata metadata2 = Metadata(2, "QmBa4oMoctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWe2zF");
    Metadata metadata3 = Metadata(3, "QmHi23fctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWzt32");

    function setUp() public {
        __deployRubricVotes();
    }

    //////////////////////////////
    // Init
    //////////////////////////////
    function test_init() public view {
        assertEq(uint8(contest().contestStatus()), uint8(ContestStatus.Populating));

        assertTrue(contest().isRetractable());
        assertFalse(contest().isContinuous());

        assertEq(address(contest().votesModule()), address(votesModule()));
        assertEq(address(contest().choicesModule()), address(choicesModule()));
        assertEq(address(contest().pointsModule()), address(pointsModule()));
        assertEq(address(contest().executionModule()), address(executionModule()));

        // votes params

        assertEq(address(votesModule().contest()), address(contest()));
        assertEq(votesModule().adminHatId(), adminHatId);
        assertEq(votesModule().judgeHatId(), judgeHatId);
        assertEq(votesModule().maxVotesForChoice(), MVPC);

        // choices params

        assertEq(address(choicesModule().contest()), address(contest()));
        assertEq(choicesModule().hatId(), adminHatId);
        assertEq(address(choicesModule().hats()), address(hats));
    }

    //////////////////////////////
    // Basic Tests
    //////////////////////////////

    function test_registerChoice() public {
        _registerChoice(choice1(), choiceData1, metadata1);

        (Metadata memory metadata, bytes memory data, bool exists) = choicesModule().choices(choice1());

        assertEq(metadata.protocol, metadata1.protocol);
        assertEq(metadata.pointer, metadata1.pointer);
        assertEq(data, choiceData1);
        assertTrue(exists);
    }

    function test_removeChoice() public {
        _registerChoice(choice1(), choiceData1, metadata1);
        _removeChoice(choice1());

        (Metadata memory metadata, bytes memory data, bool exists) = choicesModule().choices(choice1());

        assertEq(metadata.protocol, 0);
        assertEq(metadata.pointer, "");
        assertEq(data, "");
        assertFalse(exists);
    }

    function test_setupChoices() public {
        _standardChoices();

        (Metadata memory _metadata1, bytes memory _data1, bool _exists1) = choicesModule().choices(choice1());

        assertEq(_metadata1.protocol, _metadata1.protocol);
        assertEq(_metadata1.pointer, _metadata1.pointer);
        assertEq(_data1, choiceData1);
        assertTrue(_exists1);

        (Metadata memory _metadata2, bytes memory _data2, bool _exists2) = choicesModule().choices(choice2());

        assertEq(_metadata2.protocol, _metadata2.protocol);
        assertEq(_metadata2.pointer, _metadata2.pointer);
        assertEq(_data2, choiceData2);
        assertTrue(_exists2);

        (Metadata memory _metadata3, bytes memory _data3, bool _exists3) = choicesModule().choices(choice3());

        assertEq(_metadata3.protocol, _metadata3.protocol);
        assertEq(_metadata3.pointer, _metadata3.pointer);
        assertEq(_data3, choiceData3);
        assertTrue(_exists3);
    }

    function test_vote() public {
        _standardChoices();

        _vote(judge1(), choice1(), MVPC);

        assertEq(votesModule().votes(choice1(), address(judge1())), MVPC);
        assertEq(votesModule().totalVotesForChoice(choice1()), MVPC);
    }

    //////////////////////////////
    // Reverts
    //////////////////////////////

    function testRevert_vote_overMvpc() public {
        _standardChoices();

        vm.expectRevert("Amount exceeds maxVotesForChoice");
        _vote(judge1(), choice1(), MVPC + 1);
    }

    function testRevert_vote_overMvpc_doubleVote() public {
        _standardChoices();

        _vote(judge1(), choice1(), MVPC);
        vm.expectRevert("Amount exceeds maxVotesForChoice");
        _vote(judge1(), choice1(), 1);

        vm.expectRevert("Amount exceeds maxVotesForChoice");
        _vote(judge1(), choice1(), MVPC);
    }

    function testRevert_vote_notWearer() public {
        _standardChoices();
        vm.expectRevert("Only wearer");
        _vote(someGuy(), choice1(), MVPC);
    }

    function testRevert_vote_zeroAmount() public {
        _standardChoices();
        vm.expectRevert("Amount must be greater than 0");
        _vote(judge1(), choice1(), 0);
    }

    function testRevert_vote_notContest() public {
        _standardChoices();
        vm.expectRevert("Only contest");
        votesModule().vote(someGuy(), choice1(), MVPC, abi.encode(_mockMetadata));
    }

    function testRevert_vote_choiceDoesNotExist() public {
        _standardChoices();
        vm.expectRevert("Choice does not exist");
        _vote(judge1(), choice4(), MVPC);
    }

    //////////////////////////////
    // Helpers
    //////////////////////////////

    function _vote(address _voter, bytes32 _choiceId, uint256 _amount) public {
        vm.startPrank(_voter);
        contest().vote(_choiceId, _amount, abi.encode(_mockMetadata));
        vm.stopPrank();
    }

    function _removeChoice(bytes32 _choiceId) public {
        vm.startPrank(admin1());
        choicesModule().removeChoice(_choiceId, "");
        vm.stopPrank();
    }

    function _registerChoice(bytes32 _choiceId, bytes memory _data, Metadata memory _metadata) public {
        vm.startPrank(admin1());
        choicesModule().registerChoice(_choiceId, abi.encode(_data, _metadata));
        vm.stopPrank();
    }

    function finalizeChoices() public {
        vm.startPrank(admin1());
        choicesModule().finalizeChoices();
        vm.stopPrank();
    }

    function _standardChoices() public {
        _registerChoice(choice1(), choiceData1, metadata1);
        _registerChoice(choice2(), choiceData2, metadata2);
        _registerChoice(choice3(), choiceData3, metadata3);

        finalizeChoices();
    }
}
