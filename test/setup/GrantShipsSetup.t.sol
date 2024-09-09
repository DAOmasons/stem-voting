// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {HatsSetup} from "./hatsSetup.t.sol";
import {console} from "forge-std/Test.sol";

import {ARBTokenSetupLive} from "./VotesTokenSetup.t.sol";

import {ERC20VotesPoints} from "../../src/modules/points/ERC20VotesPoints.sol";
import {TimedVotes} from "../../src/modules/votes/TimedVotes.sol";
import {HatsAllowList} from "../../src/modules/choices/HatsAllowList.sol";
import {Contest} from "../../src/Contest.sol";
import {ContestStatus} from "../../src/core/ContestStatus.sol";
import {FastFactory} from "../../src/factories/gsRough/FastFactory.sol";
import {Metadata} from "../../src/core/Metadata.sol";
import {EmptyExecution} from "../../src/modules/execution/EmptyExecution.sol";

contract GrantShipsSetup is HatsSetup, ARBTokenSetupLive {
    event ContestInitialized(
        address votesModule,
        address pointsModule,
        address choicesModule,
        address executionModule,
        bool isContinuous,
        bool isRetractable,
        ContestStatus status
    );

    address[] _voters;
    uint256 constant VOTE_AMOUNT = 1_000e18;

    uint256 constant START_BLOCK = 208213640;
    uint256 constant DELEGATE_BLOCK = START_BLOCK + 10;
    uint256 constant SNAPSHOT_BLOCK = DELEGATE_BLOCK + 15;
    uint256 constant VOTE_BLOCK = DELEGATE_BLOCK + 20;
    uint256 constant TWO_WEEKS = 1209600;

    ERC20VotesPoints _pointsModule;
    TimedVotes _votesModule;
    HatsAllowList _choiceModule;
    Contest _contest;
    EmptyExecution _executionModule;
    FastFactory _factory;
    Metadata _mockMetadata = Metadata(1, "qm....");

    function __setupGrantShipsBasic() internal {
        vm.createSelectFork({blockNumber: START_BLOCK, urlOrAlias: "arbitrumOne"});
        __setupHats();
        __setupArbToken();
        _setupVoters();

        // ensure fork block number is synchronized with test environment block number
        assertEq(block.number, VOTE_BLOCK);

        __fastFactory_init_contest();
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

    function _fastFactory_setup() public {
        vm.startPrank(stemAdmin1());
        _factory = new FastFactory(stemAdmin1());

        factory().addAdmin(stemAdmin2());

        Contest _contestImpl = new Contest();
        ERC20VotesPoints _pointsImpl = new ERC20VotesPoints();
        TimedVotes _votesImpl = new TimedVotes();
        HatsAllowList _choicesImpl = new HatsAllowList();
        EmptyExecution _executionImpl = new EmptyExecution();

        factory().setContestTemplate("v0.1.0", address(_contestImpl), _mockMetadata);
        factory().setModuleTemplate("ERC20VotesPoints_v0.1.0", address(_pointsImpl), _mockMetadata);
        factory().setModuleTemplate("TimedVotes_v0.1.0", address(_votesImpl), _mockMetadata);
        factory().setModuleTemplate("HatsAllowList_v0.1.0", address(_choicesImpl), _mockMetadata);
        factory().setModuleTemplate("MockExecutionModule_v0.1.0", address(_executionImpl), _mockMetadata);

        vm.stopPrank();

        assertTrue(factory().admins(stemAdmin1()));
        assertTrue(factory().admins(stemAdmin2()));

        assertTrue(factory().contestTemplates("v0.1.0") == address(_contestImpl));
        assertTrue(factory().moduleTemplates("ERC20VotesPoints_v0.1.0") == address(_pointsImpl));
        assertTrue(factory().moduleTemplates("TimedVotes_v0.1.0") == address(_votesImpl));
        assertTrue(factory().moduleTemplates("HatsAllowList_v0.1.0") == address(_choicesImpl));
        assertTrue(factory().moduleTemplates("MockExecutionModule_v0.1.0") == address(_executionImpl));
    }

    function __fastFactory_init_contest() public {
        _fastFactory_setup();

        bytes[4] memory moduleData;
        string[4] memory moduleNames;

        // votes module data
        moduleData[0] = abi.encode(TWO_WEEKS);
        moduleNames[0] = "TimedVotes_v0.1.0";

        // points module data
        moduleData[1] = abi.encode(address(arbToken()), SNAPSHOT_BLOCK);
        moduleNames[1] = "ERC20VotesPoints_v0.1.0";

        // choices module data
        moduleData[2] = abi.encode(address(hats()), facilitator1().id, new bytes[](0));
        moduleNames[2] = "HatsAllowList_v0.1.0";

        // execution module data
        moduleData[3] = new bytes(0);
        moduleNames[3] = "MockExecutionModule_v0.1.0";

        bytes memory _contestInitData = abi.encode(moduleNames, moduleData);

        (address contestAddress, address[4] memory moduleAddress) =
            factory().buildContest(_contestInitData, "v0.1.0", false, true, "gs_test");

        _contest = Contest(contestAddress);
        _votesModule = TimedVotes(moduleAddress[0]);
        _pointsModule = ERC20VotesPoints(moduleAddress[1]);
        _choiceModule = HatsAllowList(moduleAddress[2]);
        _executionModule = EmptyExecution(moduleAddress[3]);
    }

    // Note:
    // NOT USED: This function is not used in the test
    // Now using FastFactory to build contest
    // Saving for backup and reference only
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

        // setup execution module
        executionModule().initialize(address(contest()), new bytes(0));

        // // setup contest
        bytes memory _contestInitData = abi.encode(
            address(votesModule()),
            address(pointsModule()),
            address(choicesModule()),
            address(executionModule()),
            false,
            true
        );

        vm.expectEmit(true, false, false, true);
        emit ContestInitialized(
            address(votesModule()),
            address(pointsModule()),
            address(choicesModule()),
            address(executionModule()),
            false,
            true,
            ContestStatus.Populating
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

    function executionModule() public view returns (EmptyExecution) {
        return _executionModule;
    }

    function contest() public view returns (Contest) {
        return _contest;
    }

    function factory() public view returns (FastFactory) {
        return _factory;
    }

    function arbVoter(uint256 _index) public view returns (address) {
        return _voters[_index];
    }
}
