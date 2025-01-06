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

    ///////////////////////////////////
    //// Helpers
    ///////////////////////////////////

    function _vote(address _voter, uint256 _amount) private {
        rubricVotes.vote(_voter, choice1(), _amount, "");
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
