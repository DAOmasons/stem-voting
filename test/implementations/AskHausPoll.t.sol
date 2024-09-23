// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {AskHausSetupLive} from "./../setup/AskHausSetup.t.sol";
import {HolderType} from "../../src/core/BaalUtils.sol";
import {ContestStatus} from "../../src/core/ContestStatus.sol";
import {Metadata} from "../../src/core/Metadata.sol";
import {Contest} from "../../src/Contest.sol";

contract AskHausPollTest is Test, AskHausSetupLive {
    bytes32[] _allThreeChoices;
    uint256[] _equalSplit;
    uint256[] _equalPartial;
    uint256[] _favorsChoice1;
    uint256[] _favorsChoice2;
    bytes[] _batchData;

    Metadata emptyMetadata;

    function setUp() public {
        vm.createSelectFork({blockNumber: START_BLOCK, urlOrAlias: "sepolia"});
        __setupAskHausPoll(HolderType.Both);

        _allThreeChoices.push(choice1());
        _allThreeChoices.push(choice2());
        _allThreeChoices.push(choice3());

        _equalSplit.push(voteAmount / 3);
        _equalSplit.push(voteAmount / 3);
        _equalSplit.push(voteAmount / 3);

        _equalPartial.push(voteAmount / 6);
        _equalPartial.push(voteAmount / 6);
        _equalPartial.push(voteAmount / 6);

        _favorsChoice1.push(voteAmount / 2);
        _favorsChoice1.push(voteAmount / 4);
        _favorsChoice1.push(voteAmount / 4);

        _favorsChoice2.push(voteAmount / 4);
        _favorsChoice2.push(voteAmount / 2);
        _favorsChoice2.push(voteAmount / 4);

        _batchData.push(abi.encode(_mockMetadata));
        _batchData.push(abi.encode(_mockMetadata));
        _batchData.push(abi.encode(_mockMetadata));
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

    //////////////////////////////
    // Basic Tests
    //////////////////////////////

    function test_vote_single_partial() public {
        _vote(voter1(), choice1(), SHARE_AMOUNT);

        assertEq(baalVotes().votes(choice1(), voter1()), SHARE_AMOUNT);
        assertEq(baalVotes().getTotalVotesForChoice(choice1()), SHARE_AMOUNT);

        assertEq(baalPoints().allocatedPoints(voter1()), SHARE_AMOUNT);

        assertEq(baalPoints().hasVotingPoints(voter1(), voteAmount - SHARE_AMOUNT, ""), true);
        assertEq(baalPoints().hasAllocatedPoints(voter1(), SHARE_AMOUNT, ""), true);
    }

    function test_vote_single_full() public {
        _vote(voter1(), choice1(), voteAmount);

        assertEq(baalVotes().votes(choice1(), voter1()), voteAmount);
        assertEq(baalVotes().getTotalVotesForChoice(choice1()), voteAmount);

        assertEq(baalPoints().allocatedPoints(voter1()), voteAmount);

        assertEq(baalPoints().hasVotingPoints(voter1(), 1, ""), false);
        assertEq(baalPoints().hasAllocatedPoints(voter1(), voteAmount, ""), true);
    }

    function test_vote_single_full_many() public {
        _vote(voter1(), choice1(), voteAmount / 3);
        _vote(voter1(), choice1(), voteAmount / 3);
        _vote(voter1(), choice1(), voteAmount / 3);

        assertEq(baalVotes().votes(choice1(), voter1()), voteAmount);
        assertEq(baalVotes().getTotalVotesForChoice(choice1()), voteAmount);

        assertEq(baalPoints().allocatedPoints(voter1()), voteAmount);

        assertEq(baalPoints().hasVotingPoints(voter1(), 1, ""), false);
        assertEq(baalPoints().hasAllocatedPoints(voter1(), voteAmount, ""), true);
    }

    function test_retract_single_partial() public {
        _vote(voter1(), choice1(), voteAmount);

        _retract(voter1(), choice1(), voteAmount / 2);

        assertEq(baalVotes().votes(choice1(), voter1()), voteAmount / 2);
        assertEq(baalVotes().getTotalVotesForChoice(choice1()), voteAmount / 2);

        assertEq(baalPoints().allocatedPoints(voter1()), voteAmount / 2);

        assertEq(baalPoints().hasVotingPoints(voter1(), voteAmount / 2, ""), true);
        assertEq(baalPoints().hasAllocatedPoints(voter1(), voteAmount / 2, ""), true);

        assertEq(baalPoints().hasVotingPoints(voter1(), voteAmount / 2 + 1, ""), false);
        assertEq(baalPoints().hasAllocatedPoints(voter1(), voteAmount / 2 + 1, ""), false);
    }

    function test_retract_single_full() public {
        _vote(voter1(), choice1(), voteAmount);

        _retract(voter1(), choice1(), voteAmount);

        assertEq(baalVotes().votes(choice1(), voter1()), 0);
        assertEq(baalVotes().getTotalVotesForChoice(choice1()), 0);

        assertEq(baalPoints().allocatedPoints(voter1()), 0);

        assertEq(baalPoints().hasVotingPoints(voter1(), voteAmount, ""), true);
        assertEq(baalPoints().hasAllocatedPoints(voter1(), 1, ""), false);
    }

    function test_change_single_partial() public {
        _vote(voter1(), choice1(), voteAmount / 4);
        _vote(voter1(), choice2(), voteAmount / 4 * 3);

        _change(voter1(), choice1(), choice2(), voteAmount / 4);

        assertEq(baalVotes().votes(choice1(), voter1()), 0);
        assertEq(baalVotes().votes(choice2(), voter1()), voteAmount);
    }

    function test_change_single_new() public {
        _vote(voter1(), choice1(), voteAmount / 2);
        _vote(voter1(), choice2(), voteAmount / 2);

        _change(voter1(), choice2(), choice3(), voteAmount / 4);

        assertEq(baalVotes().votes(choice1(), voter1()), voteAmount / 2);
        assertEq(baalVotes().votes(choice2(), voter1()), voteAmount / 4);
        assertEq(baalVotes().votes(choice3(), voter1()), voteAmount / 4);
    }

    function test_change_spread() public {
        _vote(voter1(), choice1(), voteAmount);

        _change(voter1(), choice1(), choice2(), voteAmount / 3);
        _change(voter1(), choice1(), choice3(), voteAmount / 3);

        assertEq(baalVotes().votes(choice1(), voter1()), voteAmount / 3);
        assertEq(baalVotes().votes(choice2(), voter1()), voteAmount / 3);
        assertEq(baalVotes().votes(choice3(), voter1()), voteAmount / 3);
    }

    function test_batch_vote_equal() public {
        _batchVote(voter1(), _allThreeChoices, _equalSplit, voteAmount);

        assertEq(baalVotes().votes(choice1(), voter1()), voteAmount / 3);
        assertEq(baalVotes().votes(choice2(), voter1()), voteAmount / 3);
        assertEq(baalVotes().votes(choice3(), voter1()), voteAmount / 3);
    }

    function test_batch_vote_skewed() public {
        _batchVote(voter1(), _allThreeChoices, _favorsChoice1, voteAmount);

        assertEq(baalVotes().votes(choice1(), voter1()), voteAmount / 2);
        assertEq(baalVotes().votes(choice2(), voter1()), voteAmount / 4);
        assertEq(baalVotes().votes(choice3(), voter1()), voteAmount / 4);
    }

    function test_batch_vote_concert() public {
        _batchVote(voter1(), _allThreeChoices, _favorsChoice1, voteAmount);
        _batchVote(voter2(), _allThreeChoices, _favorsChoice2, voteAmount);
        _batchVote(voter3(), _allThreeChoices, _equalSplit, voteAmount);

        assertEq(baalVotes().votes(choice1(), voter1()), voteAmount / 2);
        assertEq(baalVotes().votes(choice2(), voter1()), voteAmount / 4);
        assertEq(baalVotes().votes(choice3(), voter1()), voteAmount / 4);

        assertEq(baalVotes().votes(choice1(), voter2()), voteAmount / 4);
        assertEq(baalVotes().votes(choice2(), voter2()), voteAmount / 2);
        assertEq(baalVotes().votes(choice3(), voter2()), voteAmount / 4);

        assertEq(baalVotes().votes(choice1(), voter3()), voteAmount / 3);
        assertEq(baalVotes().votes(choice2(), voter3()), voteAmount / 3);
        assertEq(baalVotes().votes(choice3(), voter3()), voteAmount / 3);

        assertEq(baalVotes().getTotalVotesForChoice(choice1()), voteAmount / 2 + voteAmount / 4 + voteAmount / 3);
        assertEq(baalVotes().getTotalVotesForChoice(choice2()), voteAmount / 4 + voteAmount / 2 + voteAmount / 3);
        assertEq(baalVotes().getTotalVotesForChoice(choice3()), voteAmount / 4 + voteAmount / 4 + voteAmount / 3);
    }

    function test_batch_retract_equal() public {
        _batchVote(voter1(), _allThreeChoices, _equalSplit, voteAmount);

        assertEq(baalVotes().votes(choice1(), voter1()), voteAmount / 3);
        assertEq(baalVotes().votes(choice2(), voter1()), voteAmount / 3);
        assertEq(baalVotes().votes(choice3(), voter1()), voteAmount / 3);

        _batchRetract(voter1(), _allThreeChoices, _equalSplit, voteAmount);

        assertEq(baalVotes().votes(choice1(), voter1()), 0);
        assertEq(baalVotes().votes(choice2(), voter1()), 0);
        assertEq(baalVotes().votes(choice3(), voter1()), 0);
    }

    function test_batch_retract_partial() public {
        _batchVote(voter1(), _allThreeChoices, _equalSplit, voteAmount);

        assertEq(baalVotes().votes(choice1(), voter1()), voteAmount / 3);
        assertEq(baalVotes().votes(choice2(), voter1()), voteAmount / 3);
        assertEq(baalVotes().votes(choice3(), voter1()), voteAmount / 3);

        _batchRetract(voter1(), _allThreeChoices, _equalPartial, voteAmount / 2);

        assertEq(baalVotes().votes(choice1(), voter1()), voteAmount / 6);
        assertEq(baalVotes().votes(choice2(), voter1()), voteAmount / 6);
        assertEq(baalVotes().votes(choice3(), voter1()), voteAmount / 6);
    }

    function test_batch_retract_skewed() public {
        _batchVote(voter1(), _allThreeChoices, _equalSplit, voteAmount);

        assertEq(baalVotes().votes(choice1(), voter1()), voteAmount / 3);
        assertEq(baalVotes().votes(choice2(), voter1()), voteAmount / 3);
        assertEq(baalVotes().votes(choice3(), voter1()), voteAmount / 3);

        uint256[] memory _skewedPartial = new uint256[](3);

        _skewedPartial[0] = voteAmount / 3;
        _skewedPartial[1] = voteAmount / 6;
        _skewedPartial[2] = voteAmount / 6;

        _batchRetract(voter1(), _allThreeChoices, _skewedPartial, voteAmount / 3 * 2);

        assertEq(baalVotes().votes(choice1(), voter1()), 0);
        assertEq(baalVotes().votes(choice2(), voter1()), voteAmount / 6);
        assertEq(baalVotes().votes(choice3(), voter1()), voteAmount / 6);
    }

    function test_batchChange_consolidate() public {
        _batchVote(voter1(), _allThreeChoices, _equalSplit, voteAmount);

        assertEq(baalVotes().votes(choice1(), voter1()), voteAmount / 3);
        assertEq(baalVotes().votes(choice2(), voter1()), voteAmount / 3);
        assertEq(baalVotes().votes(choice3(), voter1()), voteAmount / 3);

        bytes32[][2] memory _choiceIds;
        uint256[][2] memory _amounts;
        bytes[][2] memory _data;
        uint256[2] memory _totals;

        bytes32[] memory _retractChoices = new bytes32[](2);
        bytes32[] memory _addChoices = new bytes32[](1);

        uint256[] memory _retractAmounts = new uint256[](2);
        uint256[] memory _addAmounts = new uint256[](1);

        bytes[] memory _retractBytes = new bytes[](2);
        bytes[] memory _addBytes = new bytes[](1);

        _retractChoices[0] = choice1();
        _retractChoices[1] = choice2();
        _addChoices[0] = choice3();

        _retractAmounts[0] = voteAmount / 3;
        _retractAmounts[1] = voteAmount / 3;
        _addAmounts[0] = voteAmount / 3 * 2;

        _retractBytes[0] = abi.encode(_mockMetadata);
        _retractBytes[1] = abi.encode(_mockMetadata);
        _addBytes[0] = abi.encode(_mockMetadata);

        _choiceIds[0] = _retractChoices;
        _choiceIds[1] = _addChoices;

        _amounts[0] = _retractAmounts;
        _amounts[1] = _addAmounts;

        _data[0] = _retractBytes;
        _data[1] = _addBytes;

        _totals[0] = voteAmount / 3 * 2;
        _totals[1] = voteAmount / 3 * 2;

        _batchChangeVote(voter1(), _choiceIds, _amounts, _data, _totals);

        assertEq(baalVotes().votes(choice1(), voter1()), 0);
        assertEq(baalVotes().votes(choice2(), voter1()), 0);
        assertEq(baalVotes().votes(choice3(), voter1()), voteAmount);
    }

    function test_batchChange_spread() public {
        _vote(voter1(), choice1(), voteAmount);

        assertEq(baalVotes().votes(choice1(), voter1()), voteAmount);

        bytes32[][2] memory _choiceIds;
        uint256[][2] memory _amounts;
        bytes[][2] memory _data;
        uint256[2] memory _totals;

        bytes32[] memory _retractChoices = new bytes32[](1);
        bytes32[] memory _addChoices = new bytes32[](3);

        uint256[] memory _retractAmounts = new uint256[](1);
        uint256[] memory _addAmounts = new uint256[](3);

        bytes[] memory _retractBytes = new bytes[](1);
        bytes[] memory _addBytes = new bytes[](3);

        _retractChoices[0] = choice1();
        _addChoices[0] = choice1();
        _addChoices[1] = choice2();
        _addChoices[2] = choice3();

        _retractAmounts[0] = voteAmount;
        _addAmounts[0] = voteAmount / 3;
        _addAmounts[1] = voteAmount / 3;
        _addAmounts[2] = voteAmount / 3;

        _retractBytes[0] = abi.encode(_mockMetadata);
        _addBytes[0] = abi.encode(_mockMetadata);
        _addBytes[1] = abi.encode(_mockMetadata);
        _addBytes[2] = abi.encode(_mockMetadata);

        _choiceIds[0] = _retractChoices;
        _choiceIds[1] = _addChoices;

        _amounts[0] = _retractAmounts;
        _amounts[1] = _addAmounts;

        _data[0] = _retractBytes;
        _data[1] = _addBytes;

        _totals[0] = voteAmount;
        _totals[1] = voteAmount;

        _batchChangeVote(voter1(), _choiceIds, _amounts, _data, _totals);

        assertEq(baalVotes().votes(choice1(), voter1()), voteAmount / 3);
        assertEq(baalVotes().votes(choice2(), voter1()), voteAmount / 3);
        assertEq(baalVotes().votes(choice3(), voter1()), voteAmount / 3);
    }

    function testFinalize() public {
        _vote(voter1(), choice1(), voteAmount);
        _vote(voter2(), choice2(), voteAmount);
        _vote(voter3(), choice3(), voteAmount);

        _retract(voter1(), choice1(), voteAmount);

        _change(voter2(), choice2(), choice3(), voteAmount);

        vm.warp(block.timestamp + TWO_WEEKS + 1);
        baalVotes().finalizeVoting();

        assertEq(uint8(contest().contestStatus()), uint8(ContestStatus.Finalized));
    }

    //////////////////////////////
    // Reverts
    //////////////////////////////

    function testRevert_voteModule_alreadyStarted() public {
        vm.expectRevert("Voting has already started");

        vm.startPrank(voter1());
        baalVotes().setVotingTime(0);
        vm.stopPrank();
    }

    function testRevert_vote_onlyVotingPeriod() public {
        vm.warp(block.timestamp + TWO_WEEKS + 1);
        baalVotes().finalizeVoting();

        vm.expectRevert("Contest is not in voting state");

        vm.startPrank(voter1());
        contest().vote(choice1(), voteAmount, abi.encode(_mockMetadata));
        vm.stopPrank();
    }

    function testRevert_vote_onlyValidChoice() public {
        vm.expectRevert("Choice does not exist");

        vm.startPrank(voter1());
        contest().vote(choice4(), voteAmount, abi.encode(_mockMetadata));
        vm.stopPrank();
    }

    function testRevert_vote_overspend() public {
        vm.expectRevert("Insufficient points available");

        vm.startPrank(voter1());
        contest().vote(choice1(), voteAmount + 1, abi.encode(_mockMetadata));
        vm.stopPrank();
    }

    function testRevert_vote_overspend_many() public {
        vm.startPrank(voter1());
        contest().vote(choice1(), voteAmount, abi.encode(_mockMetadata));
        vm.expectRevert("Insufficient points available");
        contest().vote(choice1(), 1, abi.encode(_mockMetadata));
        vm.stopPrank();
    }

    function testRevert_vote_noPoints() public {
        vm.expectRevert("Insufficient points available");

        vm.startPrank(someGuy());
        contest().vote(choice1(), 1, abi.encode(_mockMetadata));
        vm.stopPrank();
    }

    function testRevert_vote_nonZero() public {
        vm.expectRevert("Amount must be greater than 0");

        vm.startPrank(voter1());
        contest().vote(choice1(), 0, abi.encode(_mockMetadata));
        vm.stopPrank();
    }

    function testRevert_retract_onlyVotingPeriod() public {
        _vote(voter1(), choice1(), voteAmount);

        vm.warp(block.timestamp + TWO_WEEKS + 1);
        baalVotes().finalizeVoting();

        vm.expectRevert("Contest is not in voting state");

        vm.startPrank(voter1());
        contest().retractVote(choice1(), voteAmount, abi.encode(_mockMetadata));
        vm.stopPrank();
    }

    function testRevert_retract_onlyValidChoice() public {
        vm.expectRevert("Choice does not exist");

        vm.startPrank(voter1());
        contest().retractVote(choice4(), voteAmount, abi.encode(_mockMetadata));
        vm.stopPrank();
    }

    function testRevert_retract_overspend() public {
        _vote(voter1(), choice1(), voteAmount);

        vm.expectRevert("Insufficient points allocated");

        vm.startPrank(voter1());
        contest().retractVote(choice1(), voteAmount + 1, abi.encode(_mockMetadata));
        vm.stopPrank();
    }

    function testRevert_retract_overspend_many() public {
        _vote(voter1(), choice1(), voteAmount);

        vm.startPrank(voter1());
        contest().retractVote(choice1(), voteAmount, abi.encode(_mockMetadata));
        vm.expectRevert("Insufficient points allocated");
        contest().retractVote(choice1(), 1, abi.encode(_mockMetadata));
        vm.stopPrank();
    }

    function testRevert_retract_noPoints() public {
        vm.expectRevert("Insufficient points allocated");

        vm.startPrank(someGuy());
        contest().retractVote(choice1(), 1, abi.encode(_mockMetadata));
        vm.stopPrank();
    }

    function testRevert_retractVote_nonZero() public {
        _vote(voter1(), choice1(), voteAmount);

        vm.expectRevert("Amount must be greater than 0");

        vm.startPrank(voter1());
        contest().retractVote(choice1(), 0, abi.encode(_mockMetadata));
        vm.stopPrank();
    }

    function testRevert_batchVote_onlyVotingPeriod() public {
        vm.warp(block.timestamp + TWO_WEEKS + 1);
        baalVotes().finalizeVoting();

        vm.expectRevert("Contest is not in voting state");

        vm.startPrank(voter1());
        contest().batchVote(_allThreeChoices, _equalSplit, _batchData, voteAmount, _mockMetadata);
        vm.stopPrank();
    }

    function testRevert_batchVote_invalidInputLength() public {
        bytes[] memory _data = new bytes[](2);

        _data[0] = "";
        _data[1] = "";

        vm.expectRevert("Array mismatch: Invalid input length");

        vm.startPrank(voter1());
        contest().batchVote(_allThreeChoices, _equalSplit, _data, voteAmount, _mockMetadata);
        vm.stopPrank();

        bytes32[] memory _choices = new bytes32[](2);

        _choices[0] = choice1();
        _choices[1] = choice2();

        vm.expectRevert("Array mismatch: Invalid input length");

        vm.startPrank(voter1());
        contest().batchVote(_choices, _equalSplit, _batchData, voteAmount, _mockMetadata);
        vm.stopPrank();

        uint256[] memory _amounts = new uint256[](2);

        _amounts[0] = 1;
        _amounts[1] = 1;

        vm.expectRevert("Array mismatch: Invalid input length");

        vm.startPrank(voter1());
        contest().batchVote(_allThreeChoices, _amounts, _batchData, voteAmount, _mockMetadata);
        vm.stopPrank();
    }

    function testRevert_batchVote_overspend() public {
        uint256[] memory _overspendAmounts = new uint256[](3);

        _overspendAmounts[0] = voteAmount / 3 + 1;
        _overspendAmounts[1] = voteAmount / 3;
        _overspendAmounts[2] = voteAmount / 3;

        vm.expectRevert("Insufficient points available");

        vm.startPrank(voter1());
        contest().batchVote(_allThreeChoices, _overspendAmounts, _batchData, voteAmount, _mockMetadata);
        vm.stopPrank();

        _overspendAmounts[0] = voteAmount / 3;
        _overspendAmounts[1] = voteAmount / 3 + 1;
        _overspendAmounts[2] = voteAmount / 3;

        vm.expectRevert("Insufficient points available");

        vm.startPrank(voter1());
        contest().batchVote(_allThreeChoices, _overspendAmounts, _batchData, voteAmount, _mockMetadata);
        vm.stopPrank();

        _overspendAmounts[0] = voteAmount / 3;
        _overspendAmounts[1] = voteAmount / 3;
        _overspendAmounts[2] = voteAmount / 3 + 1;

        vm.expectRevert("Insufficient points available");

        vm.startPrank(voter1());
        contest().batchVote(_allThreeChoices, _overspendAmounts, _batchData, voteAmount, _mockMetadata);
        vm.stopPrank();
    }

    function testRevert_batchVote_nonExistentChoice() public {
        bytes32[] memory invalidChoices = new bytes32[](3);
        invalidChoices[0] = choice1();
        invalidChoices[1] = choice2();
        invalidChoices[2] = choice4();

        vm.expectRevert("Choice does not exist");
        vm.startPrank(voter1());
        contest().batchVote(invalidChoices, _equalSplit, _batchData, voteAmount, _mockMetadata);
        vm.stopPrank();
    }

    function testRevert_batchVote_invalidTotal() public {
        vm.expectRevert("Invalid total amount");
        vm.startPrank(voter1());
        contest().batchVote(_allThreeChoices, _equalSplit, _batchData, voteAmount + 1, _mockMetadata);
        vm.stopPrank();
    }

    function testRevert_batchRetract_onlyVotingPeriod() public {
        vm.warp(block.timestamp + TWO_WEEKS + 1);
        baalVotes().finalizeVoting();

        vm.expectRevert("Contest is not in voting state");

        vm.startPrank(voter1());
        contest().batchRetractVote(_allThreeChoices, _equalSplit, _batchData, voteAmount, _mockMetadata);
        vm.stopPrank();
    }

    function testRevert_batchRetract_invalidInputLength() public {
        bytes[] memory _data = new bytes[](2);

        _data[0] = "";
        _data[1] = "";

        vm.expectRevert("Array mismatch: Invalid input length");

        vm.startPrank(voter1());
        contest().batchRetractVote(_allThreeChoices, _equalSplit, _data, voteAmount, _mockMetadata);
        vm.stopPrank();

        bytes32[] memory _choices = new bytes32[](2);

        _choices[0] = choice1();
        _choices[1] = choice2();

        vm.expectRevert("Array mismatch: Invalid input length");

        vm.startPrank(voter1());
        contest().batchRetractVote(_choices, _equalSplit, _batchData, voteAmount, _mockMetadata);
        vm.stopPrank();

        uint256[] memory _amounts = new uint256[](2);

        _amounts[0] = 1;
        _amounts[1] = 1;

        vm.expectRevert("Array mismatch: Invalid input length");

        vm.startPrank(voter1());
        contest().batchRetractVote(_allThreeChoices, _amounts, _batchData, voteAmount, _mockMetadata);
        vm.stopPrank();
    }

    function testRevert_batchRetractVote_overspend() public {
        _batchVote(voter1(), _allThreeChoices, _equalSplit, voteAmount);

        uint256[] memory _overspendAmounts = new uint256[](3);

        _overspendAmounts[0] = voteAmount / 3 + 1;
        _overspendAmounts[1] = voteAmount / 3;
        _overspendAmounts[2] = voteAmount / 3;

        vm.expectRevert("Retracted amount exceeds vote amount");

        vm.startPrank(voter1());
        contest().batchRetractVote(_allThreeChoices, _overspendAmounts, _batchData, voteAmount, _mockMetadata);
        vm.stopPrank();

        _overspendAmounts[0] = voteAmount / 3;
        _overspendAmounts[1] = voteAmount / 3 + 1;
        _overspendAmounts[2] = voteAmount / 3;

        vm.expectRevert("Retracted amount exceeds vote amount");

        vm.startPrank(voter1());
        contest().batchRetractVote(_allThreeChoices, _overspendAmounts, _batchData, voteAmount, _mockMetadata);
        vm.stopPrank();

        _overspendAmounts[0] = voteAmount / 3;
        _overspendAmounts[1] = voteAmount / 3;
        _overspendAmounts[2] = voteAmount / 3 + 1;

        vm.expectRevert("Insufficient points allocated");

        vm.startPrank(voter1());
        contest().batchRetractVote(_allThreeChoices, _overspendAmounts, _batchData, voteAmount, _mockMetadata);
        vm.stopPrank();
    }

    function testRevert_batchRetractVote_nonExistentChoice() public {
        _batchVote(voter1(), _allThreeChoices, _equalSplit, voteAmount);

        bytes32[] memory invalidChoices = new bytes32[](3);
        invalidChoices[0] = choice1();
        invalidChoices[1] = choice2();
        invalidChoices[2] = choice4();

        vm.expectRevert("Choice does not exist");
        vm.startPrank(voter1());
        contest().batchRetractVote(invalidChoices, _equalSplit, _batchData, voteAmount, _mockMetadata);
        vm.stopPrank();
    }

    function testRevert_batchRetractVote_invalidTotal() public {
        _batchVote(voter1(), _allThreeChoices, _equalSplit, voteAmount);

        vm.expectRevert("Invalid total amount");
        vm.startPrank(voter1());
        contest().batchRetractVote(_allThreeChoices, _equalSplit, _batchData, voteAmount + 1, _mockMetadata);
        vm.stopPrank();
    }

    //////////////////////////////
    // Adversarial
    //////////////////////////////

    function testAttack_mintMoreShares() public {
        // user votes and uses all of their points
        _batchVote(voter1(), _allThreeChoices, _equalSplit, voteAmount);

        uint256[] memory _mintAmounts = new uint256[](1);
        address[] memory _mintAddresses = new address[](1);

        _mintAmounts[0] = voteAmount;
        _mintAddresses[0] = voter1();

        // proposal passes and user gets more shares
        vm.startPrank(dao().avatar());
        dao().mintShares(_mintAddresses, _mintAmounts);
        vm.stopPrank();

        vm.expectRevert("Insufficient points available");

        // user tries to vote again, but get gets caught by the snapshot check
        vm.startPrank(voter1());
        contest().vote(choice1(), voteAmount, abi.encode(_mockMetadata));
        vm.stopPrank();
    }

    function testAttack_batchChange_misrepresentTotals() public {
        _batchVote(voter1(), _allThreeChoices, _equalSplit, voteAmount);

        bytes32[][2] memory _choiceIds;
        uint256[][2] memory _amounts;
        bytes[][2] memory _data;
        uint256[2] memory _totals;

        bytes32[] memory _retractChoices = new bytes32[](3);
        bytes32[] memory _addChoices = new bytes32[](3);

        uint256[] memory _retractAmounts = new uint256[](3);
        uint256[] memory _addAmounts = new uint256[](3);

        bytes[] memory _retractBytes = new bytes[](3);
        bytes[] memory _addBytes = new bytes[](3);

        _retractChoices[0] = choice1();
        _retractChoices[1] = choice2();
        _retractChoices[2] = choice3();

        _addChoices[0] = choice1();
        _addChoices[1] = choice2();
        _addChoices[2] = choice3();

        // removes less vote power
        _retractAmounts[0] = voteAmount / 6;
        _retractAmounts[1] = voteAmount / 6;
        _retractAmounts[2] = voteAmount / 6;

        // adds more vote power than removed
        _addAmounts[0] = voteAmount / 3;
        _addAmounts[1] = voteAmount / 3;
        _addAmounts[2] = voteAmount / 3;

        _retractBytes[0] = abi.encode(_mockMetadata);
        _retractBytes[1] = abi.encode(_mockMetadata);
        _retractBytes[2] = abi.encode(_mockMetadata);

        _addBytes[0] = abi.encode(_mockMetadata);
        _addBytes[1] = abi.encode(_mockMetadata);
        _addBytes[2] = abi.encode(_mockMetadata);

        _choiceIds[0] = _retractChoices;
        _choiceIds[1] = _addChoices;

        _amounts[0] = _retractAmounts;
        _amounts[1] = _addAmounts;

        _data[0] = _retractBytes;
        _data[1] = _addBytes;

        _totals[0] = voteAmount;
        _totals[1] = voteAmount;

        vm.expectRevert("Invalid total amount");

        _batchChangeVote(voter1(), _choiceIds, _amounts, _data, _totals);
    }

    function testAttack_shiftBatchRetract() public {
        // this is an attempt to retract more votes from a choice than I have allocated to

        _batchVote(voter1(), _allThreeChoices, _equalSplit, voteAmount);

        uint256[] memory _sneakyAmounts = new uint256[](3);
        _sneakyAmounts[0] = voteAmount / 3 - 1;
        _sneakyAmounts[1] = voteAmount / 3;
        _sneakyAmounts[2] = voteAmount / 3 + 1;

        vm.expectRevert("Retracted amount exceeds vote amount");

        vm.startPrank(voter1());
        contest().batchRetractVote(_allThreeChoices, _sneakyAmounts, _batchData, voteAmount, _mockMetadata);
        vm.stopPrank();
    }

    //////////////////////////////
    // Helpers
    //////////////////////////////

    function _batchChangeVote(
        address _voter,
        bytes32[][2] memory _choiceIds,
        uint256[][2] memory _amounts,
        bytes[][2] memory _data,
        uint256[2] memory _totals
    ) internal {
        Metadata[2] memory _metadata;

        _metadata[0] = emptyMetadata;
        _metadata[1] = emptyMetadata;

        vm.startPrank(_voter);
        contest().batchChangeVote(_choiceIds, _amounts, _data, _totals, _metadata);
        vm.stopPrank();
    }

    function _batchRetract(address _voter, bytes32[] memory _choices, uint256[] memory _amounts, uint256 _totalAmount)
        internal
    {
        vm.startPrank(_voter);
        contest().batchRetractVote(_choices, _amounts, _batchData, _totalAmount, emptyMetadata);
        vm.stopPrank();
    }

    function _batchVote(address _voter, bytes32[] memory _choices, uint256[] memory _amounts, uint256 _totalAmount)
        internal
    {
        vm.startPrank(_voter);
        contest().batchVote(_choices, _amounts, _batchData, _totalAmount, emptyMetadata);
        vm.stopPrank();
    }

    function _change(address _voter, bytes32 _oldChoice, bytes32 _newChoice, uint256 _amount) public {
        vm.startPrank(_voter);
        contest().changeVote(_oldChoice, _newChoice, _amount, abi.encode(_mockMetadata));
        vm.stopPrank();
    }

    function _vote(address _voter, bytes32 _choice, uint256 _amount) public {
        vm.startPrank(_voter);
        contest().vote(_choice, _amount, abi.encode(_mockMetadata));
        vm.stopPrank();
    }

    function _retract(address _voter, bytes32 _choice, uint256 _amount) public {
        vm.startPrank(_voter);
        contest().retractVote(_choice, _amount, abi.encode(_mockMetadata));
        vm.stopPrank();
    }
}
