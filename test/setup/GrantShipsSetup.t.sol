// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {HatsSetup} from "./hatsSetup.t.sol";
import {ARBTokenSetupLive} from "./VotesTokenSetup.t.sol";

import {ERC20VotesPoints} from "../../src/modules/points/ERC20VotesPoints.sol";
import {CheckpointVoting} from "../../src/modules/votes/CheckpointVotes.sol";
import {HatsAllowList} from "../../src/modules/choices/HatsAllowList.sol";
import {Contest} from "../../src/Contest.sol";

contract GrantShipsSetup is HatsSetup, ARBTokenSetupLive {
    address[] _voters;
    uint256 constant VOTE_AMOUNT = 1_000e18;

    uint256 constant START_BLOCK = 208213640;
    uint256 constant DELEGATE_BLOCK = START_BLOCK + 10;
    uint256 constant SNAPSHOT_BLOCK = DELEGATE_BLOCK + 15;
    uint256 constant VOTE_BLOCK = DELEGATE_BLOCK + 20;

    ERC20VotesPoints _pointsModule;
    CheckpointVoting _votesModule;
    HatsAllowList _choiceModule;
    Contest _contest;

    function __setupGrantShips() internal {
        __setupHats();
        __setupArbToken();
        _setupVoters();

        _choiceModule = new HatsAllowList();
        _pointsModule = new ERC20VotesPoints();
        _votesModule = new CheckpointVoting();
        _contest = new Contest();

        _rawDog_init();
    }

    function _setupVoters() internal {
        _airdrop();
        _delegateVotes();
    }

    function _airdrop() internal {
        _voters.push(voter0());
        _voters.push(voter1());
        _voters.push(voter2());
        _voters.push(voter3());
        _voters.push(voter4());

        vm.startPrank(arbWhale());

        for (uint256 i = 0; i < _voters.length;) {
            _arbToken.transfer(_voters[i], VOTE_AMOUNT);

            unchecked {
                i++;
            }
        }

        vm.stopPrank();
    }

    function _delegateVotes() internal {
        vm.roll(DELEGATE_BLOCK);
        for (uint256 i = 0; i < _voters.length;) {
            vm.prank(_voters[i]);
            _arbToken.delegate(_voters[i]);

            unchecked {
                i++;
            }
        }
        vm.roll(VOTE_BLOCK);
    }

    function _rawDog_init() public {}
}
