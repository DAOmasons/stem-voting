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

    function testVote_both_partial() public {
        _initialize();
        _setupVoting_now();

        vm.startPrank(address(mockContest()));

        votesModule.vote(voter1(), choice1(), _daoAmount / 2, abi.encode(_reason, address(arbToken())));
        votesModule.vote(voter1(), choice1(), _contextAmount / 2, abi.encode(_reason, address(loot())));

        assertEq(votesModule.daoVotes(choice1(), address(voter1())), _daoAmount / 2);
        assertEq(votesModule.contextVotes(choice1(), address(voter1())), _contextAmount / 2);

        votesModule.vote(voter1(), choice1(), _daoAmount / 2, abi.encode(_reason, address(arbToken())));
        votesModule.vote(voter1(), choice1(), _contextAmount / 2, abi.encode(_reason, address(loot())));

        assertEq(votesModule.daoVotes(choice1(), address(voter1())), _daoAmount);
        assertEq(votesModule.contextVotes(choice1(), address(voter1())), _contextAmount);

        vm.stopPrank();
    }

    function testVote_retract_context() public {
        _initialize();
        _setupVoting_now();
        _vote_context();
        _retract_context();

        assertEq(votesModule.contextVotes(choice1(), address(voter1())), 0);
        assertEq(votesModule.totalContextVotesForChoice(choice1()), 0);
        assertEq(votesModule.totalContextVotes(), 0);
    }

    function testVote_retract_dao() public {
        _initialize();
        _setupVoting_now();
        _vote_dao();
        _retract_dao();

        assertEq(votesModule.daoVotes(choice1(), address(voter1())), 0);
        assertEq(votesModule.totalDaoVotesForChoice(choice1()), 0);
        assertEq(votesModule.totalDaoVotes(), 0);
    }

    function testVote_finalizeVoting() public {
        _initialize();
        _setupVoting_now();
        _vote_dao();
        _retract_dao();
        _finalizeVoting();
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

    function testRevert_setupVoting_alreadyStarted() public {
        _initialize();
        _setupVoting_now();
        vm.expectRevert("Voting has already started");
        votesModule.setupVoting(0, TWO_WEEKS);
    }

    function testRevert_setupVoting_notInitialized() public {
        _initialize();

        vm.expectRevert("Contest is not in voting state");
        votesModule.setupVoting(0, TWO_WEEKS);
    }

    function testRevert_setupVoting_pastStartTime() public {
        _initialize();

        mockContest().cheatStatus(ContestStatus.Voting);

        vm.expectRevert("Start time must be in the future");
        votesModule.setupVoting(block.timestamp, TWO_WEEKS);

        vm.expectRevert("Start time must be in the future");
        votesModule.setupVoting(block.timestamp - 1, TWO_WEEKS);

        votesModule.setupVoting(block.timestamp + 1, TWO_WEEKS);
    }

    function testRevert_vote_onlyContest() public {
        _initialize();
        _setupVoting_now();

        vm.expectRevert("Only contest");
        votesModule.vote(voter1(), choice1(), _daoAmount, abi.encode(_reason, address(0)));
    }

    function testRevert_vote_invalidToken() public {
        _initialize();
        _setupVoting_now();

        vm.expectRevert("Invalid token");
        vm.startPrank(address(mockContest()));
        votesModule.vote(voter1(), choice1(), _daoAmount, abi.encode(_reason, address(0)));
        vm.stopPrank();
    }

    function testRevert_retractVote_onlyContest() public {
        _initialize();
        _setupVoting_now();
        _vote_dao();

        vm.expectRevert("Only contest");
        votesModule.retractVote(voter1(), choice1(), _daoAmount, abi.encode(_reason, address(0)));
    }

    function testRevert_retractVote_invalidToken() public {
        _initialize();
        _setupVoting_now();
        _vote_dao();

        vm.expectRevert("Invalid token");
        vm.startPrank(address(mockContest()));
        votesModule.retractVote(voter1(), choice1(), _daoAmount, abi.encode(_reason, address(0)));
        vm.stopPrank();
    }

    function testRevert_retractVote_insufficientBalance() public {
        _initialize();
        _setupVoting_now();
        _vote_dao();

        vm.expectRevert("Insufficient votes");

        vm.startPrank(address(mockContest()));
        votesModule.retractVote(voter1(), choice1(), _daoAmount + 1, abi.encode(_reason, address(arbToken())));
        vm.stopPrank();
    }

    function testRevert_notVotingPeriod() public {
        _initialize();

        vm.expectRevert("Must vote within voting period");
        vm.startPrank(address(mockContest()));
        votesModule.vote(voter1(), choice1(), _daoAmount, abi.encode(_reason, address(0)));

        mockContest().cheatStatus(ContestStatus.Voting);
        votesModule.setupVoting(block.timestamp + 1, TWO_WEEKS);

        vm.expectRevert("Must vote within voting period");
        votesModule.vote(voter1(), choice1(), _daoAmount, abi.encode(_reason, address(0)));

        vm.warp(block.timestamp + 1);

        votesModule.vote(voter1(), choice1(), _daoAmount, abi.encode(_reason, address(loot())));

        vm.warp(block.timestamp + TWO_WEEKS + 1);

        vm.expectRevert("Must vote within voting period");
        votesModule.vote(voter1(), choice1(), _daoAmount, abi.encode(_reason, address(loot())));

        vm.stopPrank();
    }

    //////////////////////////////
    // Helpers
    //////////////////////////////

    function _finalizeVoting() private {
        vm.warp(block.timestamp + TWO_WEEKS + 1);
        votesModule.finalizeVoting();
    }

    function _retract_dao() public {
        vm.expectEmit(true, false, false, true);
        emit VoteRetracted(voter1(), choice1(), _daoAmount, _reason, address(arbToken()));

        vm.startPrank(address(mockContest()));
        votesModule.retractVote(voter1(), choice1(), _daoAmount, abi.encode(_reason, address(arbToken())));
        vm.stopPrank();
    }

    function _retract_context() public {
        vm.expectEmit(true, false, false, true);
        emit VoteRetracted(voter1(), choice1(), _contextAmount, _reason, address(loot()));

        vm.startPrank(address(mockContest()));
        votesModule.retractVote(voter1(), choice1(), _contextAmount, abi.encode(_reason, address(loot())));
        vm.stopPrank();
    }

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
