// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {HatsSetup} from "./hatsSetup.t.sol";
import {console} from "forge-std/Test.sol";

import {ARBTokenSetupLive} from "./VotesTokenSetup.t.sol";

import {ERC20VotesPoints} from "../../src/modules/points/ERC20VotesPoints.sol";
import {TimedVotes} from "../../src/modules/votes/TimedVotes.sol";
import {HatsAllowList} from "../../src/modules/choices/HatsAllowList.sol";
import {Contest} from "../../src/Contest.sol";

contract GrantShipsSetup is HatsSetup, ARBTokenSetupLive {
    address[] _voters;
    uint256 constant VOTE_AMOUNT = 1_000e18;

    uint256 constant START_BLOCK = 208213640;
    uint256 constant DELEGATE_BLOCK = START_BLOCK + 10;
    uint256 constant SNAPSHOT_BLOCK = DELEGATE_BLOCK + 15;
    uint256 constant VOTE_BLOCK = DELEGATE_BLOCK + 20;
    uint256 constant TWO_WEEKS = 1209600;

    address signalOnly = makeAddr("signal-only");

    ERC20VotesPoints _pointsModule;
    TimedVotes _votesModule;
    HatsAllowList _choiceModule;
    Contest _contest;

    function __setupGrantShips() internal {
        vm.createSelectFork({blockNumber: START_BLOCK, urlOrAlias: "arbitrumOne"});
        __setupHats();
        __setupArbToken();
        _setupVoters();

        _choiceModule = new HatsAllowList();
        _pointsModule = new ERC20VotesPoints();
        _votesModule = new TimedVotes();
        _contest = new Contest();

        // ensure fork block number is synchronized with test environment block number
        assertEq(block.number, VOTE_BLOCK);

        // setup modules & contest without factory pattern
        __rawDog_init_contest();
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

    function __rawDog_init_contest() public {
        // setup choice module
        bytes memory _choiceInitData = abi.encode(address(hats()), facilitator1().id, new bytes[](0));
        choicesModule().initialize(address(contest()), _choiceInitData);

        // setup points module
        bytes memory _pointsInitData = abi.encode(address(arbToken()), SNAPSHOT_BLOCK);
        pointsModule().initialize(address(contest()), _pointsInitData);

        // setup votes module
        bytes memory _votesInitData = abi.encode(TWO_WEEKS);
        votesModule().initialize(address(contest()), _votesInitData);

        // // setup contest
        bytes memory _contestInitData = abi.encode(
            address(votesModule()), address(pointsModule()), address(choicesModule()), signalOnly, false, false
        );

        contest().initialize(_contestInitData);
    }

    function choicesModule() public view returns (HatsAllowList) {
        return _choiceModule;
    }

    function pointsModule() public view returns (ERC20VotesPoints) {
        return _pointsModule;
    }

    function votesModule() public view returns (TimedVotes) {
        return _votesModule;
    }

    function contest() public view returns (Contest) {
        return _contest;
    }

    function arbVoter(uint256 _index) public view returns (address) {
        return _voters[_index];
    }
}
