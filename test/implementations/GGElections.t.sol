// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console} from "forge-std/Test.sol";
import {GGSetup} from "../setup/GGSetup.t.sol";
import {Metadata} from "../../src/core/Metadata.sol";
import {ContestStatus} from "../../src/core/ContestStatus.sol";
import {BasicChoice} from "../../src/core/Choice.sol";
import {TimerType} from "../../src/modules/votes/utils/VoteTimer.sol";

contract GGElections is GGSetup {
    bytes32[] _allThreeChoices;
    uint256[] _equalSplit;
    uint256[] _equalPartial;
    uint256[] _favorsChoice1;
    uint256[] _favorsChoice2;
    bytes[] _batchData;

    Metadata emptyMetadata;

    Metadata metadata = Metadata(1, "QmWmyoMoctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWeVdD");
    Metadata metadata2 = Metadata(2, "QmBa4oMoctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWe2zF");
    Metadata metadata3 = Metadata(3, "QmHi23fctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWzt32");
    Metadata metadata4 = Metadata(4, "QmWmyoMoctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWeVdD");
    Metadata metadata5 = Metadata(5, "QmBa4oMoctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWe2zF");

    bytes choiceData = "choice1";
    bytes choiceData2 = "choice2";
    bytes choiceData3 = "choice3";
    bytes choiceData4 = "choice4";
    bytes choiceData5 = "choice5";

    function setUp() public {
        __deployGGElections();

        _allThreeChoices.push(choice1());
        _allThreeChoices.push(choice2());
        _allThreeChoices.push(choice3());

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

        _favorsChoice1.push(VOTE_AMOUNT / 8);
        _favorsChoice1.push(VOTE_AMOUNT / 2);
        _favorsChoice1.push(VOTE_AMOUNT / 8);
        _favorsChoice1.push(VOTE_AMOUNT / 8);
        _favorsChoice1.push(VOTE_AMOUNT / 8);

        _batchData.push(abi.encode(_mockMetadata));
        _batchData.push(abi.encode(_mockMetadata));
        _batchData.push(abi.encode(_mockMetadata));
        _batchData.push(abi.encode(_mockMetadata));
        _batchData.push(abi.encode(_mockMetadata));
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
    // Helpers
    //////////////////////////////

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

    function _removeChoice(address _registrar, bytes32 _choiceId) public {
        vm.startPrank(_registrar);
        openChoices().removeChoice(_choiceId, "");
        vm.stopPrank();
    }

    function _vote(uint256 _voter, bytes32 _choice, uint256 _amount) public {
        vm.startPrank(voter(_voter));

        bytes memory _pointBytes = abi.encode(voterProof(_voter), VOTE_AMOUNT);
        bytes memory _votesBytes = abi.encode(emptyMetadata);

        contest().vote(_choice, _amount, abi.encode(_votesBytes, _pointBytes));
        vm.stopPrank();
    }

    function _retract(uint256 _voter, bytes32 _choice, uint256 _amount) public {
        vm.startPrank(voter(_voter));

        bytes memory _votesBytes = abi.encode(emptyMetadata);

        contest().retractVote(_choice, _amount, abi.encode(_votesBytes, ""));
        vm.stopPrank();
    }

    function _change(uint256 _voter, bytes32 _oldChoice, bytes32 _newChoice, uint256 _amount) public {
        vm.startPrank(voter(_voter));

        bytes memory _pointBytes = abi.encode(voterProof(_voter), VOTE_AMOUNT);
        bytes memory _votesBytes = abi.encode(emptyMetadata);

        contest().changeVote(_oldChoice, _newChoice, _amount, abi.encode(_votesBytes, _pointBytes));
        vm.stopPrank();
    }
}
