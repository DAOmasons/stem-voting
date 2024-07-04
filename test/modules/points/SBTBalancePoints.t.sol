// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SBTBalancePoints} from "../../../src/modules/points/SBTBalancePoints.sol";
import {GSVotingToken} from "../../../src/factories/gsRough/GSVoteToken.sol";

import {Accounts} from "../../setup/Accounts.t.sol";

contract SBTBalancePointsTest is Test, Accounts {
    event Initialized(address contest, address token);
    event PointsAllocated(address indexed user, uint256 amount);
    event PointsReleased(address indexed user, uint256 amount);

    address[] _voters;

    uint256 constant VOTE_AMOUNT = 1_000e18;

    SBTBalancePoints internal _pointsModule;
    GSVotingToken internal _voteToken;

    function setUp() public {
        _setupToken();
        _pointsModule = new SBTBalancePoints();
    }

    function test_setup() public {
        assertEq(voteToken().name(), "GSVoting");
        assertEq(voteToken().symbol(), "GSV");
        assertEq(voteToken().decimals(), 18);
        assertEq(voteToken().totalSupply(), 3_000e18);

        assertEq(voteToken().owner(), sbtMinter());

        assertEq(voteToken().balanceOf(voter0()), VOTE_AMOUNT);
        assertEq(voteToken().balanceOf(voter1()), VOTE_AMOUNT);
        assertEq(voteToken().balanceOf(voter2()), VOTE_AMOUNT);
        assertEq(voteToken().balanceOf(voter3()), 0);
    }

    function test_initialize() public {
        _initialize();

        assertEq(address(pointsModule().voteToken()), address(voteToken()));
        assertEq(pointsModule().contest(), address(this));
    }

    function test_allocatePoints_total() public {
        _allocatePoints(0);

        uint256 allocatedPoints = pointsModule().getAllocatedPoints(_voters[0]);
        uint256 pointsLeft = pointsModule().getPoints(_voters[0]);

        assertEq(allocatedPoints, VOTE_AMOUNT);
        assertEq(pointsLeft, 0);
    }

    function test_allocatePoints_partial() public {
        _initialize();

        pointsModule().allocatePoints(_voters[0], VOTE_AMOUNT / 2);

        uint256 allocatedPoints = pointsModule().getAllocatedPoints(_voters[0]);
        uint256 pointsLeft = pointsModule().getPoints(_voters[0]);

        assertEq(pointsLeft, VOTE_AMOUNT / 2);
        assertEq(allocatedPoints, VOTE_AMOUNT / 2);

        pointsModule().allocatePoints(_voters[0], VOTE_AMOUNT / 2);

        allocatedPoints = pointsModule().getAllocatedPoints(_voters[0]);
        pointsLeft = pointsModule().getPoints(_voters[0]);

        assertEq(allocatedPoints, VOTE_AMOUNT);
        assertEq(pointsLeft, 0);
    }

    function test_releasePoints_total() public {
        _releasePoints(0);

        uint256 allocatedPoints = pointsModule().getAllocatedPoints(_voters[0]);
        uint256 pointsLeft = pointsModule().getPoints(_voters[0]);

        assertEq(allocatedPoints, 0);
        assertEq(pointsLeft, VOTE_AMOUNT);
    }

    function test_releasePoints_partial() public {
        _allocatePoints(0);

        pointsModule().releasePoints(_voters[0], VOTE_AMOUNT / 2);

        uint256 allocatedPoints = pointsModule().getAllocatedPoints(_voters[0]);
        uint256 pointsLeft = pointsModule().getPoints(_voters[0]);

        assertEq(allocatedPoints, VOTE_AMOUNT / 2);
        assertEq(pointsLeft, VOTE_AMOUNT / 2);

        pointsModule().releasePoints(_voters[0], VOTE_AMOUNT / 2);

        allocatedPoints = pointsModule().getAllocatedPoints(_voters[0]);
        pointsLeft = pointsModule().getPoints(_voters[0]);

        assertEq(allocatedPoints, 0);
        assertEq(pointsLeft, VOTE_AMOUNT);
    }

    function testRevertAllocate_nonContest() public {
        _initialize();

        vm.prank(voter0());
        vm.expectRevert("Only contest");
        pointsModule().allocatePoints(voter0(), VOTE_AMOUNT);

        vm.expectRevert("Only contest");
        vm.prank(someGuy());
        pointsModule().allocatePoints(voter0(), VOTE_AMOUNT);
    }

    function testRevertAllocate_nonZero() public {
        _initialize();

        vm.expectRevert("Amount must be greater than 0");
        pointsModule().allocatePoints(voter0(), 0);
    }

    function testRevertAllocate_insufficient() public {
        _initialize();

        vm.expectRevert("Insufficient points available");
        pointsModule().allocatePoints(voter0(), VOTE_AMOUNT + 1);

        vm.expectRevert("Insufficient points available");
        pointsModule().allocatePoints(someGuy(), VOTE_AMOUNT);
    }

    function testRevertRelease_nonContest() public {
        _initialize();

        vm.prank(voter0());
        vm.expectRevert("Only contest");
        pointsModule().releasePoints(voter0(), VOTE_AMOUNT);

        vm.expectRevert("Only contest");
        vm.prank(someGuy());
        pointsModule().releasePoints(voter0(), VOTE_AMOUNT);
    }

    function testRevertRelease_nonZero() public {
        _initialize();

        vm.expectRevert("Amount must be greater than 0");
        pointsModule().releasePoints(voter0(), 0);
    }

    function testRevertRelease_insufficient() public {
        _initialize();

        vm.expectRevert("Insufficient points allocated");
        pointsModule().releasePoints(voter0(), VOTE_AMOUNT + 1);

        vm.expectRevert("Insufficient points allocated");
        pointsModule().releasePoints(someGuy(), VOTE_AMOUNT);
    }

    function testRevertClaimPoints() public {
        _initialize();

        vm.expectRevert("This contract does not require users to claim points.");
        pointsModule().claimPoints();
    }

    function testRevertAllocate_doublespend() public {
        _initialize();

        pointsModule().allocatePoints(voter0(), VOTE_AMOUNT);

        vm.expectRevert("Insufficient points available");
        pointsModule().allocatePoints(voter0(), VOTE_AMOUNT);
    }

    function testRevertAllocate_doublespend_transfer() public {
        _initialize();

        pointsModule().allocatePoints(voter0(), VOTE_AMOUNT);

        vm.expectRevert("SBT: Transfers are not allowed");
        vm.startPrank(voter0());
        voteToken().transfer(someGuy(), VOTE_AMOUNT);
        vm.stopPrank();
    }

    //////////////////////////////
    // Getters
    //////////////////////////////

    function test_getAllocatedPoints() public {
        _initialize();

        for (uint256 i = 0; i < _voters.length; i++) {
            uint256 allocatedPoints = pointsModule().getAllocatedPoints(_voters[i]);
            assertEq(allocatedPoints, 0);

            pointsModule().allocatePoints(_voters[i], VOTE_AMOUNT);
            allocatedPoints = pointsModule().getAllocatedPoints(_voters[i]);
            assertEq(allocatedPoints, VOTE_AMOUNT);
        }
    }

    function test_getPoints() public {
        _initialize();

        for (uint256 i = 0; i < _voters.length; i++) {
            uint256 points = pointsModule().getPoints(_voters[i]);
            assertEq(points, VOTE_AMOUNT);

            pointsModule().allocatePoints(_voters[i], VOTE_AMOUNT);
            points = pointsModule().getPoints(_voters[i]);
            assertEq(points, 0);
        }
    }

    function test_hasVotingPoints() public {
        _initialize();

        for (uint256 i = 0; i < _voters.length; i++) {
            bool hasPoints = pointsModule().hasVotingPoints(_voters[i], VOTE_AMOUNT);
            assertTrue(hasPoints);

            pointsModule().allocatePoints(_voters[i], VOTE_AMOUNT);
            hasPoints = pointsModule().hasVotingPoints(_voters[i], VOTE_AMOUNT);
            assertFalse(hasPoints);
        }
    }

    //////////////////////////////
    // Helpers
    //////////////////////////////

    function _releasePoints(uint256 _voter) internal {
        _allocatePoints(_voter);

        vm.expectEmit(true, false, false, true);
        emit PointsReleased(_voters[_voter], VOTE_AMOUNT);

        pointsModule().releasePoints(_voters[_voter], VOTE_AMOUNT);
    }

    function _allocatePoints(uint256 _voter) internal {
        _initialize();
        vm.expectEmit(true, false, false, true);
        emit PointsAllocated(_voters[_voter], VOTE_AMOUNT);

        pointsModule().allocatePoints(_voters[_voter], VOTE_AMOUNT);
    }

    function _initialize() internal {
        bytes memory initData = abi.encode(address(voteToken()));

        pointsModule().initialize(address(this), initData);
    }

    function _airdrop() internal {
        // mint tokens to voters

        _voters.push(voter0());
        _voters.push(voter1());
        _voters.push(voter2());

        vm.startPrank(sbtMinter());

        for (uint256 i = 0; i < _voters.length;) {
            voteToken().mint(_voters[i], VOTE_AMOUNT);

            unchecked {
                i++;
            }
        }
        vm.stopPrank();
    }

    function _setupToken() internal {
        _voteToken = new GSVotingToken("GSVoting", "GSV", 0, sbtMinter());

        voteToken().transferOwnership(sbtMinter());

        _airdrop();
    }

    function voteToken() internal view returns (GSVotingToken) {
        return _voteToken;
    }

    function pointsModule() internal view returns (SBTBalancePoints) {
        return _pointsModule;
    }
}
