// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ARBTokenSetupLive} from "../../setup/VotesTokenSetup.t.sol";
import {ContextPointsV0} from "../../../src/modules/points/ContextPoints.sol";
import {Accounts} from "../../setup/Accounts.t.sol";
import {BaalSetupLive} from "../../setup/BaalSetup.t.sol";
import {Metadata} from "../../../src/core/Metadata.sol";

contract ContextPointsV0Test is Test, ARBTokenSetupLive, BaalSetupLive, Accounts {
    event Initialized(address contest, address token, uint256 votingCheckpoint);
    event PointsAllocated(address indexed user, uint256 amount, address token);
    event PointsReleased(address indexed user, uint256 amount, address token);

    address[] _voters;

    uint256 startBlock = 208213640;
    uint256 delegateBlock = startBlock + 10;
    uint256 snapshotBlock = delegateBlock + 15;
    uint256 voteBlock = delegateBlock + 20;

    uint256 daoTokenAmount = 700e18;
    uint256 contextTokenAmount = 300e18;

    uint256 voteAmount = 1_000e18;

    ContextPointsV0 public pointsModule;

    Metadata _metadata = Metadata(1, "reason");

    function setUp() public {
        vm.createSelectFork({blockNumber: startBlock, urlOrAlias: "arbitrumOne"});
        __setupArbToken();
        __setUpBaal();

        pointsModule = new ContextPointsV0();
    }

    //////////////////////////////
    // Token Setup Tests
    //////////////////////////////

    function test_pre_setup() public view {
        uint256 whaleBalance = arbToken().balanceOf(arbWhale());

        assertEq(arbToken().symbol(), "ARB");
        assertEq(arbToken().decimals(), 18);

        assertEq(whaleBalance, 83_315_716_895924118689251310);
    }

    //////////////////////////////
    // Base Functionality Tests
    //////////////////////////////

    function test_initialize() public {
        _initialize();

        assertEq(pointsModule.contest(), address(this));
        assertEq(pointsModule.votingCheckpoint(), snapshotBlock);
        assertEq(address(pointsModule.daoToken()), address(arbToken()));
        assertEq(address(pointsModule.contextToken()), address(loot()));
    }

    function test_allocatePoints_context_total() public {
        _allocatePoints(0, contextTokenAmount, address(loot()));

        uint256 allocatedContextPoints = pointsModule.contextPoints(_voters[0]);
        uint256 allocatedDaoPoints = pointsModule.daoTokenPoints(_voters[0]);

        bytes memory _contextData = abi.encode(_metadata, address(loot()));
        bytes memory _daoData = abi.encode(_metadata, address(arbToken()));

        bool hasContextPointsLeft = pointsModule.hasVotingPoints(_voters[0], 1, _contextData);
        bool hasDaoPointsLeft = pointsModule.hasVotingPoints(_voters[0], 1, _daoData);

        assertEq(allocatedContextPoints, contextTokenAmount);
        assertEq(allocatedDaoPoints, 0);

        assertFalse(hasContextPointsLeft);
        assertTrue(hasDaoPointsLeft);
    }

    function test_allocatePoints_dao_total() public {
        _allocatePoints(0, daoTokenAmount, address(arbToken()));

        uint256 allocatedDaoPoints = pointsModule.daoTokenPoints(_voters[0]);
        uint256 allocatedContextPoints = pointsModule.contextPoints(_voters[0]);

        bytes memory _daoData = abi.encode(_metadata, address(arbToken()));
        bytes memory _contextData = abi.encode(_metadata, address(loot()));

        bool hasDaoPointsLeft = pointsModule.hasVotingPoints(_voters[0], 1, _daoData);
        bool hasContextPointsLeft = pointsModule.hasVotingPoints(_voters[0], 1, _contextData);

        assertEq(allocatedDaoPoints, daoTokenAmount);
        assertEq(allocatedContextPoints, 0);

        assertFalse(hasDaoPointsLeft);
        assertTrue(hasContextPointsLeft);
    }

    function test_allocatePoints_context_partial() public {
        _allocatePoints(0, contextTokenAmount / 2, address(loot()));

        uint256 allocatedContextPoints = pointsModule.contextPoints(_voters[0]);
        uint256 allocatedDaoPoints = pointsModule.daoTokenPoints(_voters[0]);

        bytes memory _contextData = abi.encode(_metadata, address(loot()));
        bytes memory _daoData = abi.encode(_metadata, address(arbToken()));

        bool hasContextPointsLeft = pointsModule.hasVotingPoints(_voters[0], 1, _contextData);
        bool hasDaoPointsLeft = pointsModule.hasVotingPoints(_voters[0], 0, _daoData);

        assertEq(allocatedContextPoints, contextTokenAmount / 2);
        assertEq(allocatedDaoPoints, 0);

        assertTrue(hasContextPointsLeft);
        assertTrue(hasDaoPointsLeft);
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
            _arbToken.transfer(_voters[i], daoTokenAmount);

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
        _setupContextVotes();
    }

    function _setupContextVotes() internal {
        address[] memory voters = new address[](3);

        voters[0] = voter0();
        voters[1] = voter1();
        voters[2] = voter2();

        address daoAvatar = dao().avatar();

        uint256[] memory amounts = new uint256[](voters.length);

        for (uint256 i = 0; i < voters.length; i++) {
            amounts[i] = contextTokenAmount;
        }

        vm.startPrank(daoAvatar);
        dao().mintLoot(voters, amounts);
        vm.stopPrank();
    }

    function _initialize() internal {
        _setupVotes();
        bytes memory initData = abi.encode(address(arbToken()), address(loot()), snapshotBlock);

        pointsModule.initialize(address(this), initData);
    }

    function _allocatePoints_contextToken(uint256 _voter) internal {
        _initialize();
        vm.expectEmit(true, false, false, true);

        bytes memory _data = abi.encode(_metadata, address(loot()));

        emit PointsAllocated(_voters[_voter], contextTokenAmount, address(loot()));
        pointsModule.allocatePoints(_voters[_voter], contextTokenAmount, _data);
    }

    function _allocatePoints(uint256 _voter, uint256 _amount, address _token) internal {
        _initialize();
        vm.expectEmit(true, false, false, true);

        bytes memory _data = abi.encode(_metadata, _token);

        emit PointsAllocated(_voters[_voter], _amount, _token);
        pointsModule.allocatePoints(_voters[_voter], _amount, _data);
    }

    // function _releasePoints(uint256 _voter) internal {
    //     _allocatePoints(_voter);

    //     vm.expectEmit(true, false, false, true);
    //     emit PointsReleased(_voters[_voter], voteAmount);

    //     pointsModule.releasePoints(_voters[_voter], voteAmount, "");
    // }
}
