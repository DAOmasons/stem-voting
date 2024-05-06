// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ARBTokenSetupLive} from "../../setup/VotesTokenSetup.sol";
import {ERC20VotesPoints} from "../../../src/modules/points/ERC20VotesPoints.sol";

contract ERC20VotesPointsTest is Test, ARBTokenSetupLive {
    event Initialized(address contest, address token, uint256 votingCheckpoint);
    event PointsAllocated(address indexed user, uint256 amount);
    event PointsReleased(address indexed user, uint256 amount);

    address[] _voters;

    uint256 startBlock = 208213640;
    uint256 delegateBlock = startBlock + 10;
    uint256 snapshotBlock = delegateBlock + 15;
    uint256 voteBlock = delegateBlock + 20;

    uint256 voteAmount = 1_000e18;

    ERC20VotesPoints pointsModule;

    function setUp() public {
        vm.createSelectFork({blockNumber: startBlock, urlOrAlias: "arbitrumOne"});
        __setupArbToken();

        pointsModule = new ERC20VotesPoints();
    }

    //////////////////////////////
    // Token Setup Tests
    //////////////////////////////

    function test_setup() public view {
        uint256 whaleBalance = arbToken().balanceOf(arbWhale());

        assertEq(arbToken().symbol(), "ARB");
        assertEq(arbToken().decimals(), 18);

        assertEq(whaleBalance, 83_315_716_895924118689251310);
    }

    function test_airdrop() public {
        _airdrop();

        for (uint256 i = 0; i < _voters.length; i++) {
            uint256 balance = arbToken().balanceOf(_voters[i]);

            assertEq(balance, voteAmount);
        }
    }

    function test_delegateVotes() public {
        _setupVotes();
        for (uint256 i = 0; i < _voters.length; i++) {
            address delegate = arbToken().delegates(_voters[i]);
            uint256 votes = arbToken().getVotes(_voters[i]);

            assertEq(delegate, _voters[i]);

            assertEq(votes, voteAmount);
            // has votes at delegateBlock

            uint256 delegateVotes = arbToken().getPastVotes(_voters[i], delegateBlock);
            assertEq(delegateVotes, voteAmount);

            // has votes at snapshot
            uint256 snapshotVotes = arbToken().getPastVotes(_voters[i], snapshotBlock);
            assertEq(snapshotVotes, voteAmount);

            // does not have votes before snapshot
            uint256 preDelegateVotes = arbToken().getPastVotes(_voters[i], delegateBlock - 1);
            assertEq(preDelegateVotes, 0);
        }
    }

    //////////////////////////////
    // Base Functionality Tests
    //////////////////////////////

    function test_initialize() public {
        _initialize();

        assertEq(address(pointsModule.voteToken()), address(arbToken()));
        assertEq(pointsModule.votingCheckpoint(), snapshotBlock);
        assertEq(pointsModule.contest(), address(this));
    }

    function test_allocatePoints_total() public {
        _allocatePoints(0);

        uint256 allocatedPoints = pointsModule.getAllocatedPoints(_voters[0]);
        uint256 pointsLeft = pointsModule.getPoints(_voters[0]);

        assertEq(allocatedPoints, voteAmount);
        assertEq(pointsLeft, 0);
    }

    function test_allocatePoints_partial() public {
        _initialize();

        pointsModule.allocatePoints(_voters[0], voteAmount / 2);

        uint256 allocatedPoints = pointsModule.getAllocatedPoints(_voters[0]);
        uint256 pointsLeft = pointsModule.getPoints(_voters[0]);

        assertEq(pointsLeft, voteAmount / 2);
        assertEq(allocatedPoints, voteAmount / 2);

        pointsModule.allocatePoints(_voters[0], voteAmount / 2);

        allocatedPoints = pointsModule.getAllocatedPoints(_voters[0]);
        pointsLeft = pointsModule.getPoints(_voters[0]);

        assertEq(allocatedPoints, voteAmount);
        assertEq(pointsLeft, 0);
    }

    function test_releasePoints_total() public {
        _releasePoints(0);

        uint256 allocatedPoints = pointsModule.getAllocatedPoints(_voters[0]);
        uint256 pointsLeft = pointsModule.getPoints(_voters[0]);

        assertEq(allocatedPoints, 0);
        assertEq(pointsLeft, voteAmount);
    }

    function test_releasePoints_partial() public {
        _allocatePoints(0);

        pointsModule.releasePoints(_voters[0], voteAmount / 2);

        uint256 allocatedPoints = pointsModule.getAllocatedPoints(_voters[0]);
        uint256 pointsLeft = pointsModule.getPoints(_voters[0]);

        assertEq(allocatedPoints, voteAmount / 2);
        assertEq(pointsLeft, voteAmount / 2);

        pointsModule.releasePoints(_voters[0], voteAmount / 2);

        allocatedPoints = pointsModule.getAllocatedPoints(_voters[0]);
        pointsLeft = pointsModule.getPoints(_voters[0]);

        assertEq(allocatedPoints, 0);
        assertEq(pointsLeft, voteAmount);
    }

    //////////////////////////////
    // Reverts
    //////////////////////////////

    function testRevertAllocate_nonContest() public {
        _initialize();

        vm.prank(voter0());
        vm.expectRevert("Only contest");
        pointsModule.allocatePoints(voter0(), voteAmount);

        vm.expectRevert("Only contest");
        vm.prank(someGuy());
        pointsModule.allocatePoints(voter0(), voteAmount);
    }

    function testRevertAllocate_nonZero() public {
        _initialize();

        vm.expectRevert("Amount must be greater than 0");
        pointsModule.allocatePoints(voter0(), 0);
    }

    function testRevertAllocate_insufficient() public {
        _initialize();

        vm.expectRevert("Insufficient points available");
        pointsModule.allocatePoints(voter0(), voteAmount + 1);

        vm.expectRevert("Insufficient points available");
        pointsModule.allocatePoints(someGuy(), voteAmount);
    }

    function testRevertRelease_nonContest() public {
        _initialize();

        vm.prank(voter0());
        vm.expectRevert("Only contest");
        pointsModule.releasePoints(voter0(), voteAmount);

        vm.expectRevert("Only contest");
        vm.prank(someGuy());
        pointsModule.releasePoints(voter0(), voteAmount);
    }

    function testRevertRelease_nonZero() public {
        _initialize();

        vm.expectRevert("Amount must be greater than 0");
        pointsModule.releasePoints(voter0(), 0);
    }

    function testRevertRelease_insufficient() public {
        _initialize();

        vm.expectRevert("Insufficient points allocated");
        pointsModule.releasePoints(voter0(), voteAmount + 1);

        vm.expectRevert("Insufficient points allocated");
        pointsModule.releasePoints(someGuy(), voteAmount);
    }

    function testRevertClaimPoints() public {
        _initialize();

        vm.expectRevert("This contract does not require users to claim points.");
        pointsModule.claimPoints();
    }

    //////////////////////////////
    // Adversarial
    //////////////////////////////

    function testRevertAllocate_doublespend() public {
        _initialize();

        pointsModule.allocatePoints(voter0(), voteAmount);

        vm.expectRevert("Insufficient points available");
        pointsModule.allocatePoints(voter0(), voteAmount);
    }

    function testRevertAllocate_doublespend_transfer() public {
        _initialize();

        pointsModule.allocatePoints(voter0(), voteAmount);

        vm.startPrank(voter0());
        arbToken().transfer(someGuy(), voteAmount);
        vm.stopPrank();

        vm.expectRevert("Insufficient points available");
        pointsModule.allocatePoints(someGuy(), voteAmount);
    }

    //////////////////////////////
    // Getters
    //////////////////////////////

    function test_getAllocatedPoints() public {
        _initialize();

        for (uint256 i = 0; i < _voters.length; i++) {
            uint256 allocatedPoints = pointsModule.getAllocatedPoints(_voters[i]);
            assertEq(allocatedPoints, 0);

            pointsModule.allocatePoints(_voters[i], voteAmount);
            allocatedPoints = pointsModule.getAllocatedPoints(_voters[i]);
            assertEq(allocatedPoints, voteAmount);
        }
    }

    function test_getPoints() public {
        _initialize();

        for (uint256 i = 0; i < _voters.length; i++) {
            uint256 points = pointsModule.getPoints(_voters[i]);
            assertEq(points, voteAmount);

            pointsModule.allocatePoints(_voters[i], voteAmount);
            points = pointsModule.getPoints(_voters[i]);
            assertEq(points, 0);
        }
    }

    function test_hasVotingPoints() public {
        _initialize();

        for (uint256 i = 0; i < _voters.length; i++) {
            bool hasPoints = pointsModule.hasVotingPoints(_voters[i], voteAmount);
            assertTrue(hasPoints);

            pointsModule.allocatePoints(_voters[i], voteAmount);
            hasPoints = pointsModule.hasVotingPoints(_voters[i], voteAmount);
            assertFalse(hasPoints);
        }
    }

    //////////////////////////////
    // Helpers
    //////////////////////////////

    function _airdrop() internal {
        _voters.push(voter0());
        _voters.push(voter1());
        _voters.push(voter2());

        vm.startPrank(arbWhale());

        for (uint256 i = 0; i < _voters.length;) {
            _arbToken.transfer(_voters[i], voteAmount);

            unchecked {
                i++;
            }
        }

        vm.stopPrank();
    }

    function _delegateVotes() internal {
        vm.roll(delegateBlock);
        for (uint256 i = 0; i < _voters.length;) {
            vm.prank(_voters[i]);
            _arbToken.delegate(_voters[i]);

            unchecked {
                i++;
            }
        }
        vm.roll(voteBlock);
    }

    function _setupVotes() internal {
        _airdrop();
        _delegateVotes();
    }

    function _initialize() internal {
        _setupVotes();
        bytes memory initData = abi.encode(address(arbToken()), snapshotBlock);

        pointsModule.initialize(address(this), initData);
    }

    function _allocatePoints(uint256 _voter) internal {
        _initialize();
        vm.expectEmit(true, false, false, true);
        emit PointsAllocated(_voters[_voter], voteAmount);
        pointsModule.allocatePoints(_voters[_voter], voteAmount);
    }

    function _releasePoints(uint256 _voter) internal {
        _allocatePoints(_voter);

        vm.expectEmit(true, false, false, true);
        emit PointsReleased(_voters[_voter], voteAmount);

        pointsModule.releasePoints(_voters[_voter], voteAmount);
    }
}
