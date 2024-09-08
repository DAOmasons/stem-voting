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
    event Initialized(address contest, address daoToken, address contextToken);
    event VotingStarted(uint256 startTime, uint256 endTime);
    event VoteCast(address indexed voter, bytes32 choiceId, uint256 amount, Metadata _reason, address _votingToken);
    event VoteRetracted(
        address indexed voter, bytes32 choiceId, uint256 amount, Metadata _reason, address _votingToken
    );

    ContextVotesV0 votesModule;

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

        // Forge block.timestamp starts at 0
        // warp into the future so we can test
        vm.warp(INIT_TIME);

        mockContest().cheatStatus(ContestStatus.Voting);
    }

    //////////////////////////////
    // Base Functionality Tests
    //////////////////////////////

    function testInitialize() public {
        _initialize();

        assertEq(address(votesModule.contest()), address(mockContest()));
        assertEq(votesModule.daoToken(), address(arbToken()));
        assertEq(votesModule.contextToken(), address(loot()));
    }

    function testSetupVoting_now() public {
        _initialize();
        _setupVoting_now();

        assertEq(votesModule.startTime(), block.timestamp);
        assertEq(votesModule.endTime(), block.timestamp + TWO_WEEKS);
    }

    function testSingleVote_context() public {
        _initialize();
        _setupVoting_now();
        _vote_context();

        assertEq(votesModule.contextVotes(choice1(), address(voter1())), _contextAmount);
        assertEq(votesModule.totalContextVotesForChoice(choice1()), _contextAmount);
        assertEq(votesModule.totalContextVotes(), _contextAmount);

        assertEq(votesModule.daoVotes(choice1(), address(voter1())), 0);
        assertEq(votesModule.totalDaoVotesForChoice(choice1()), 0);
        assertEq(votesModule.totalDaoVotes(), 0);
    }

    function testSingleVote_dao() public {
        _initialize();
        _setupVoting_now();
        _vote_dao();

        assertEq(votesModule.daoVotes(choice1(), address(voter1())), _daoAmount);
        assertEq(votesModule.totalDaoVotesForChoice(choice1()), _daoAmount);
        assertEq(votesModule.totalDaoVotes(), _daoAmount);

        assertEq(votesModule.contextVotes(choice1(), address(voter1())), 0);
        assertEq(votesModule.totalContextVotesForChoice(choice1()), 0);
        assertEq(votesModule.totalContextVotes(), 0);
    }

    function testVote_both() public {
        _initialize();
        _setupVoting_now();
        _vote_dao();
        _vote_context();

        assertEq(votesModule.daoVotes(choice1(), address(voter1())), _daoAmount);
        assertEq(votesModule.totalDaoVotesForChoice(choice1()), _daoAmount);
        assertEq(votesModule.totalDaoVotes(), _daoAmount);

        assertEq(votesModule.contextVotes(choice1(), address(voter1())), _contextAmount);
        assertEq(votesModule.totalContextVotesForChoice(choice1()), _contextAmount);
        assertEq(votesModule.totalContextVotes(), _contextAmount);

        assertEq(votesModule.getTotalVotesForChoice(choice1()), _voteAmount);
    }

    //////////////////////////////
    // Reverts
    //////////////////////////////

    function testInitialize_twice() public {
        _initialize();

        bytes memory _data = abi.encode(address(arbToken()), address(loot()));
        vm.expectRevert("Initializable: contract is already initialized");

        votesModule.initialize(address(this), _data);
    }

    //////////////////////////////
    // Helpers
    //////////////////////////////

    function _vote_dao() public {
        vm.expectEmit(true, false, false, true);
        emit VoteCast(voter1(), choice1(), _daoAmount, _reason, address(arbToken()));

        vm.startPrank(address(mockContest()));
        votesModule.vote(voter1(), choice1(), _daoAmount, abi.encode(_reason, address(arbToken())));
        vm.stopPrank();
    }

    function _vote_context() public {
        vm.expectEmit(true, false, false, true);
        emit VoteCast(voter1(), choice1(), _contextAmount, _reason, address(loot()));

        vm.startPrank(address(mockContest()));
        votesModule.vote(voter1(), choice1(), _contextAmount, abi.encode(_reason, address(loot())));
        vm.stopPrank();
    }

    function _setupVoting_now() public {
        mockContest().cheatStatus(ContestStatus.Voting);

        vm.expectEmit(true, false, false, true);
        emit VotingStarted(block.timestamp, block.timestamp + TWO_WEEKS);

        votesModule.setupVoting(0, TWO_WEEKS);
    }

    function _initialize() public {
        bytes memory _data = abi.encode(address(arbToken()), address(loot()));

        vm.expectEmit(true, false, false, true);

        emit Initialized(address(mockContest()), address(arbToken()), address(loot()));
        votesModule.initialize(address(mockContest()), _data);
    }
}
