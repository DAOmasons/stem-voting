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
        vm.stopPrank();

        _mintTime = block.timestamp;

        vm.warp(_mintTime + ONE_HOUR);
    }

    function test_delegatedWeights() public {
        for (uint256 i = 0; i < _voters.length; i++) {
            assertEq(shares().balanceOf(_voters[i]), voteAmount);
            assertEq(shares().getPastVotes(_voters[i], block.timestamp - 1), voteAmount);
        }

        // A voter who gets voting power after shouldn't be have a balance, but not past votes

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
}
