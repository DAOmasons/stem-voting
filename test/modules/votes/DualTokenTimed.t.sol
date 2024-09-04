// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {DualTokenTimedV0} from "../../../src/modules/votes/DualTokenTimed.sol";
import {DualTokenPointsV0} from "../../../src/modules/points/DualTokenPointsV0.sol";
import {ARBTokenSetupLive} from "../../setup/VotesTokenSetup.t.sol";
import {Metadata} from "../../../src/core/Metadata.sol";
import {MockContestSetup} from "../../setup/MockContest.sol";
import {ContestStatus} from "../../../src/core/ContestStatus.sol";

import {Accounts} from "../../setup/Accounts.t.sol";

import {BaalSetupLive} from "../../setup/BaalSetup.t.sol";

contract DualTokenTimedV0Test is Test, ARBTokenSetupLive, BaalSetupLive, MockContestSetup, Accounts {
    event Initialized(address contest, uint256 duration, address daoToken, address contextToken);
    event VotingStarted(uint256 startTime, uint256 endTime, address pointModule);
    event VoteCast(address indexed voter, bytes32 choiceId, uint256 amount, Metadata _reason, address _votingToken);
    event VoteRetracted(
        address indexed voter, bytes32 choiceId, uint256 amount, Metadata _reason, address _votingToken
    );

    DualTokenTimedV0 votesModule;
    DualTokenPointsV0 pointsModule;

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

        votesModule = new DualTokenTimedV0();
        pointsModule = new DualTokenPointsV0();

        _setupPoints();

        // Forge block.timestamp starts at 0
        // warp into the future so we can test
        vm.warp(INIT_TIME);

        mockContest().cheatStatus(ContestStatus.Voting);
    }

    //////////////////////////////
    // Base Functionality Tests
    //////////////////////////////

    function test_initialize() public {
        _inititalize();
    }

    function test_setVotingTime_now() public {
        _setVotingTime_now();

        assertEq(votesModule.startTime(), block.timestamp);
        assertEq(votesModule.endTime(), block.timestamp + TWO_WEEKS);
        assertEq(uint8(mockContest().contestStatus()), uint8(ContestStatus.Voting));

        assertEq(address(votesModule.pointModule()), address(pointsModule));
    }

    function test_setVotingTime_later() public {
        _setVotingTime_later();

        assertEq(votesModule.startTime(), block.timestamp + TWO_WEEKS);
        assertEq(votesModule.endTime(), block.timestamp + TWO_WEEKS * 2);
        assertEq(uint8(mockContest().contestStatus()), uint8(ContestStatus.Voting));

        assertEq(address(votesModule.pointModule()), address(pointsModule));
    }

    function test_vote_daoToken() public {
        _setVotingTime_now();
        _vote_daoToken();

        assertEq(votesModule.daoVotes(choice1(), address(voter1())), _daoAmount);
        assertEq(votesModule.contextVotes(choice1(), address(voter1())), 0);
    }

    function test_vote_contextToken() public {
        _setVotingTime_now();
        _vote_contextToken();

        assertEq(votesModule.daoVotes(choice1(), address(voter1())), 0);
        assertEq(votesModule.contextVotes(choice1(), address(voter1())), _contextAmount);
    }

    function test_vote_all() public {
        _setVotingTime_now();
        _vote_daoToken();
        _vote_contextToken();

        votesModule.getTotalVotesForChoice(choice1());

        assertEq(votesModule.daoVotes(choice1(), address(voter1())), _daoAmount);
        assertEq(votesModule.contextVotes(choice1(), address(voter1())), _contextAmount);
    }

    function test_retract_dao() public {
        _setVotingTime_now();
        _vote_daoToken();
        _retract(address(arbToken()), _daoAmount);

        assertEq(votesModule.daoVotes(choice1(), address(voter1())), 0);
        assertEq(votesModule.contextVotes(choice1(), address(voter1())), 0);
    }

    function test_retract_context() public {
        _setVotingTime_now();
        _vote_contextToken();
        _retract(address(loot()), _contextAmount);

        assertEq(votesModule.daoVotes(choice1(), address(voter1())), 0);
        assertEq(votesModule.contextVotes(choice1(), address(voter1())), 0);
    }

    function test_retract_partial() public {
        _setVotingTime_now();
        _vote_daoToken();
        _vote_contextToken();
        _retract(address(arbToken()), _daoAmount / 2);
        _retract(address(loot()), _contextAmount / 2);

        assertEq(votesModule.daoVotes(choice1(), address(voter1())), _daoAmount / 2);
        assertEq(votesModule.contextVotes(choice1(), address(voter1())), _contextAmount / 2);
    }

    function test_finalizeVoting() public {
        _setVotingTime_now();
        _vote_daoToken();
        _vote_contextToken();
        _finalizeVoting();
    }

    //////////////////////////////
    // Reverts
    /////////////////////////////

    function testRevert_setVotingTime_now_contestNotVoteStatus() public {
        _inititalize();

        mockContest().cheatStatus(ContestStatus.None);

        vm.expectRevert("Contest is not in voting state");
        votesModule.setupVoting(0, address(pointsModule));

        mockContest().cheatStatus(ContestStatus.Populating);

        vm.expectRevert("Contest is not in voting state");
        votesModule.setupVoting(0, address(pointsModule));

        mockContest().cheatStatus(ContestStatus.Continuous);

        vm.expectRevert("Contest is not in voting state");
        votesModule.setupVoting(0, address(pointsModule));

        mockContest().cheatStatus(ContestStatus.Finalized);

        vm.expectRevert("Contest is not in voting state");
        votesModule.setupVoting(0, address(pointsModule));

        mockContest().cheatStatus(ContestStatus.Executed);

        vm.expectRevert("Contest is not in voting state");
        votesModule.setupVoting(0, address(pointsModule));

        mockContest().cheatStatus(ContestStatus.Voting);
        votesModule.setupVoting(0, address(pointsModule));
    }

    function testRevert_setVotingTime_later_contestNotVoteStatus() public {
        _inititalize();

        mockContest().cheatStatus(ContestStatus.None);

        vm.expectRevert("Contest is not in voting state");
        votesModule.setupVoting(block.timestamp + TWO_WEEKS, address(pointsModule));
    }

    function testRevert_setVotingTime_later_startTimeInPast() public {
        _inititalize();

        mockContest().cheatStatus(ContestStatus.Voting);

        vm.expectRevert("Start time must be in the future");
        votesModule.setupVoting(block.timestamp - 1, address(pointsModule));

        votesModule.setupVoting(block.timestamp + 1, address(pointsModule));
    }

    function testRevert_setVotingTime_now_alreadyStarted() public {
        _setVotingTime_now();

        vm.expectRevert("Voting has already started");
        votesModule.setupVoting(0, address(pointsModule));

        vm.expectRevert("Voting has already started");
        votesModule.setupVoting(block.timestamp + 1, address(pointsModule));
    }

    function testRevert_setVotingTime_later_alreadyStarted() public {
        _setVotingTime_later();

        vm.expectRevert("Must vote within voting period");
        vm.prank(address(mockContest()));
        votesModule.vote(voter1(), choice1(), _contextAmount, abi.encode(_reason, address(loot())));

        vm.warp(block.timestamp + TWO_WEEKS);
        vm.prank(address(mockContest()));
        votesModule.vote(voter1(), choice1(), _contextAmount, abi.encode(_reason, address(loot())));
    }

    function testRevert_voteWithinVotePeriod_before() public {
        _setVotingTime_later();

        vm.expectRevert("Must vote within voting period");
        vm.prank(address(mockContest()));
        votesModule.vote(voter1(), choice1(), _contextAmount, abi.encode(_reason, address(loot())));
    }

    function testRevert_voteWithinVotePeriod_after() public {
        _setVotingTime_now();

        vm.warp(block.timestamp + TWO_WEEKS + 1);

        vm.expectRevert("Must vote within voting period");
        vm.prank(address(mockContest()));
        votesModule.vote(voter1(), choice1(), _contextAmount, abi.encode(_reason, address(loot())));
    }

    function testRevert_vote_notContest() public {
        _setVotingTime_now();

        vm.prank(voter1());
        vm.expectRevert("Only contest");
        votesModule.vote(voter1(), choice1(), _contextAmount, abi.encode(_reason, address(loot())));

        vm.prank(someGuy());
        vm.expectRevert("Only contest");
        votesModule.vote(voter1(), choice1(), _contextAmount, abi.encode(_reason, address(loot())));
    }

    function testRevert_retract_not_contest() public {
        vm.prank(voter1());
        vm.expectRevert("Only contest");
        votesModule.retractVote(voter1(), choice1(), _contextAmount, abi.encode(_reason, address(loot())));

        vm.startPrank(someGuy());
        vm.expectRevert("Only contest");
        votesModule.retractVote(voter1(), choice1(), _contextAmount, abi.encode(_reason, address(loot())));
    }

    function testRevert_retract_more_than_voted() public {
        _setVotingTime_now();

        _vote_contextToken();
        _vote_daoToken();

        vm.startPrank(address(mockContest()));

        vm.expectRevert("Insufficient votes");
        votesModule.retractVote(voter1(), choice1(), _contextAmount + 1, abi.encode(_reason, address(loot())));

        vm.expectRevert("Insufficient votes");
        votesModule.retractVote(voter1(), choice1(), _daoAmount + 1, abi.encode(_reason, address(arbToken())));

        votesModule.retractVote(voter1(), choice1(), _contextAmount, abi.encode(_reason, address(loot())));

        votesModule.retractVote(voter1(), choice1(), _daoAmount, abi.encode(_reason, address(arbToken())));
        vm.stopPrank();
    }

    function testRevert_finalize_notEnded() public {
        _setVotingTime_now();

        _vote_contextToken();

        vm.expectRevert("Voting period has not ended");
        votesModule.finalizeVoting();
    }

    function testRevert_finalize_notVotingStatus() public {
        _setVotingTime_now();
        _finalizeVoting();

        vm.expectRevert("Contest is not in voting state");
        votesModule.finalizeVoting();
    }

    function test_getTotalVotesForChoice() public {
        _setVotingTime_now();

        _vote_daoToken();
        _vote_contextToken();

        vm.startPrank(address(mockContest()));

        votesModule.vote(voter0(), choice1(), _daoAmount / 2, abi.encode(_reason, address(arbToken())));
        votesModule.vote(voter0(), choice2(), _daoAmount / 2, abi.encode(_reason, address(arbToken())));

        votesModule.vote(voter0(), choice1(), _contextAmount / 2, abi.encode(_reason, address(loot())));
        votesModule.vote(voter0(), choice2(), _contextAmount / 2, abi.encode(_reason, address(loot())));

        votesModule.vote(voter2(), choice1(), _daoAmount / 3, abi.encode(_reason, address(arbToken())));
        votesModule.vote(voter2(), choice2(), _daoAmount / 3, abi.encode(_reason, address(arbToken())));
        votesModule.vote(voter2(), protestVote(), _daoAmount / 3, abi.encode(_reason, address(arbToken())));

        votesModule.vote(voter2(), choice1(), _contextAmount / 3, abi.encode(_reason, address(loot())));
        votesModule.vote(voter2(), choice2(), _contextAmount / 3, abi.encode(_reason, address(loot())));
        votesModule.vote(voter2(), protestVote(), _contextAmount / 3, abi.encode(_reason, address(loot())));

        assertEq(
            votesModule.getTotalVotesForChoice(choice1()),
            _daoAmount + _contextAmount + _daoAmount / 2 + _contextAmount / 2 + _daoAmount / 3 + _contextAmount / 3
        );

        assertEq(
            votesModule.getTotalVotesForChoice(choice2()),
            _daoAmount / 2 + _contextAmount / 2 + _daoAmount / 3 + _contextAmount / 3
        );

        assertEq(votesModule.getTotalVotesForChoice(protestVote()), _daoAmount / 3 + _contextAmount / 3);

        assertEq(votesModule.daoVotesForVoter(voter2()), _daoAmount - 1); // rounding
        assertEq(votesModule.contextVotesForVoter(voter2()), _contextAmount);

        assertEq(votesModule.daoVotesForVoter(voter1()), _daoAmount);
        assertEq(votesModule.contextVotesForVoter(voter1()), _contextAmount);

        assertEq(votesModule.daoVotesForVoter(voter0()), _daoAmount);
        assertEq(votesModule.contextVotesForVoter(voter0()), _contextAmount);
    }

    //////////////////////////////
    // Helpers
    //////////////////////////////

    function _finalizeVoting() private {
        vm.warp(block.timestamp + TWO_WEEKS + 1);

        votesModule.finalizeVoting();
    }

    function _retract(address _token, uint256 _amount) private {
        vm.expectEmit(true, false, false, true);
        emit VoteRetracted(voter1(), choice1(), _amount, _reason, _token);

        vm.prank(address(mockContest()));
        votesModule.retractVote(voter1(), choice1(), _amount, abi.encode(_reason, _token));
    }

    function _vote_contextToken() private {
        vm.expectEmit(true, false, false, true);
        emit VoteCast(voter1(), choice1(), _contextAmount, _reason, address(loot()));

        vm.startPrank(address(mockContest()));
        votesModule.vote(voter1(), choice1(), _contextAmount, abi.encode(_reason, address(loot())));
        vm.stopPrank();
    }

    function _vote_daoToken() private {
        vm.expectEmit(true, false, false, true);
        emit VoteCast(voter1(), choice1(), _daoAmount, _reason, address(arbToken()));

        vm.startPrank(address(mockContest()));
        votesModule.vote(voter1(), choice1(), _daoAmount, abi.encode(_reason, address(arbToken())));
        vm.stopPrank();
    }

    function _setVotingTime_later() private {
        _inititalize();

        uint256 startTime = block.timestamp + TWO_WEEKS;

        vm.expectEmit(true, false, false, true);
        emit VotingStarted(startTime, startTime + TWO_WEEKS, address(pointsModule));

        votesModule.setupVoting(startTime, address(pointsModule));
    }

    function _setVotingTime_now() private {
        _inititalize();

        vm.expectEmit(true, false, false, true);
        emit VotingStarted(block.timestamp, block.timestamp + TWO_WEEKS, address(pointsModule));

        votesModule.setupVoting(0, address(pointsModule));
    }

    function _inititalize() private {
        vm.expectEmit(true, false, false, true);
        emit Initialized(address(mockContest()), TWO_WEEKS, address(arbToken()), address(loot()));

        bytes memory data = abi.encode(TWO_WEEKS, address(arbToken()), address(loot()));
        votesModule.initialize(address(mockContest()), data);
    }

    function _setupPoints() internal {
        _voters.push(voter0());
        _voters.push(voter1());
        _voters.push(voter2());

        uint256[] memory contextAmounts = new uint256[](3);

        contextAmounts[0] = _contextAmount;
        contextAmounts[1] = _contextAmount;
        contextAmounts[2] = _contextAmount;

        uint256 whaleBalance = arbToken().balanceOf(arbWhale());

        vm.startPrank(dao().avatar());
        dao().mintLoot(_voters, contextAmounts);
        vm.stopPrank();

        assertEq(arbToken().symbol(), "ARB");
        assertEq(arbToken().decimals(), 18);

        assertEq(whaleBalance, 83_315_716_895924118689251310);

        for (uint256 i = 0; i < _voters.length; i++) {
            vm.startPrank(arbWhale());
            arbToken().transfer(_voters[i], _daoAmount);
            vm.stopPrank();
        }

        vm.roll(delegateBlock);

        for (uint256 i = 0; i < _voters.length; i++) {
            vm.startPrank(_voters[i]);
            arbToken().delegate(_voters[i]);
            vm.stopPrank();

            assertEq(arbToken().balanceOf(_voters[i]), _daoAmount);
            assertEq(arbToken().delegates(_voters[i]), _voters[i]);
            assertEq(arbToken().getVotes(_voters[i]), _daoAmount);
        }
        vm.roll(voteBlock);
        for (uint256 i = 0; i < _voters.length; i++) {
            assertEq(loot().balanceOf(_voters[i]), _contextAmount);
        }

        pointsModule.initialize(address(mockContest()), abi.encode(address(arbToken()), address(loot()), snapshotBlock));

        assertEq(pointsModule.getContextVotingPower(_voters[0]), _contextAmount);
        assertEq(pointsModule.getContextVotingPower(_voters[1]), _contextAmount);
        assertEq(pointsModule.getContextVotingPower(_voters[2]), _contextAmount);

        assertEq(pointsModule.getDaoVotingPower(_voters[0]), _daoAmount);
        assertEq(pointsModule.getDaoVotingPower(_voters[1]), _daoAmount);
        assertEq(pointsModule.getDaoVotingPower(_voters[2]), _daoAmount);

        assertEq(pointsModule.votingCheckpoint(), snapshotBlock);
    }
}
