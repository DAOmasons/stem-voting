// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ARBTokenSetupLive} from "../../setup/VotesTokenSetup.sol";
import {ERC20VotesPoints} from "../../../src/modules/points/ERC20VotesPoints.sol";

contract ERC20VotesPointsTest is Test, ARBTokenSetupLive {
    address[] _voters;

    uint256 startBlock = 208213640;
    uint256 delegateBlock = startBlock + 10;
    uint256 snapshotBlock = delegateBlock + 15;
    uint256 voteBlock = delegateBlock + 20;

    uint256 voteAmount = 1_000e18;

    ERC20VotesPoints pointsModule;

    // uint256

    function setUp() public {
        vm.createSelectFork({blockNumber: startBlock, urlOrAlias: "arbitrumOne"});
        __setupArbToken();

        pointsModule = new ERC20VotesPoints();
    }

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

    function test_initialize() public {
        _initialize();

        assertEq(address(pointsModule.voteToken()), address(arbToken()));
        assertEq(pointsModule.votingCheckpoint(), snapshotBlock);
        assertEq(pointsModule.contest(), address(this));
    }

    function test_allocatePoints_total() public {
        _allocatePoints(0);

        uint256 allocatedPoints = pointsModule.getAllocatedPoints(_voters[0]);
        assertEq(allocatedPoints, voteAmount);
    }

    function test_allocatePoints_partial() public {
        _initialize();

        pointsModule.allocatePoints(_voters[0], voteAmount / 2);

        uint256 allocatedPoints = pointsModule.getAllocatedPoints(_voters[0]);
        assertEq(allocatedPoints, voteAmount / 2);

        pointsModule.allocatePoints(_voters[0], voteAmount / 2);

        allocatedPoints = pointsModule.getAllocatedPoints(_voters[0]);

        assertEq(allocatedPoints, voteAmount);
    }

    // function test_getAllocatedPoints() public {
    //     _initialize();

    //     for (uint256 i = 0; i < _voters.length; i++) {
    //         uint256 allocatedPoints = pointsModule.getAllocatedPoints(_voters[i]);
    //         assertEq(allocatedPoints, 0);
    //     }
    // }

    function _airdrop() internal {
        _voters.push(voter0());
        _voters.push(voter1());
        _voters.push(voter2());

        vm.startPrank(arbWhale());

        for (uint256 i = 0; i < _voters.length;) {
            _arbToken.approve(_voters[i], voteAmount);
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

        pointsModule.allocatePoints(_voters[_voter], voteAmount);
    }
}
