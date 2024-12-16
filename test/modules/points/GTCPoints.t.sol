// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Accounts} from "../../setup/Accounts.t.sol";
import {GTCTokenPoints} from "../../../src/modules/points/GTCTokenPoints.sol";
import {GTCTokenSetup} from "../../setup/GTCSetup.t.sol";

contract GTCPointsTest is Test, Accounts, GTCTokenSetup {
    uint256 constant START_BLOCK = 285113002;
    uint256 constant DELEGATE_BLOCK = START_BLOCK + 10;
    uint256 constant VOTE_BLOCK = DELEGATE_BLOCK + 20;
    uint256 constant SNAPSHOT_BLOCK = DELEGATE_BLOCK + 15;
    uint256 constant TWO_WEEKS = 1209600;

    uint256 constant VOTE_AMOUNT = 1_000e18;

    address[] _voters;

    function setUp() public {
        vm.createSelectFork({blockNumber: START_BLOCK, urlOrAlias: "arbitrumOne"});
        __setupGTCToken();
        _airdrop();
        _delegateVotes();
    }

    function test() public {}

    function _delegateVotes() internal {
        vm.roll(DELEGATE_BLOCK);
        for (uint256 i = 0; i < _voters.length;) {
            vm.prank(_voters[i]);
            gtcToken().delegate(_voters[i]);

            unchecked {
                i++;
            }
        }
        vm.roll(VOTE_BLOCK);
    }

    function _airdrop() public {
        _voters.push(voter0());
        _voters.push(voter1());
        _voters.push(voter2());
        _voters.push(voter3());
        _voters.push(voter4());

        vm.startPrank(gtcWhale());

        for (uint256 i = 0; i < _voters.length;) {
            gtcToken().transfer(_voters[i], VOTE_AMOUNT);

            unchecked {
                i++;
            }
        }

        vm.stopPrank();
    }
}
