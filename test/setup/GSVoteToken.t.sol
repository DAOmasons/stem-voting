// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Test, console} from "forge-std/Test.sol";
import {Accounts} from "./Accounts.t.sol";
import {GSVotingToken} from "../../src/factories/gsRough/GSVoteToken.sol";

contract GSVoteTokenTest is Test, Accounts {
    GSVotingToken internal _voteToken;
    uint256 internal constant VOTE_AMOUNT = 1_000e18;
    uint256 internal constant SUPPLY_AT_SETUP = 24_000e18;

    function setUp() public {
        setupLocal();
    }

    function testSetup() public {
        assertEq(voteToken().name(), "GSVoting");
        assertEq(voteToken().symbol(), "GSV");
        assertEq(voteToken().decimals(), 18);
        assertEq(voteToken().totalSupply(), SUPPLY_AT_SETUP);

        assertEq(voteToken().owner(), admin1());

        assertEq(voteToken().balanceOf(voter0()), VOTE_AMOUNT);
        assertEq(voteToken().balanceOf(voter1()), VOTE_AMOUNT * 2);
        assertEq(voteToken().balanceOf(voter2()), VOTE_AMOUNT * 3);
        assertEq(voteToken().balanceOf(voter3()), VOTE_AMOUNT);
        assertEq(voteToken().balanceOf(voter4()), VOTE_AMOUNT * 4);
        assertEq(voteToken().balanceOf(voter5()), VOTE_AMOUNT);
        assertEq(voteToken().balanceOf(voter6()), VOTE_AMOUNT * 7);
        assertEq(voteToken().balanceOf(voter7()), VOTE_AMOUNT);
        assertEq(voteToken().balanceOf(voter8()), VOTE_AMOUNT);
        assertEq(voteToken().balanceOf(voter9()), VOTE_AMOUNT * 3);
    }

    function testBurn() public {
        vm.startPrank(admin1());
        voteToken().burn(voter0(), VOTE_AMOUNT);
        vm.stopPrank();

        assertEq(voteToken().balanceOf(voter0()), 0);
        assertEq(voteToken().totalSupply(), SUPPLY_AT_SETUP - VOTE_AMOUNT);
    }

    function testRevert_unauthorized() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.startPrank(voter0());
        voteToken().burn(voter0(), VOTE_AMOUNT);
        vm.stopPrank();

        vm.expectRevert("Ownable: caller is not the owner");

        vm.startPrank(voter0());
        voteToken().mint(voter0(), VOTE_AMOUNT);
        vm.stopPrank();

        vm.expectRevert("Ownable: caller is not the owner");

        vm.startPrank(someGuy());
        voteToken().mint(someGuy(), VOTE_AMOUNT);
        vm.stopPrank();
    }

    function testRevert_transfer_noTransfer() public {
        vm.expectRevert("SBT: Transfers are not allowed");
        voteToken().transfer(voter1(), VOTE_AMOUNT);

        vm.expectRevert("SBT: Transfers are not allowed");
        vm.startPrank(voter0());
        voteToken().transfer(voter1(), VOTE_AMOUNT);
        vm.stopPrank();
    }

    function testRevert_transferFrom_noTransfer() public {
        vm.expectRevert("SBT: Transfers are not allowed");
        voteToken().transferFrom(voter0(), voter1(), VOTE_AMOUNT);

        vm.expectRevert("SBT: Transfers are not allowed");
        vm.startPrank(voter0());
        voteToken().transferFrom(voter0(), voter1(), VOTE_AMOUNT);
        vm.stopPrank();
    }

    function voteToken() public view returns (GSVotingToken) {
        return _voteToken;
    }

    function setupLocal() public {
        // deploy token
        _voteToken = new GSVotingToken("GSVoting", "GSV", 0, admin1());
        // transfer ownership to admin1
        voteToken().transferOwnership(admin1());

        // mint some tokens

        vm.startPrank(admin1());
        voteToken().mint(voter0(), VOTE_AMOUNT);
        voteToken().mint(voter1(), VOTE_AMOUNT * 2);
        voteToken().mint(voter2(), VOTE_AMOUNT * 3);
        voteToken().mint(voter3(), VOTE_AMOUNT);
        voteToken().mint(voter4(), VOTE_AMOUNT * 4);
        voteToken().mint(voter5(), VOTE_AMOUNT);
        voteToken().mint(voter6(), VOTE_AMOUNT * 7);
        voteToken().mint(voter7(), VOTE_AMOUNT);
        voteToken().mint(voter8(), VOTE_AMOUNT);
        voteToken().mint(voter9(), VOTE_AMOUNT * 3);
        vm.stopPrank();
    }
}
