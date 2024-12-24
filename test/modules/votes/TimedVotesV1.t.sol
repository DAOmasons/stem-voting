// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Accounts} from "../../setup/Accounts.t.sol";
import {Hats} from "lib/hats-protocol/src/Hats.sol";
import {TimedVotesV1} from "../../../src/modules/votes/TimedVotesV1.sol";
import {Metadata} from "../../../src/core/Metadata.sol";
import {ContestStatus} from "../../../src/core/ContestStatus.sol";
import {MockContestSetup} from "../../setup/MockContest.sol";
import {TimerType} from "../../../src/modules/votes/utils/VoteTimer.sol";

contract TimedVotingV1Test is Test, Accounts, MockContestSetup {
    event Initialized(address _contest, uint256 _startTime, TimerType _timerType, uint256 _adminHatId);
    event TimerSet(uint256 startTime, uint256 endTime);
    event VoteCast(address indexed voter, bytes32 choiceId, uint256 amount, Metadata _reason);
    event VoteRetracted(address indexed voter, bytes32 choiceId, uint256 amount, Metadata _reason);

    TimedVotesV1 votesModule;
    Hats hats;

    error InvalidInitialization();

    uint256 _voteAmount = 1e18;
    uint256 TWO_WEEKS = 1209600;

    Metadata _reason = Metadata(1, "reason");

    uint256 topHatId;
    uint256 adminHatId;

    address[] admins;

    uint256 constant INIT_TIME = 1714976595;

    bytes wrappedReason = abi.encode(abi.encode(_reason), "");

    function setUp() public {
        __setupMockContest();

        votesModule = new TimedVotesV1();
        _setupHats();

        vm.warp(INIT_TIME);
    }

    //////////////////////////////
    // Base Functionality Tests
    //////////////////////////////

    function testInit_auto() public {
        _init_auto();

        assertEq(address(votesModule.contest()), address(mockContest()));
        assertEq(uint8(votesModule.timerType()), uint8(TimerType.Auto));
        assertEq(votesModule.duration(), TWO_WEEKS);
        assertEq(votesModule.adminHatId(), adminHatId);
        assertEq(votesModule.startTime(), INIT_TIME);
        assertEq(votesModule.endTime(), INIT_TIME + TWO_WEEKS);
    }

    function testVote_auto() public {
        _init_auto();
        _vote(voter1(), _voteAmount);

        assertEq(votesModule.votes(choice1(), address(voter1())), _voteAmount);
        assertEq(votesModule.totalVotesForChoice(choice1()), _voteAmount);
    }

    function testRetractVote_auto() public {
        _init_auto();
        _vote(voter1(), _voteAmount);

        assertEq(votesModule.votes(choice1(), address(voter1())), _voteAmount);
        assertEq(votesModule.totalVotesForChoice(choice1()), _voteAmount);

        _retract(voter1(), _voteAmount);

        assertEq(votesModule.votes(choice1(), address(voter1())), 0);
        assertEq(votesModule.totalVotesForChoice(choice1()), 0);
    }

    function testFinalize_auto() public {
        _init_auto();
        _vote(voter1(), _voteAmount);

        assertEq(votesModule.votes(choice1(), address(voter1())), _voteAmount);
        assertEq(votesModule.totalVotesForChoice(choice1()), _voteAmount);

        vm.warp(INIT_TIME + TWO_WEEKS + 1);
        _finalizeVoting();
    }

    function testInit_preset() public {
        _init_preset();

        assertEq(address(votesModule.contest()), address(mockContest()));
        assertEq(uint8(votesModule.timerType()), uint8(TimerType.Preset));
        assertEq(votesModule.duration(), TWO_WEEKS);
        assertEq(votesModule.adminHatId(), adminHatId);
        assertEq(votesModule.startTime(), INIT_TIME + TWO_WEEKS);
        assertEq(votesModule.endTime(), INIT_TIME + TWO_WEEKS + TWO_WEEKS);
    }

    function testVote_preset() public {
        _init_preset();
        vm.warp(INIT_TIME + TWO_WEEKS + 1);
        _vote(voter1(), _voteAmount);

        assertEq(votesModule.votes(choice1(), address(voter1())), _voteAmount);
        assertEq(votesModule.totalVotesForChoice(choice1()), _voteAmount);
    }

    function testRetractVote_preset() public {
        _init_preset();
        vm.warp(INIT_TIME + TWO_WEEKS + 1);
        _vote(voter1(), _voteAmount);

        assertEq(votesModule.votes(choice1(), address(voter1())), _voteAmount);
        assertEq(votesModule.totalVotesForChoice(choice1()), _voteAmount);

        _retract(voter1(), _voteAmount);

        assertEq(votesModule.votes(choice1(), address(voter1())), 0);
        assertEq(votesModule.totalVotesForChoice(choice1()), 0);
    }

    function testFinalize_preset() public {
        _init_preset();
        vm.warp(INIT_TIME + TWO_WEEKS + 1);
        _vote(voter1(), _voteAmount);

        assertEq(votesModule.votes(choice1(), address(voter1())), _voteAmount);
        assertEq(votesModule.totalVotesForChoice(choice1()), _voteAmount);

        vm.warp(INIT_TIME + TWO_WEEKS + TWO_WEEKS + 1);
        _finalizeVoting();
    }

    function testInit_lazy() public {
        _init_lazy();

        assertEq(address(votesModule.contest()), address(mockContest()));
        assertEq(uint8(votesModule.timerType()), uint8(TimerType.Lazy));
        assertEq(votesModule.duration(), TWO_WEEKS);
        assertEq(votesModule.adminHatId(), adminHatId);
        assertEq(votesModule.startTime(), 0);
        assertEq(votesModule.endTime(), 0);
    }

    function testSetupTimer_lazy() public {
        _init_lazy();

        vm.warp(INIT_TIME);
        _startTimer();

        assertEq(votesModule.startTime(), INIT_TIME);
        assertEq(votesModule.endTime(), INIT_TIME + TWO_WEEKS);
    }

    function testVote_lazy() public {
        _init_lazy();

        vm.warp(INIT_TIME);

        _startTimer();
        _vote(voter1(), _voteAmount);

        assertEq(votesModule.votes(choice1(), address(voter1())), _voteAmount);
        assertEq(votesModule.totalVotesForChoice(choice1()), _voteAmount);
    }

    function testVote_lazy_retract() public {
        _init_lazy();

        vm.warp(INIT_TIME);

        _startTimer();
        _vote(voter1(), _voteAmount);

        assertEq(votesModule.votes(choice1(), address(voter1())), _voteAmount);
        assertEq(votesModule.totalVotesForChoice(choice1()), _voteAmount);

        _retract(voter1(), _voteAmount);

        assertEq(votesModule.votes(choice1(), address(voter1())), 0);
        assertEq(votesModule.totalVotesForChoice(choice1()), 0);
    }

    function testFinalize_lazy() public {
        _init_lazy();

        vm.warp(INIT_TIME);

        _startTimer();
        _vote(voter1(), _voteAmount);

        assertEq(votesModule.votes(choice1(), address(voter1())), _voteAmount);
        assertEq(votesModule.totalVotesForChoice(choice1()), _voteAmount);

        vm.warp(INIT_TIME + TWO_WEEKS + 1);
        _finalizeVoting();
    }

    //////////////////////////////
    // Reverts
    //////////////////////////////

    function testRevert_doubleInit() public {
        _init_auto();

        bytes memory data = abi.encode(TWO_WEEKS, 0, TimerType.Auto, adminHatId, address(hats));

        vm.expectRevert(InvalidInitialization.selector);
        votesModule.initialize(address(mockContest()), data);
    }

    function testRevert_initAuto_invalidStartTime() public {
        bytes memory data = abi.encode(TWO_WEEKS, 1, TimerType.Auto, adminHatId, address(hats));

        vm.expectRevert("Invalid start time");
        votesModule.initialize(address(mockContest()), data);

        data = abi.encode(TWO_WEEKS, INIT_TIME + TWO_WEEKS, TimerType.Auto, adminHatId, address(hats));
        vm.expectRevert("Invalid start time");
        votesModule.initialize(address(mockContest()), data);
    }

    function testRevert_afterVotingPeriod_auto_vote() public {
        _init_auto();
        vm.warp(INIT_TIME + TWO_WEEKS + 1);

        vm.expectRevert("Not voting period");
        vm.prank(address(mockContest()));
        votesModule.vote(address(voter1()), choice1(), _voteAmount, wrappedReason);
    }

    function testRevert_afterVotingPeriod_auto_retract() public {
        _init_auto();

        _vote(voter1(), _voteAmount);

        vm.warp(INIT_TIME + TWO_WEEKS + 1);

        vm.expectRevert("Not voting period");
        vm.prank(address(mockContest()));
        votesModule.retractVote(address(voter1()), choice1(), _voteAmount, wrappedReason);
    }

    function testRevert_finalizeBefore_auto() public {
        _init_auto();

        _vote(voter1(), _voteAmount);

        vm.expectRevert("Voting period not completed");
        _finalizeVoting();
    }

    function testRevert_finalize_notAdmin() public {
        _init_auto();

        vm.warp(INIT_TIME + TWO_WEEKS + 1);

        vm.expectRevert("Only wearer");
        vm.prank(address(someGuy()));
        votesModule.finalizeVotes();
    }

    function testRevert_beforeVotingPeriod_preset_vote() public {
        _init_preset();

        vm.expectRevert("Not voting period");
        vm.prank(address(mockContest()));
        votesModule.vote(address(voter1()), choice1(), _voteAmount, wrappedReason);
    }

    function testRevert_retractVotingPeriod_preset_vote() public {
        _init_preset();

        vm.warp(INIT_TIME + TWO_WEEKS + TWO_WEEKS + 1);

        vm.expectRevert("Not voting period");
        vm.prank(address(mockContest()));
        votesModule.vote(address(voter1()), choice1(), _voteAmount, wrappedReason);
    }

    function testRevert_beforeVotingPeriod_preset_retract() public {
        _init_preset();

        vm.expectRevert("Not voting period");
        vm.prank(address(mockContest()));
        votesModule.retractVote(address(voter1()), choice1(), _voteAmount, wrappedReason);
    }

    function testRevert_retractVotingPeriod_preset_retract() public {
        _init_preset();

        vm.warp(INIT_TIME + TWO_WEEKS + TWO_WEEKS + 1);

        vm.expectRevert("Not voting period");
        vm.prank(address(mockContest()));
        votesModule.retractVote(address(voter1()), choice1(), _voteAmount, wrappedReason);
    }

    function testRevert_finalizeBefore_preset() public {
        _init_preset();

        vm.warp(INIT_TIME + TWO_WEEKS);

        vm.expectRevert("Voting period not completed");
        _finalizeVoting();

        vm.warp(INIT_TIME + TWO_WEEKS + TWO_WEEKS - 1);

        vm.expectRevert("Voting period not completed");
        _finalizeVoting();
    }

    function testRevert_startTimer_auto() public {
        _init_auto();

        _vote(voter1(), _voteAmount);

        vm.expectRevert("Invalid timer type");
        vm.prank(admin1());
        votesModule.startTimer();
    }

    function testRevert_startTimer_preset() public {
        _init_preset();

        vm.expectRevert("Invalid timer type");
        vm.prank(admin1());
        votesModule.startTimer();
    }

    function testRevert_init_lazy_noAdmin() public {
        bytes memory data = abi.encode(TWO_WEEKS, 0, TimerType.Lazy, 0, address(hats));

        vm.expectRevert("Lazy timer requires admin hat");
        votesModule.initialize(address(mockContest()), data);
    }

    function testRevert_beforeTimerSet_lazy_vote() public {
        _init_lazy();

        vm.expectRevert("Not voting period");

        vm.prank(address(mockContest()));
        votesModule.vote(address(voter1()), choice1(), _voteAmount, wrappedReason);
    }

    function testRevert_beforeTimerSet_lazy_retract() public {
        _init_lazy();

        vm.expectRevert("Not voting period");

        vm.prank(address(mockContest()));
        votesModule.retractVote(address(voter1()), choice1(), _voteAmount, wrappedReason);
    }

    function testRevert_startTimer_notAdmin() public {
        _init_lazy();

        vm.expectRevert("Only wearer");
        vm.prank(address(someGuy()));
        votesModule.startTimer();
    }

    function testRevert_startTime_twice() public {
        _init_lazy();

        _startTimer();

        vm.expectRevert("Timer already set");

        vm.prank(admin1());
        votesModule.startTimer();
    }

    function testRevert_finalizeBefore_lazy() public {
        _init_lazy();

        vm.warp(INIT_TIME);

        _startTimer();

        vm.expectRevert("Voting period not completed");
        _finalizeVoting();

        vm.warp(INIT_TIME + TWO_WEEKS - 1);

        vm.expectRevert("Voting period not completed");
        _finalizeVoting();

        vm.warp(INIT_TIME + TWO_WEEKS);
        _finalizeVoting();
    }

    function testRevert_finalize_beforeStartTime() public {
        _init_lazy();

        vm.expectRevert("Voting period not completed");
        _finalizeVoting();
    }

    //////////////////////////////
    // Helpers
    //////////////////////////////

    function _init_auto() private {
        bytes memory data = abi.encode(TWO_WEEKS, 0, TimerType.Auto, adminHatId, address(hats));

        vm.expectEmit(true, false, false, true);
        emit TimerSet(INIT_TIME, INIT_TIME + TWO_WEEKS);
        vm.expectEmit(true, false, false, true);
        emit Initialized(address(mockContest()), TWO_WEEKS, TimerType.Auto, adminHatId);
        votesModule.initialize(address(mockContest()), data);
    }

    function _init_preset() private {
        bytes memory data = abi.encode(TWO_WEEKS, INIT_TIME + TWO_WEEKS, TimerType.Preset, adminHatId, address(hats));

        vm.expectEmit(true, false, false, true);
        emit TimerSet(INIT_TIME + TWO_WEEKS, INIT_TIME + TWO_WEEKS + TWO_WEEKS);
        vm.expectEmit(true, false, false, true);
        emit Initialized(address(mockContest()), TWO_WEEKS, TimerType.Preset, adminHatId);
        votesModule.initialize(address(mockContest()), data);
    }

    function _vote(address _voter, uint256 _amount) private {
        vm.prank(address(mockContest()));

        vm.expectEmit(true, false, false, true);
        emit VoteCast(_voter, choice1(), _amount, _reason);
        votesModule.vote(address(_voter), choice1(), _amount, wrappedReason);
    }

    function _retract(address _voter, uint256 _amount) private {
        vm.prank(address(mockContest()));

        vm.expectEmit(true, false, false, true);
        emit VoteRetracted(_voter, choice1(), _amount, _reason);
        votesModule.retractVote(address(_voter), choice1(), _amount, wrappedReason);
    }

    function _startTimer() private {
        vm.prank(admin1());
        vm.expectEmit(true, false, false, true);
        emit TimerSet(block.timestamp, block.timestamp + TWO_WEEKS);
        votesModule.startTimer();
    }

    function _finalizeVoting() private {
        vm.prank(address(admin1()));
        votesModule.finalizeVotes();
    }

    function _init_lazy() private {
        bytes memory data = abi.encode(TWO_WEEKS, 0, TimerType.Lazy, adminHatId, address(hats));

        votesModule.initialize(address(mockContest()), data);
    }

    function _setupHats() private {
        hats = new Hats("", "");

        topHatId = hats.mintTopHat(dummyDao(), "", "");

        vm.prank(dummyDao());
        adminHatId = hats.createHat(topHatId, "admin", 100, address(13), address(13), true, "");

        admins.push(admin1());
        admins.push(admin2());

        uint256[] memory adminIds = new uint256[](admins.length);

        adminIds[0] = adminHatId;
        adminIds[1] = adminHatId;

        vm.prank(dummyDao());

        hats.batchMintHats(adminIds, admins);
    }
}
