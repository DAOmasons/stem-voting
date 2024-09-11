// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {ARBTokenSetupLive} from "../../setup/VotesTokenSetup.t.sol";
import {BaalPointsV0} from "../../../src/modules/points/BaalPoints.sol";
import {Accounts} from "../../setup/Accounts.t.sol";
import {BaalSetupLive} from "../../setup/BaalSetup.t.sol";

import {HolderType} from "../../../src/core/BaalUtils.sol";

contract BaalPointsV0Test is Test, BaalSetupLive, Accounts {
    event Initialized(
        address contest, address dao, address sharesToken, address lootToken, uint256 checkpoint, HolderType holderType
    );
    event PointsAllocated(address indexed user, uint256 amount);
    event PointsReleased(address indexed user, uint256 amount);

    error InvalidInitialization();

    address[] _voters;

    uint256 _mintTime;
    uint256 _voteTime;

    uint256 constant ONE_HOUR = 3600;

    BaalPointsV0 pointsModule;

    uint256 voteAmount = 1_000e18;

    function setUp() public {
        vm.createSelectFork({blockNumber: 6668489, urlOrAlias: "sepolia"});

        __setUpBaalWithNewToken();
        _setupVoters();

        pointsModule = new BaalPointsV0();
    }

    function test_delegatedWeights() public {
        for (uint256 i = 0; i < _voters.length; i++) {
            assertEq(shares().balanceOf(_voters[i]), voteAmount);
            assertEq(shares().getPastVotes(_voters[i], block.timestamp - 1), voteAmount);

            assertEq(loot().balanceOf(_voters[i]), voteAmount);
            assertEq(loot().getPastVotes(_voters[i], block.timestamp - 1), voteAmount);
        }
    }

    //////////////////////////////
    // Unit Tests
    //////////////////////////////

    function test_initialize_shares() public {
        _initialize_shares();

        assertEq(address(dao()), address(pointsModule.dao()));
        assertEq(address(shares()), address(pointsModule.sharesToken()));
        assertEq(address(loot()), address(pointsModule.lootToken()));
        assertEq(pointsModule.checkpoint(), block.timestamp - 1);
        assertEq(address(this), address(pointsModule.contest()));
        assertEq(uint8(HolderType.Share), uint8(pointsModule.holderType()));
    }

    function test_initialize_loot() public {
        _initialize_loot();

        assertEq(address(dao()), address(pointsModule.dao()));
        assertEq(address(shares()), address(pointsModule.sharesToken()));
        assertEq(address(loot()), address(pointsModule.lootToken()));
        assertEq(pointsModule.checkpoint(), block.timestamp - 1);
        assertEq(address(this), address(pointsModule.contest()));
        assertEq(uint8(HolderType.Loot), uint8(pointsModule.holderType()));
    }

    function test_initialize_both() public {
        _initialize_both();

        assertEq(address(dao()), address(pointsModule.dao()));
        assertEq(address(shares()), address(pointsModule.sharesToken()));
        assertEq(address(loot()), address(pointsModule.lootToken()));
        assertEq(pointsModule.checkpoint(), block.timestamp - 1);
        assertEq(address(this), address(pointsModule.contest()));
        assertEq(uint8(HolderType.Both), uint8(pointsModule.holderType()));
    }

    function test_allocate_shares() public {
        _initialize_shares();
        _allocate(voter1(), voteAmount);

        assertEq(pointsModule.allocatedPoints(voter1()), voteAmount);
    }

    function test_allocate_loot() public {
        _initialize_loot();
        _allocate(voter1(), voteAmount);

        assertEq(pointsModule.allocatedPoints(voter1()), voteAmount);
    }

    function test_allocate_both() public {
        _initialize_both();
        _allocate(voter1(), voteAmount * 2);

        assertEq(pointsModule.allocatedPoints(voter1()), voteAmount * 2);
    }

    function test_release_shares() public {
        _initialize_shares();
        _allocate(voter1(), voteAmount);
        _release(voter1(), voteAmount / 2);

        assertEq(pointsModule.allocatedPoints(voter1()), voteAmount / 2);

        _release(voter1(), voteAmount / 2);
        assertEq(pointsModule.allocatedPoints(voter1()), 0);
    }

    function test_release_loot() public {
        _initialize_loot();
        _allocate(voter1(), voteAmount);
        _release(voter1(), voteAmount / 2);

        assertEq(pointsModule.allocatedPoints(voter1()), voteAmount / 2);

        _release(voter1(), voteAmount / 2);
        assertEq(pointsModule.allocatedPoints(voter1()), 0);
    }

    function test_release_both() public {
        _initialize_both();
        _allocate(voter1(), voteAmount * 2);
        _release(voter1(), voteAmount);

        assertEq(pointsModule.allocatedPoints(voter1()), voteAmount);

        _release(voter1(), voteAmount);

        assertEq(pointsModule.allocatedPoints(voter1()), 0);
    }

    //////////////////////////////
    // Reverts
    //////////////////////////////

    function testRevert_init_twice() public {
        _initialize_both();

        vm.expectRevert(InvalidInitialization.selector);

        bytes memory data = abi.encode(address(dao()), block.timestamp - 1, HolderType.Both);
        pointsModule.initialize(address(this), data);
    }

    function testRevert_init_nonZero_contest() public {
        bytes memory data = abi.encode(address(dao()), block.timestamp - 1, HolderType.Both);

        vm.expectRevert("Invalid contest address");
        pointsModule.initialize(address(0), data);
    }

    function testRevert_init_nonZero_daoAddress() public {
        bytes memory data = abi.encode(address(0), block.timestamp - 1, HolderType.Both);

        vm.expectRevert("Invalid DAO address");
        pointsModule.initialize(address(this), data);
    }

    function testRevert_init_nonZero_holderType() public {
        bytes memory data = abi.encode(address(this), block.timestamp - 1, HolderType.None);

        vm.expectRevert("Invalid holder type");
        pointsModule.initialize(address(this), data);
    }

    function testRevert_allocate_nonZero() public {
        _initialize_both();

        vm.expectRevert("Amount must be greater than 0");
        pointsModule.allocatePoints(voter1(), 0, "");
    }

    function testRevert_allocate_notContest() public {
        _initialize_both();

        vm.expectRevert("Only contest");

        vm.prank(someGuy());
        pointsModule.allocatePoints(voter1(), voteAmount, "");
    }

    function testRevert_release_notContest() public {
        _initialize_both();

        vm.expectRevert("Only contest");

        vm.prank(someGuy());
        pointsModule.releasePoints(voter1(), voteAmount, "");
    }

    function testRevert_allocate_insufficient_shares() public {
        _initialize_shares();

        vm.expectRevert("Insufficient points available");
        pointsModule.allocatePoints(voter1(), voteAmount + 1, "");
    }

    function testRevert_allocate_insufficient_loot() public {
        _initialize_loot();

        vm.expectRevert("Insufficient points available");
        pointsModule.allocatePoints(voter1(), voteAmount + 1, "");
    }

    function testRevert_allocate_insufficient_both() public {
        _initialize_both();

        vm.expectRevert("Insufficient points available");
        pointsModule.allocatePoints(voter1(), voteAmount * 2 + 1, "");
    }

    function testRevert_release_nonZero() public {
        _initialize_both();

        vm.expectRevert("Amount must be greater than 0");
        pointsModule.releasePoints(voter1(), 0, "");
    }

    function testRevert_release_insufficient() public {
        _initialize_both();

        vm.expectRevert("Insufficient points allocated");
        pointsModule.releasePoints(voter1(), 1, "");

        _allocate(voter1(), voteAmount * 2);

        vm.expectRevert("Insufficient points allocated");
        pointsModule.releasePoints(voter1(), voteAmount * 2 + 1, "");
    }

    //////////////////////////////
    // Getters
    //////////////////////////////

    function testGetPoints_both() public {
        _initialize_both();

        assertEq(pointsModule.getPoints(voter1()), voteAmount * 2);
    }

    function testGetPoints_shares() public {
        _initialize_shares();

        assertEq(pointsModule.getPoints(voter1()), voteAmount);
    }

    function testGetPoints_loot() public {
        _initialize_loot();

        assertEq(pointsModule.getPoints(voter1()), voteAmount);
    }

    //////////////////////////////
    // New Token test
    //////////////////////////////

    function test_weights_within_snapshot() public {
        address[] memory newVoters = new address[](1);
        uint256[] memory balances = new uint256[](1);

        newVoters[0] = voter3();
        balances[0] = voteAmount;

        address avatar = dao().avatar();

        vm.startPrank(avatar);
        dao().mintShares(newVoters, balances);
        vm.stopPrank();

        assertEq(shares().balanceOf(voter3()), voteAmount);
        assertEq(shares().getPastVotes(voter3(), block.timestamp - 1), 0);

        // some random guy shouldn't have any voting power
        assertEq(shares().getPastVotes(someGuy(), block.timestamp - 1), 0);

        // but if we jump ahead voter3 should have voting power

        vm.warp(block.timestamp + ONE_HOUR);

        assertEq(shares().getPastVotes(voter3(), block.timestamp - 1), voteAmount);
    }

    //////////////////////////////
    // Helpers
    //////////////////////////////

    function _release(address _voter, uint256 _amount) internal {
        vm.expectEmit(true, false, false, true);

        emit PointsReleased(_voter, _amount);
        pointsModule.releasePoints(_voter, _amount, "");
    }

    function _allocate(address _voter, uint256 _amount) internal {
        vm.expectEmit(true, false, false, true);
        emit PointsAllocated(_voter, _amount);
        pointsModule.allocatePoints(_voter, _amount, "");
    }

    function _initialize_shares() internal {
        vm.expectEmit(true, false, false, true);

        emit Initialized(
            address(this), address(dao()), address(shares()), address(loot()), block.timestamp - 1, HolderType.Share
        );

        bytes memory data = abi.encode(address(dao()), block.timestamp - 1, HolderType.Share);

        pointsModule.initialize(address(this), data);
    }

    function _initialize_loot() internal {
        vm.expectEmit(true, false, false, true);

        emit Initialized(
            address(this), address(dao()), address(shares()), address(loot()), block.timestamp - 1, HolderType.Loot
        );

        bytes memory data = abi.encode(address(dao()), block.timestamp - 1, HolderType.Loot);

        pointsModule.initialize(address(this), data);
    }

    function _initialize_both() internal {
        vm.expectEmit(true, false, false, true);

        emit Initialized(
            address(this), address(dao()), address(shares()), address(loot()), block.timestamp - 1, HolderType.Both
        );

        bytes memory data = abi.encode(address(dao()), block.timestamp - 1, HolderType.Both);

        pointsModule.initialize(address(this), data);
    }

    function _setupVoters() public {
        _voters = new address[](3);

        _voters[0] = voter0();
        _voters[1] = voter1();
        _voters[2] = voter2();

        uint256[] memory balances = new uint256[](3);

        balances[0] = voteAmount;
        balances[1] = voteAmount;
        balances[2] = voteAmount;

        address avatar = dao().avatar();

        vm.startPrank(avatar);
        dao().mintShares(_voters, balances);
        dao().mintLoot(_voters, balances);
        vm.stopPrank();

        _mintTime = block.timestamp;

        vm.warp(_mintTime + ONE_HOUR);
    }
}
