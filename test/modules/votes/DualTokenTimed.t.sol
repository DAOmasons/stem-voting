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

        votesModule = new DualTokenTimedV0();
        pointsModule = new DualTokenPointsV0();

        _setupPoints();

        // Forge block.timestamp starts at 0
        // warp into the future so we can test
        vm.warp(INIT_TIME);
    }

    //////////////////////////////
    // Base Functionality Tests
    //////////////////////////////

    function test_initialize() public {
        _inititalize();
    }

    //////////////////////////////
    // Helpers
    //////////////////////////////

    function _setVotingTime_now() private {
        _inititalize();

        mockContest().cheatStatus(ContestStatus.Voting);

        vm.expectEmit(true, false, false, true);
        emit VotingStarted(block.timestamp, block.timestamp + TWO_WEEKS, address(0));

        votesModule.setupVoting(0, address(0));
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
