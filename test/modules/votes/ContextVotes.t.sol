// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {ContextVotesV0} from "../../../src/modules/votes/ContextVotes.sol";
import {ContextPointsV0} from "../../../src/modules/points/ContextPoints.sol";
import {ARBTokenSetupLive} from "../../setup/VotesTokenSetup.t.sol";
import {Metadata} from "../../../src/core/Metadata.sol";
import {MockContestSetup} from "../../setup/MockContest.sol";
import {ContestStatus} from "../../../src/core/ContestStatus.sol";

import {Accounts} from "../../setup/Accounts.t.sol";

import {BaalSetupLive} from "../../setup/BaalSetup.t.sol";

contract ContextVotesV0Test is Test, ARBTokenSetupLive, BaalSetupLive, MockContestSetup, Accounts {
    event Initialized(address contest, uint256 duration, address daoToken, address contextToken);
    event VotingStarted(uint256 startTime, uint256 endTime, address pointModule);
    event VoteCast(address indexed voter, bytes32 choiceId, uint256 amount, Metadata _reason, address _votingToken);
    event VoteRetracted(
        address indexed voter, bytes32 choiceId, uint256 amount, Metadata _reason, address _votingToken
    );

    ContextVotesV0 votesModule;
    ContextPointsV0 pointsModule;

    uint256 startBlock = 208213640;
    uint256 delegateBlock = startBlock + 10;
    uint256 snapshotBlock = delegateBlock + 15;
    uint256 voteBlock = delegateBlock + 20;

    uint256 _voteAmount = 10e18;
    uint256 _contextAmount = 3e18;
    uint256 _daoAmount = 7e18;
    uint256 TWO_WEEKS = 1209600;

    address[] _voters;

    Metadata _reason = Metadata(1, "reason");

    // 05/05/2024 23:23:15 PST
    uint256 constant INIT_TIME = 1714976595;

    function setUp() public {
        vm.createSelectFork({blockNumber: startBlock, urlOrAlias: "arbitrumOne"});

        __setupArbToken();
        __setUpBaal();
        __setupMockContest();

        votesModule = new ContextVotesV0();
        pointsModule = new ContextPointsV0();

        // Forge block.timestamp starts at 0
        // warp into the future so we can test
        vm.warp(INIT_TIME);

        mockContest().cheatStatus(ContestStatus.Voting);
    }

    //////////////////////////////
    // Base Functionality Tests
    //////////////////////////////

    function testInitialize_twice() public {
        // _initialize();

        // vm.expectRevert("Initializable: contract is already initialized");

        // bytes memory initData = abi.encode(address(voteToken()));

        // pointsModule().initialize(address(this), initData);
    }
}
