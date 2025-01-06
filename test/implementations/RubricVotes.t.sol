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

    function test_vote_twice() public {
        _standardChoices();

        _vote(judge1(), choice1(), MVPC / 2);
        _vote(judge1(), choice1(), MVPC / 2);

        assertEq(votesModule().votes(choice1(), address(judge1())), MVPC);
        assertEq(votesModule().totalVotesForChoice(choice1()), MVPC);
    }

    function test_vote_voteForEach() public {
        _standardChoices();

        _vote(judge1(), choice1(), MVPC * 45 / 100);
        _vote(judge1(), choice2(), MVPC * 87 / 100);
        _vote(judge1(), choice3(), MVPC * 78 / 100);

        assertEq(votesModule().votes(choice1(), address(judge1())), MVPC * 45 / 100);
        assertEq(votesModule().votes(choice2(), address(judge1())), MVPC * 87 / 100);
        assertEq(votesModule().votes(choice3(), address(judge1())), MVPC * 78 / 100);

        assertEq(votesModule().totalVotesForChoice(choice1()), MVPC * 45 / 100);
        assertEq(votesModule().totalVotesForChoice(choice2()), MVPC * 87 / 100);
        assertEq(votesModule().totalVotesForChoice(choice3()), MVPC * 78 / 100);
    }

    function test_vote_voteForEach_allJudges() public {
        _standardChoices();

        _vote(judge1(), choice1(), MVPC * 45 / 100);
        _vote(judge1(), choice2(), MVPC * 87 / 100);
        _vote(judge1(), choice3(), MVPC * 78 / 100);

        _vote(judge2(), choice1(), MVPC * 45 / 100);
        _vote(judge2(), choice2(), MVPC * 87 / 100);
        _vote(judge2(), choice3(), MVPC * 78 / 100);

        _vote(judge3(), choice1(), MVPC * 45 / 100);
        _vote(judge3(), choice2(), MVPC * 87 / 100);
        _vote(judge3(), choice3(), MVPC * 78 / 100);

        uint256 totalVotesForChoice1 = MVPC * 45 / 100 + MVPC * 45 / 100 + MVPC * 45 / 100;
        uint256 totalVotesForChoice2 = MVPC * 87 / 100 + MVPC * 87 / 100 + MVPC * 87 / 100;
        uint256 totalVotesForChoice3 = MVPC * 78 / 100 + MVPC * 78 / 100 + MVPC * 78 / 100;

        assertEq(votesModule().totalVotesForChoice(choice1()), totalVotesForChoice1);
        assertEq(votesModule().totalVotesForChoice(choice2()), totalVotesForChoice2);
        assertEq(votesModule().totalVotesForChoice(choice3()), totalVotesForChoice3);
    }

    function test_retractVote() public {
        _standardChoices();

        _vote(judge1(), choice1(), MVPC);
        _retract(judge1(), choice1(), MVPC);

        assertEq(votesModule().votes(choice1(), address(judge1())), 0);
        assertEq(votesModule().totalVotesForChoice(choice1()), 0);
    }

    function test_retractVote_twice() public {
        _standardChoices();

        _vote(judge1(), choice1(), MVPC);
        _retract(judge1(), choice1(), MVPC / 2);
        _retract(judge1(), choice1(), MVPC / 2);

        assertEq(votesModule().votes(choice1(), address(judge1())), 0);
        assertEq(votesModule().totalVotesForChoice(choice1()), 0);
    }

    function test_batchVote() public {
        _standardChoices();

        bytes32[] memory choiceIds = new bytes32[](3);
        choiceIds[0] = choice1();
        choiceIds[1] = choice2();
        choiceIds[2] = choice3();

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = MVPC * 83 / 100;
        amounts[1] = MVPC * 95 / 100;
        amounts[2] = MVPC * 72 / 100;

        uint256 totalAmount = MVPC * 83 / 100 + MVPC * 95 / 100 + MVPC * 72 / 100;

        bytes[] memory data = new bytes[](3);
        data[0] = abi.encode(_mockMetadata);
        data[1] = abi.encode(_mockMetadata);
        data[2] = abi.encode(_mockMetadata);

        _batchVote(judge1(), choiceIds, amounts, data, totalAmount);

        assertEq(votesModule().votes(choice1(), address(judge1())), MVPC * 83 / 100);
        assertEq(votesModule().votes(choice2(), address(judge1())), MVPC * 95 / 100);
        assertEq(votesModule().votes(choice3(), address(judge1())), MVPC * 72 / 100);

        assertEq(votesModule().totalVotesForChoice(choice1()), MVPC * 83 / 100);
        assertEq(votesModule().totalVotesForChoice(choice2()), MVPC * 95 / 100);
        assertEq(votesModule().totalVotesForChoice(choice3()), MVPC * 72 / 100);
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

    function testRevert_vote_beforeVotingPeriod() public {
        vm.expectRevert("Contest is not in voting state");
        _vote(judge1(), choice1(), MVPC);
    }

    function testRevert_retract_overAllocated() public {
        _standardChoices();
        _vote(judge1(), choice1(), MVPC / 2);

        vm.expectRevert("Amount exceeds amount already voted");
        _retract(judge1(), choice1(), MVPC / 2 + 1);
    }

    function testRevert_retract_overAllocated_double() public {
        _standardChoices();

        _vote(judge1(), choice1(), MVPC);
        _retract(judge1(), choice1(), MVPC);

        vm.expectRevert("Amount exceeds amount already voted");
        _retract(judge1(), choice1(), 1);
    }

    function testRevert_retract_notWearer() public {
        _standardChoices();
        vm.expectRevert("Only wearer");
        _retract(someGuy(), choice1(), MVPC);
    }

    function testRevert_retract_zeroAmount() public {
        _standardChoices();
        vm.expectRevert("Amount must be greater than 0");
        _retract(judge1(), choice1(), 0);
    }

    function testRevert_retract_notContest() public {
        _standardChoices();
        vm.expectRevert("Only contest");
        votesModule().retractVote(someGuy(), choice1(), MVPC, "");
    }

    function testRevert_retract_choiceDoesNotExist() public {
        _standardChoices();
        // contest does not catch this on retract to allow continuous configurations
        vm.expectRevert("Amount exceeds amount already voted");
        _retract(judge1(), choice4(), MVPC);
    }

    function testRevert_retract_beforeVotingPeriod() public {
        vm.expectRevert("Contest is not in voting state");
        _retract(judge1(), choice1(), MVPC);
    }

    //////////////////////////////
    // Helpers
    //////////////////////////////

    function _batchVote(
        address _voter,
        bytes32[] memory _choices,
        uint256[] memory _amounts,
        bytes[] memory _batchData,
        uint256 _totalAmount
    ) public {
        vm.startPrank(_voter);

        contest().batchVote(_choices, _amounts, _batchData, _totalAmount, _mockMetadata);

        vm.stopPrank();
    }

    function _retract(address _voter, bytes32 _choiceId, uint256 _amount) public {
        vm.startPrank(_voter);
        contest().retractVote(_choiceId, _amount, "");
        vm.stopPrank();
    }

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
