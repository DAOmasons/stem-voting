// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {AskHausSetupLive} from "./../setup/AskHausSetup.t.sol";
import {HolderType} from "../../src/core/BaalUtils.sol";
import {ContestStatus} from "../../src/core/ContestStatus.sol";
import {Metadata} from "../../src/core/Metadata.sol";

contract AskHausSignalSessionsTest is Test, AskHausSetupLive {
    bytes32[] _allThreeChoices;
    uint256[] _equalSplit;
    uint256[] _equalPartial;
    uint256[] _favorsChoice1;
    uint256[] _favorsChoice2;
    bytes[] _batchData;

    Metadata metadata = Metadata(1, "QmWmyoMoctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWeVdD");
    Metadata metadata2 = Metadata(2, "QmBa4oMoctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWe2zF");
    Metadata metadata3 = Metadata(3, "QmHi23fctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWzt32");

    function setUp() public {
        vm.createSelectFork({blockNumber: START_BLOCK, urlOrAlias: "sepolia"});
        __setupAskHausSignalSession(HolderType.Share);

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
        assertEq(uint8(contest().contestStatus()), uint8(ContestStatus.Continuous));
        assertTrue(contest().isRetractable());
        assertTrue(contest().isContinuous());

        assertEq(address(contest().votesModule()), address(baalVotes()));
        assertEq(address(contest().choicesModule()), address(baalChoices()));
        assertEq(address(contest().pointsModule()), address(baalPoints()));
        assertEq(address(contest().executionModule()), address(execution()));

        // votes params
        assertEq(baalVotes().duration(), TWO_WEEKS);
        assertEq(address(baalVotes().contest()), address(contest()));
        assertEq(baalVotes().startTime(), block.timestamp);
        assertEq(baalVotes().endTime(), block.timestamp + TWO_WEEKS);

        // choices params
        assertEq(address(baalChoices().contest()), address(contest()));
        assertEq(address(baalChoices().dao()), address(dao()));
        assertEq(address(baalChoices().lootToken()), address(loot()));
        assertEq(address(baalChoices().sharesToken()), address(shares()));
        assertEq(uint8(baalChoices().holderType()), uint8(HolderType.Share));
        assertEq(baalChoices().checkpoint(), snapshotTimestamp);
        assertEq(baalChoices().holderThreshold(), SHARE_AMOUNT);
        assertFalse(baalChoices().timed());
        assertEq(baalChoices().startTime(), 0);
        assertEq(baalChoices().endTime(), 0);

        // points params
        assertEq(baalPoints().dao(), address(dao()));
        assertEq(uint8(baalPoints().holderType()), uint8(HolderType.Share));
        assertEq(baalPoints().checkpoint(), snapshotTimestamp);
        assertEq(address(baalPoints().sharesToken()), address(shares()));
        assertEq(address(baalPoints().lootToken()), address(loot()));
        assertEq(address(baalPoints().contest()), address(contest()));

        // execution params
        assertEq(address(execution().contest()), address(contest()));
    }

    //////////////////////////////
    // Basic Tests
    //////////////////////////////

    function _registerChoice() public {}

    function _removeChoice() public {}

    //////////////////////////////
    // Reverts
    //////////////////////////////

    //////////////////////////////
    // Adversarial
    //////////////////////////////

    //////////////////////////////
    // Helpers
    //////////////////////////////
}
