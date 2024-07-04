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
