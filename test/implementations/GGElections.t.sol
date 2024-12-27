// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console} from "forge-std/Test.sol";
import {GGSetup} from "../setup/GGSetup.t.sol";
import {Metadata} from "../../src/core/Metadata.sol";
import {ContestStatus} from "../../src/core/ContestStatus.sol";
import {BasicChoice} from "../../src/core/Choice.sol";
import {TimerType} from "../../src/modules/votes/utils/VoteTimer.sol";

contract GGElections is GGSetup {
    bytes32[] _allFiveChoices;
    uint256[] _equalSplit;
    uint256[] _equalPartial;
    uint256[] _favorsChoice1;
    uint256[] _favorsChoice2;
    bytes[] _voteData;

    Metadata emptyMetadata;

    Metadata metadata = Metadata(1, "QmWmyoMoctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWeVdD");
    Metadata metadata2 = Metadata(2, "QmBa4oMoctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWe2zF");
    Metadata metadata3 = Metadata(3, "QmHi23fctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWzt32");
    Metadata metadata4 = Metadata(4, "QmWmyoMoctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWeVdD");
    Metadata metadata5 = Metadata(5, "QmBa4oMoctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWe2zF");

    Metadata[] metadatas;

    bytes choiceData = "choice1";
    bytes choiceData2 = "choice2";
    bytes choiceData3 = "choice3";
    bytes choiceData4 = "choice4";
    bytes choiceData5 = "choice5";

    function setUp() public {
        __deployGGElections();

        _allFiveChoices.push(choice1());
        _allFiveChoices.push(choice2());
        _allFiveChoices.push(choice3());
        _allFiveChoices.push(choice4());
        _allFiveChoices.push(choice5());

        _equalSplit.push(VOTE_AMOUNT / 5);
        _equalSplit.push(VOTE_AMOUNT / 5);
        _equalSplit.push(VOTE_AMOUNT / 5);
        _equalSplit.push(VOTE_AMOUNT / 5);
        _equalSplit.push(VOTE_AMOUNT / 5);

        _equalPartial.push(VOTE_AMOUNT / 10);
        _equalPartial.push(VOTE_AMOUNT / 10);
        _equalPartial.push(VOTE_AMOUNT / 10);
        _equalPartial.push(VOTE_AMOUNT / 10);
        _equalPartial.push(VOTE_AMOUNT / 10);

        _favorsChoice1.push(VOTE_AMOUNT / 2);
        _favorsChoice1.push(VOTE_AMOUNT / 8);
        _favorsChoice1.push(VOTE_AMOUNT / 8);
        _favorsChoice1.push(VOTE_AMOUNT / 8);
        _favorsChoice1.push(VOTE_AMOUNT / 8);

        _favorsChoice2.push(VOTE_AMOUNT / 8);
        _favorsChoice2.push(VOTE_AMOUNT / 2);
        _favorsChoice2.push(VOTE_AMOUNT / 8);
        _favorsChoice2.push(VOTE_AMOUNT / 8);
        _favorsChoice2.push(VOTE_AMOUNT / 8);

        bytes memory votesData = abi.encode(emptyMetadata);

        bytes memory pointsData1 = abi.encode(voterProof(0), VOTE_AMOUNT);
        bytes memory pointsData2 = abi.encode(voterProof(1), VOTE_AMOUNT);
        bytes memory pointsData3 = abi.encode(voterProof(2), VOTE_AMOUNT);
        bytes memory pointsData4 = abi.encode(voterProof(3), VOTE_AMOUNT);
        bytes memory pointsData5 = abi.encode(voterProof(4), VOTE_AMOUNT);

        _voteData.push(abi.encode(votesData, pointsData1));
        _voteData.push(abi.encode(votesData, pointsData2));
        _voteData.push(abi.encode(votesData, pointsData3));
        _voteData.push(abi.encode(votesData, pointsData4));
        _voteData.push(abi.encode(votesData, pointsData5));

        metadatas.push(metadata);
        metadatas.push(metadata2);
        metadatas.push(metadata3);
        metadatas.push(metadata4);
        metadatas.push(metadata5);
    }

    //////////////////////////////
    // Init
    //////////////////////////////
    function test_init() public view {
        assertEq(uint8(contest().contestStatus()), uint8(ContestStatus.Populating));

        assertTrue(contest().isRetractable());
        assertFalse(contest().isContinuous());

        assertEq(address(contest().votesModule()), address(timedVotes()));
        assertEq(address(contest().choicesModule()), address(openChoices()));
        assertEq(address(contest().pointsModule()), address(merklePoints()));
        assertEq(address(contest().executionModule()), address(hatterExecution()));

        // votes params

        assertEq(timedVotes().duration(), TWO_WEEKS);
        assertEq(address(timedVotes().contest()), address(contest()));
        assertEq(timedVotes().startTime(), block.timestamp);
        assertEq(timedVotes().endTime(), block.timestamp + TWO_WEEKS);
        assertEq(timedVotes().adminHatId(), adminHatId);
        assertEq(uint8(timedVotes().timerType()), uint8(TimerType.Auto));

        // choices params

        assertEq(address(openChoices().contest()), address(contest()));
        assertEq(openChoices().adminHatId(), adminHatId);
        assertEq(openChoices().canNominate(), true);
        assertFalse(openChoices().lockSubmissions());
        assertEq(address(openChoices().hats()), address(hats));

        // points params

        assertEq(merklePoints().contest(), address(contest()));
        assertEq(merklePoints().merkleRoot(), merkleRoot);

        // execution params

        assertEq(address(hatterExecution().contest()), address(contest()));
        assertEq(hatterExecution().adminHatId(), adminHatId);
        assertEq(hatterExecution().winnerHatId(), judgeHatId);
        assertEq(hatterExecution().winnerAmt(), 3);
    }

    //////////////////////////////
    // Basic Tests
    //////////////////////////////

    function test_registerChoice() public {
        _registerChoice(voter1(), choice1(), choiceData, metadata);

        BasicChoice memory choice = openChoices().getChoice(choice1());

        assertEq(choice.metadata.protocol, metadata.protocol);
        assertEq(choice.metadata.pointer, metadata.pointer);
        assertEq(choice.data, choiceData);
        assertEq(choice.registrar, voter1());
        assertEq(choice.exists, true);
    }

    function test_registerChoice_many() public {
        _registerChoice(voter1(), choice1(), choiceData, metadata);
        _registerChoice(voter2(), choice2(), choiceData2, metadata2);
        _registerChoice(voter3(), choice3(), choiceData3, metadata3);
        _registerChoice(voter4(), choice4(), choiceData4, metadata4);
        _registerChoice(voter5(), choice5(), choiceData5, metadata5);
    }

    function test_retract() public {
        _registerChoice(voter1(), choice1(), choiceData, metadata);

        BasicChoice memory choice = openChoices().getChoice(choice1());

        assertEq(choice.metadata.protocol, metadata.protocol);
        assertEq(choice.metadata.pointer, metadata.pointer);
        assertEq(choice.data, choiceData);
        assertEq(choice.registrar, voter1());
        assertEq(choice.exists, true);

        _removeChoice(choice1());

        choice = openChoices().getChoice(choice1());

        assertEq(choice.metadata.protocol, metadata.protocol);
        assertEq(choice.metadata.pointer, metadata.pointer);
        assertEq(choice.data, choiceData);
        assertEq(choice.registrar, voter1());
        assertEq(choice.exists, false);
    }

    function test_vote_partial() public {
        _voteReady();
        _vote(0, choice1(), VOTE_AMOUNT / 2);

        assertEq(timedVotes().votes(choice1(), voter(0)), VOTE_AMOUNT / 2);
        assertEq(timedVotes().getTotalVotesForChoice(choice1()), VOTE_AMOUNT / 2);

        assertEq(merklePoints().allocatedPoints(voter(0)), VOTE_AMOUNT / 2);

        assertEq(merklePoints().hasVotingPoints(voter(0), VOTE_AMOUNT / 2, voteData(0)), true);
        assertEq(merklePoints().hasAllocatedPoints(voter(0), VOTE_AMOUNT / 2, voteData(0)), true);
    }

    function test_vote_single_full() public {
        _voteReady();

        _vote(0, choice1(), VOTE_AMOUNT);

        assertEq(timedVotes().votes(choice1(), voter(0)), VOTE_AMOUNT);
        assertEq(timedVotes().getTotalVotesForChoice(choice1()), VOTE_AMOUNT);

        assertEq(merklePoints().allocatedPoints(voter(0)), VOTE_AMOUNT);

        assertEq(merklePoints().hasVotingPoints(voter(0), VOTE_AMOUNT, voteData(0)), false);
        assertEq(merklePoints().hasAllocatedPoints(voter(0), VOTE_AMOUNT, voteData(0)), true);
    }

    function test_vote_single_full_many() public {
        _voteReady();

        _vote(0, choice1(), VOTE_AMOUNT / 5);
        _vote(0, choice1(), VOTE_AMOUNT / 5);
        _vote(0, choice1(), VOTE_AMOUNT / 5);
        _vote(0, choice1(), VOTE_AMOUNT / 5);
        _vote(0, choice1(), VOTE_AMOUNT / 5);

        assertEq(timedVotes().votes(choice1(), voter(0)), VOTE_AMOUNT);
        assertEq(timedVotes().getTotalVotesForChoice(choice1()), VOTE_AMOUNT);

        assertEq(merklePoints().allocatedPoints(voter(0)), VOTE_AMOUNT);

        assertEq(merklePoints().hasVotingPoints(voter(0), 1, voteData(0)), false);
        assertEq(merklePoints().hasAllocatedPoints(voter(0), VOTE_AMOUNT, voteData(0)), true);
    }

    function test_retract_single_partial() public {
        _voteReady();

        _vote(0, choice1(), VOTE_AMOUNT);

        _retract(0, choice1(), VOTE_AMOUNT / 2);

        assertEq(timedVotes().votes(choice1(), voter(0)), VOTE_AMOUNT / 2);
        assertEq(timedVotes().getTotalVotesForChoice(choice1()), VOTE_AMOUNT / 2);

        assertEq(merklePoints().allocatedPoints(voter(0)), VOTE_AMOUNT / 2);

        assertEq(merklePoints().hasVotingPoints(voter(0), VOTE_AMOUNT / 2, voteData(0)), true);
        assertEq(merklePoints().hasAllocatedPoints(voter(0), VOTE_AMOUNT / 2, voteData(0)), true);

        assertEq(merklePoints().hasVotingPoints(voter(0), VOTE_AMOUNT / 2 + 1, voteData(0)), false);
        assertEq(merklePoints().hasAllocatedPoints(voter(0), VOTE_AMOUNT / 2 + 1, voteData(0)), false);
    }

    function test_retract_single_full() public {
        _voteReady();

        _vote(0, choice1(), VOTE_AMOUNT);

        _retract(0, choice1(), VOTE_AMOUNT);

        assertEq(timedVotes().votes(choice1(), voter(0)), 0);
        assertEq(timedVotes().getTotalVotesForChoice(choice1()), 0);

        assertEq(merklePoints().allocatedPoints(voter(0)), 0);

        assertEq(merklePoints().hasVotingPoints(voter(0), VOTE_AMOUNT, voteData(0)), true);
        assertEq(merklePoints().hasAllocatedPoints(voter(0), 1, voteData(0)), false);
    }

    function test_change_single_partial() public {
        _voteReady();

        _vote(0, choice1(), VOTE_AMOUNT / 4);
        _vote(0, choice2(), VOTE_AMOUNT / 4 * 3);

        _change(0, choice1(), choice2(), VOTE_AMOUNT / 4);

        assertEq(timedVotes().votes(choice1(), voter(0)), 0);
        assertEq(timedVotes().votes(choice2(), voter(0)), VOTE_AMOUNT);
    }

    function test_change_single_new() public {
        _voteReady();

        _vote(0, choice1(), VOTE_AMOUNT / 2);
        _vote(0, choice2(), VOTE_AMOUNT / 2);

        _change(0, choice2(), choice3(), VOTE_AMOUNT / 4);

        assertEq(timedVotes().votes(choice1(), voter(0)), VOTE_AMOUNT / 2);
        assertEq(timedVotes().votes(choice2(), voter(0)), VOTE_AMOUNT / 4);
        assertEq(timedVotes().votes(choice3(), voter(0)), VOTE_AMOUNT / 4);
    }

    function test_change_spread() public {
        _voteReady();

        _vote(0, choice1(), VOTE_AMOUNT);

        _change(0, choice1(), choice2(), VOTE_AMOUNT / 5);
        _change(0, choice1(), choice3(), VOTE_AMOUNT / 5);
        _change(0, choice1(), choice4(), VOTE_AMOUNT / 5);
        _change(0, choice1(), choice5(), VOTE_AMOUNT / 5);

        assertEq(timedVotes().votes(choice1(), voter(0)), VOTE_AMOUNT / 5);
        assertEq(timedVotes().votes(choice2(), voter(0)), VOTE_AMOUNT / 5);
        assertEq(timedVotes().votes(choice3(), voter(0)), VOTE_AMOUNT / 5);
        assertEq(timedVotes().votes(choice4(), voter(0)), VOTE_AMOUNT / 5);
        assertEq(timedVotes().votes(choice5(), voter(0)), VOTE_AMOUNT / 5);
    }

    function test_batch_vote_equal() public {
        _voteReady();

        _batchVote(0, _allFiveChoices, _equalSplit, VOTE_AMOUNT);

        assertEq(timedVotes().votes(choice1(), voter(0)), VOTE_AMOUNT / 5);
        assertEq(timedVotes().votes(choice2(), voter(0)), VOTE_AMOUNT / 5);
        assertEq(timedVotes().votes(choice3(), voter(0)), VOTE_AMOUNT / 5);
        assertEq(timedVotes().votes(choice4(), voter(0)), VOTE_AMOUNT / 5);
        assertEq(timedVotes().votes(choice5(), voter(0)), VOTE_AMOUNT / 5);
    }

    function test_batch_vote_skewed() public {
        _voteReady();

        _batchVote(0, _allFiveChoices, _favorsChoice1, VOTE_AMOUNT);

        assertEq(timedVotes().votes(choice1(), voter(0)), VOTE_AMOUNT / 2);
        assertEq(timedVotes().votes(choice2(), voter(0)), VOTE_AMOUNT / 8);
        assertEq(timedVotes().votes(choice3(), voter(0)), VOTE_AMOUNT / 8);
        assertEq(timedVotes().votes(choice4(), voter(0)), VOTE_AMOUNT / 8);
        assertEq(timedVotes().votes(choice5(), voter(0)), VOTE_AMOUNT / 8);
    }

    function test_batch_vote_concert() public {
        _voteReady();

        _batchVote(0, _allFiveChoices, _favorsChoice1, VOTE_AMOUNT);
        _batchVote(1, _allFiveChoices, _favorsChoice2, VOTE_AMOUNT);
        _batchVote(2, _allFiveChoices, _equalSplit, VOTE_AMOUNT);

        assertEq(timedVotes().votes(choice1(), voter(0)), VOTE_AMOUNT / 2);
        assertEq(timedVotes().votes(choice2(), voter(0)), VOTE_AMOUNT / 8);
        assertEq(timedVotes().votes(choice3(), voter(0)), VOTE_AMOUNT / 8);
        assertEq(timedVotes().votes(choice4(), voter(0)), VOTE_AMOUNT / 8);
        assertEq(timedVotes().votes(choice5(), voter(0)), VOTE_AMOUNT / 8);

        assertEq(timedVotes().votes(choice1(), voter(1)), VOTE_AMOUNT / 8);
        assertEq(timedVotes().votes(choice2(), voter(1)), VOTE_AMOUNT / 2);
        assertEq(timedVotes().votes(choice3(), voter(1)), VOTE_AMOUNT / 8);
        assertEq(timedVotes().votes(choice4(), voter(1)), VOTE_AMOUNT / 8);
        assertEq(timedVotes().votes(choice5(), voter(1)), VOTE_AMOUNT / 8);

        assertEq(timedVotes().votes(choice1(), voter(2)), VOTE_AMOUNT / 5);
        assertEq(timedVotes().votes(choice2(), voter(2)), VOTE_AMOUNT / 5);
        assertEq(timedVotes().votes(choice3(), voter(2)), VOTE_AMOUNT / 5);
        assertEq(timedVotes().votes(choice4(), voter(2)), VOTE_AMOUNT / 5);
        assertEq(timedVotes().votes(choice5(), voter(2)), VOTE_AMOUNT / 5);
    }

    function test_batch_retract_equal() public {
        _voteReady();

        _batchVote(0, _allFiveChoices, _equalSplit, VOTE_AMOUNT);

        assertEq(timedVotes().votes(choice1(), voter(0)), VOTE_AMOUNT / 5);
        assertEq(timedVotes().votes(choice2(), voter(0)), VOTE_AMOUNT / 5);
        assertEq(timedVotes().votes(choice3(), voter(0)), VOTE_AMOUNT / 5);
        assertEq(timedVotes().votes(choice4(), voter(0)), VOTE_AMOUNT / 5);
        assertEq(timedVotes().votes(choice5(), voter(0)), VOTE_AMOUNT / 5);

        _batchRetract(0, _allFiveChoices, _equalSplit, VOTE_AMOUNT);

        assertEq(timedVotes().votes(choice1(), voter(0)), 0);
        assertEq(timedVotes().votes(choice2(), voter(0)), 0);
        assertEq(timedVotes().votes(choice3(), voter(0)), 0);
        assertEq(timedVotes().votes(choice4(), voter(0)), 0);
        assertEq(timedVotes().votes(choice5(), voter(0)), 0);
    }

    function test_batch_retract_skewed() public {
        _voteReady();

        _batchVote(0, _allFiveChoices, _equalSplit, VOTE_AMOUNT);

        assertEq(timedVotes().votes(choice1(), voter(0)), VOTE_AMOUNT / 5);
        assertEq(timedVotes().votes(choice2(), voter(0)), VOTE_AMOUNT / 5);
        assertEq(timedVotes().votes(choice3(), voter(0)), VOTE_AMOUNT / 5);
        assertEq(timedVotes().votes(choice4(), voter(0)), VOTE_AMOUNT / 5);
        assertEq(timedVotes().votes(choice5(), voter(0)), VOTE_AMOUNT / 5);

        uint256[] memory _skewedPartial = new uint256[](5);

        _skewedPartial[0] = VOTE_AMOUNT / 5;
        _skewedPartial[1] = VOTE_AMOUNT / 10;
        _skewedPartial[2] = VOTE_AMOUNT / 10;
        _skewedPartial[3] = VOTE_AMOUNT / 10;
        _skewedPartial[4] = VOTE_AMOUNT / 10;

        _batchRetract(0, _allFiveChoices, _skewedPartial, VOTE_AMOUNT / 5 * 3);

        assertEq(timedVotes().votes(choice1(), voter(0)), 0);
        assertEq(timedVotes().votes(choice2(), voter(0)), VOTE_AMOUNT / 10);
        assertEq(timedVotes().votes(choice3(), voter(0)), VOTE_AMOUNT / 10);
        assertEq(timedVotes().votes(choice4(), voter(0)), VOTE_AMOUNT / 10);
        assertEq(timedVotes().votes(choice5(), voter(0)), VOTE_AMOUNT / 10);
    }
    //////////////////////////////
    // Helpers
    //////////////////////////////

    function _voteReady() public {
        _standardChoices();

        vm.prank(admin1());

        openChoices().finalizeChoices();
    }

    function _standardChoices() public {
        _registerChoice(voter1(), choice1(), choiceData, metadata);
        _registerChoice(voter2(), choice2(), choiceData2, metadata2);
        _registerChoice(voter3(), choice3(), choiceData3, metadata3);
        _registerChoice(voter4(), choice4(), choiceData4, metadata4);
        _registerChoice(voter5(), choice5(), choiceData5, metadata5);
    }

    function _registerChoice(address _registrar, bytes32 _choiceId, bytes memory _data, Metadata memory _metadata)
        public
    {
        vm.startPrank(_registrar);
        openChoices().registerChoice(_choiceId, abi.encode(_data, _metadata, _registrar));
        vm.stopPrank();
    }

    function _removeChoice(bytes32 _choiceId) public {
        vm.startPrank(admin1());
        openChoices().removeChoice(_choiceId, "");
        vm.stopPrank();
    }

    function _vote(uint256 _voter, bytes32 _choice, uint256 _amount) public {
        vm.startPrank(voter(_voter));

        contest().vote(_choice, _amount, voteData(_voter));

        vm.stopPrank();
    }

    function _retract(uint256 _voter, bytes32 _choice, uint256 _amount) public {
        vm.startPrank(voter(_voter));

        contest().retractVote(_choice, _amount, voteData(_voter));

        vm.stopPrank();
    }

    function _change(uint256 _voter, bytes32 _oldChoice, bytes32 _newChoice, uint256 _amount) public {
        vm.startPrank(voter(_voter));

        contest().changeVote(_oldChoice, _newChoice, _amount, voteData(_voter));
        vm.stopPrank();
    }

    function _batchVote(uint256 _voter, bytes32[] memory _choices, uint256[] memory _amounts, uint256 _totalAmount)
        internal
    {
        vm.startPrank(voter(_voter));

        bytes[] memory batchData = new bytes[](_choices.length);

        for (uint256 i = 0; i < _choices.length; i++) {
            batchData[i] = voteData(_voter);
        }

        contest().batchVote(_choices, _amounts, batchData, _totalAmount, metadatas[_voter]);
    }

    function _batchRetract(uint256 _voter, bytes32[] memory _choices, uint256[] memory _amounts, uint256 _totalAmount)
        internal
    {
        vm.startPrank(voter(_voter));

        bytes[] memory batchData = new bytes[](_choices.length);

        for (uint256 i = 0; i < _choices.length; i++) {
            batchData[i] = voteData(_voter);
        }

        contest().batchRetractVote(_choices, _amounts, batchData, _totalAmount, metadatas[_voter]);
    }

    function _batchChange(
        uint256 _voter,
        bytes32[][2] memory _choiceIds,
        uint256[][2] memory _amounts,
        uint256[2] memory _totals
    ) internal {
        vm.startPrank(voter(_voter));

        Metadata[2] memory _metadata;
        _metadata[0] = emptyMetadata;
        _metadata[1] = emptyMetadata;

        bytes[][2] memory _data;
        _data[0] = _voteData;
        _data[1] = _voteData;

        contest().batchChangeVote(_choiceIds, _amounts, _data, _totals, _metadata);
    }

    function voteData(uint256 _voter) public view returns (bytes memory) {
        return _voteData[_voter];
    }
}
