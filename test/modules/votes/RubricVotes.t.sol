// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Hats} from "lib/hats-protocol/src/Hats.sol";
import {Accounts} from "../../setup/Accounts.t.sol";
import {MockContestSetup} from "../../setup/MockContest.sol";

import {RubricVotes} from "../../../src/modules/votes/RubricVotes.sol";
import {ContestStatus} from "../../../src/core/ContestStatus.sol";

contract RubricVotesTest is Test, Accounts, MockContestSetup {
    error InvalidInitialization();

    event Initialized(address _contest, uint256 _adminHatId);
    event VoteCast(address voter, bytes32 choiceId, uint256 amount);
    event VoteRetracted(address voter, bytes32 choiceId, uint256 amount);

    Hats hats;
    uint256 topHatId;
    uint256 adminHatId;
    uint256 judgeHatId;
    address[] admins;
    address[] judges;
    RubricVotes rubricVotes;

    ///max votes per choice
    uint256 constant MVPC = 1e18;

    function setUp() public {
        rubricVotes = new RubricVotes();
        __setupMockContest();
        _setupHats();

        mockContest().cheatStatus(ContestStatus.Voting);
    }

    ///////////////////////////////////
    //// Base Unit Tests
    ///////////////////////////////////

    function testInit() public {
        _init();

        assert(rubricVotes.adminHatId() == adminHatId);
        assert(rubricVotes.judgeHatId() == judgeHatId);

        assert(address(rubricVotes.contest()) == address(mockContest()));

        assertTrue(hats.isWearerOfHat(admin1(), adminHatId));
        assertTrue(hats.isWearerOfHat(admin2(), adminHatId));
        assertTrue(hats.isWearerOfHat(judge1(), judgeHatId));
        assertTrue(hats.isWearerOfHat(judge2(), judgeHatId));
        assertTrue(hats.isWearerOfHat(judge3(), judgeHatId));
    }

    function testVote_max() public {
        _init();

        _vote(judge1(), choice1(), MVPC);

        assertEq(rubricVotes.votes(choice1(), address(judge1())), MVPC);
    }

    function testVote_partial() public {
        _init();

        _vote(judge1(), choice1(), MVPC * 89 / 100);

        assertEq(rubricVotes.votes(choice1(), address(judge1())), MVPC * 89 / 100);
    }

    function testVote_many() public {
        _init();

        _vote(judge1(), choice1(), MVPC * 89 / 100);
        _vote(judge1(), choice2(), MVPC * 10 / 100);
        _vote(judge1(), choice3(), MVPC * 74 / 100);

        assertEq(rubricVotes.votes(choice1(), address(judge1())), MVPC * 89 / 100);
        assertEq(rubricVotes.votes(choice2(), address(judge1())), MVPC * 10 / 100);
        assertEq(rubricVotes.votes(choice3(), address(judge1())), MVPC * 74 / 100);

        assertEq(rubricVotes.totalVotesForChoice(choice1()), MVPC * 89 / 100);
        assertEq(rubricVotes.totalVotesForChoice(choice2()), MVPC * 10 / 100);
        assertEq(rubricVotes.totalVotesForChoice(choice3()), MVPC * 74 / 100);
    }

    function testVote_many_allJudges() public {
        _init();

        _vote(judge1(), choice1(), MVPC * 89 / 100);
        _vote(judge1(), choice2(), MVPC * 10 / 100);
        _vote(judge1(), choice3(), MVPC * 74 / 100);

        assertEq(rubricVotes.votes(choice1(), address(judge1())), MVPC * 89 / 100);
        assertEq(rubricVotes.votes(choice2(), address(judge1())), MVPC * 10 / 100);
        assertEq(rubricVotes.votes(choice3(), address(judge1())), MVPC * 74 / 100);

        _vote(judge2(), choice1(), MVPC * 74 / 100);
        _vote(judge2(), choice2(), MVPC * 45 / 100);
        _vote(judge2(), choice3(), MVPC * 56 / 100);

        assertEq(rubricVotes.votes(choice1(), address(judge2())), MVPC * 74 / 100);
        assertEq(rubricVotes.votes(choice2(), address(judge2())), MVPC * 45 / 100);
        assertEq(rubricVotes.votes(choice3(), address(judge2())), MVPC * 56 / 100);

        _vote(judge3(), choice1(), MVPC * 33 / 100);
        _vote(judge3(), choice2(), MVPC * 44 / 100);
        _vote(judge3(), choice3(), MVPC * 55 / 100);

        assertEq(rubricVotes.votes(choice1(), address(judge3())), MVPC * 33 / 100);
        assertEq(rubricVotes.votes(choice2(), address(judge3())), MVPC * 44 / 100);
        assertEq(rubricVotes.votes(choice3(), address(judge3())), MVPC * 55 / 100);

        assertEq(rubricVotes.totalVotesForChoice(choice1()), MVPC * 89 / 100 + MVPC * 74 / 100 + MVPC * 33 / 100);
        assertEq(rubricVotes.totalVotesForChoice(choice2()), MVPC * 10 / 100 + MVPC * 45 / 100 + MVPC * 44 / 100);
        assertEq(rubricVotes.totalVotesForChoice(choice3()), MVPC * 74 / 100 + MVPC * 56 / 100 + MVPC * 55 / 100);
    }

    function testRectract() public {
        _init();

        _vote(judge1(), choice1(), MVPC);
        _retractVote(judge1(), choice1(), MVPC);

        assertEq(rubricVotes.votes(choice1(), address(judge1())), 0);
        assertEq(rubricVotes.totalVotesForChoice(choice1()), 0);
    }

    ///////////////////////////////////
    //// Reverts
    ///////////////////////////////////

    function testRevert_init_twice() public {
        _init();

        vm.expectRevert(InvalidInitialization.selector);
        _init();
    }

    function testRevert_init_invalid() public {
        bytes memory data = abi.encode(0, judgeHatId, MVPC, address(hats));

        vm.expectRevert("Invalid init params");
        rubricVotes.initialize(address(mockContest()), data);

        data = abi.encode(topHatId, 0, MVPC, address(hats));
        vm.expectRevert("Invalid init params");
        rubricVotes.initialize(address(mockContest()), data);

        data = abi.encode(topHatId, judgeHatId, 0, address(hats));
        vm.expectRevert("Invalid init params");
        rubricVotes.initialize(address(mockContest()), data);

        data = abi.encode(topHatId, judgeHatId, MVPC, address(0));
        vm.expectRevert("Invalid init params");
        rubricVotes.initialize(address(mockContest()), data);

        data = abi.encode(topHatId, judgeHatId, MVPC, address(hats));
        vm.expectRevert("Invalid init params");
        rubricVotes.initialize(address(0), data);
    }

    function testRevert_vote_notContest() public {
        _init();

        vm.prank(someGuy());
        vm.expectRevert("Only contest");
        rubricVotes.vote(judge1(), choice1(), MVPC, "");
    }

    function testRevert_vote_notJudge() public {
        _init();

        vm.prank(address(mockContest()));
        vm.expectRevert("Only wearer");

        rubricVotes.vote(someGuy(), choice1(), MVPC, "");
    }

    function testRevert_vote_zeroAmount() public {
        _init();

        vm.prank(address(mockContest()));
        vm.expectRevert("Amount must be greater than 0");
        rubricVotes.vote(judge1(), choice1(), 0, "");
    }

    function testRevert_vote_overMVPC() public {
        _init();

        vm.prank(address(mockContest()));
        vm.expectRevert("Amount exceeds maxVotesForChoice");
        rubricVotes.vote(judge1(), choice1(), MVPC + 1, "");
    }

    function testRevert_vote_overMVPC_doubleVote() public {
        _init();

        _vote(judge1(), choice1(), MVPC / 2);

        vm.prank(address(mockContest()));
        vm.expectRevert("Amount exceeds maxVotesForChoice");
        rubricVotes.vote(judge1(), choice1(), MVPC / 2 + 1, "");
    }

    ///////////////////////////////////
    //// Helpers
    ///////////////////////////////////

    function _retractVote(address _voter, bytes32 _choiceId, uint256 _amount) private {
        vm.prank(address(mockContest()));
        vm.expectEmit(true, false, false, true);
        emit VoteRetracted(_voter, _choiceId, _amount);
        rubricVotes.retractVote(_voter, _choiceId, _amount, "");
    }

    function _vote(address _voter, bytes32 _choiceId, uint256 _amount) private {
        vm.prank(address(mockContest()));
        vm.expectEmit(true, false, false, true);
        emit VoteCast(_voter, _choiceId, _amount);
        rubricVotes.vote(_voter, _choiceId, _amount, "");
    }

    function _init() private {
        bytes memory data = abi.encode(adminHatId, judgeHatId, MVPC, address(hats));

        rubricVotes.initialize(address(mockContest()), data);
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

        vm.prank(admin1());
        judgeHatId = hats.createHat(adminHatId, "judge", 100, address(13), address(13), true, "");

        judges.push(judge1());
        judges.push(judge2());
        judges.push(judge3());

        uint256[] memory judgeIds = new uint256[](judges.length);

        judgeIds[0] = judgeHatId;
        judgeIds[1] = judgeHatId;
        judgeIds[2] = judgeHatId;

        vm.prank(dummyDao());
        hats.batchMintHats(judgeIds, judges);
    }
}
