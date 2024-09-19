// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console} from "forge-std/Test.sol";

import {ContestStatus} from "../../src/core/ContestStatus.sol";
import {BaalPointsV0} from "../../src/modules/points/BaalPoints.sol";
import {Prepop} from "../../src/modules/choices/Prepop.sol";
import {TimedVotes} from "../../src/modules/votes/TimedVotes.sol";
import {EmptyExecution} from "../../src/modules/execution/EmptyExecution.sol";
import {FastFactory} from "../../src/factories/gsRough/FastFactory.sol";
import {Metadata} from "../../src/core/Metadata.sol";
import {BaalGateV0} from "../../src/modules/choices/BaalGate.sol";
import {BaalSetupLive} from "./BaalSetup.t.sol";
import {Contest} from "../../src/Contest.sol";
import {Accounts} from "./Accounts.t.sol";
import {HolderType} from "../../src/core/BaalUtils.sol";
import {BasicChoice} from "../../src/core/Choice.sol";

contract AskHausSetupLive is BaalSetupLive, Accounts {
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
    uint256 constant SHARE_AMOUNT = 1_000e18;
    uint256 constant LOOT_AMOUNT = 2_000e18;

    uint256 constant START_BLOCK = 6668489;
    uint256 START_TIMESTAMP = block.timestamp;
    uint256 DELEGATE_TIMESTAMP = START_TIMESTAMP + 10;
    uint256 SNAPSHOT_TIMESTAMP = DELEGATE_TIMESTAMP + 15;
    uint256 VOTE_TIMESTAMP = DELEGATE_TIMESTAMP + 20;
    uint256 constant TWO_WEEKS = 1209600;

    BaalPointsV0 _baalPoints;
    BaalGateV0 _baalChoices;
    Prepop _prepopChoices;
    Contest _contest;
    TimedVotes _timedVotesModule;
    EmptyExecution _executionModule;
    FastFactory _factory;

    Contest _contestImpl;
    BaalPointsV0 _baalPointsImpl;
    BaalGateV0 _baalChoicesImpl;
    Prepop _prepopChoicesImpl;
    TimedVotes _timedVotesModuleImpl;
    EmptyExecution _executionModuleImpl;

    Metadata _mockMetadata = Metadata(1, "qm....");

    BasicChoice _choice1 = BasicChoice(_mockMetadata, "", true, address(0));
    BasicChoice _choice2 = BasicChoice(_mockMetadata, "", true, address(0));
    BasicChoice _choice3 = BasicChoice(_mockMetadata, "", true, address(0));

    function __setupAskHausPoll(HolderType _holderType) internal {
        // ensure fork block number is synchronized with test environment block number
        // assertEq(block.timestamp, START_TIMESTAMP);
        __setUpBaalWithNewToken();
        _setupVoters();
        _fastFactorySetup();

        bytes[4] memory moduleData;
        string[4] memory moduleNames;

        // votes Module data

        moduleData[0] = abi.encode(TWO_WEEKS);
        moduleNames[0] = _timedVotesModuleImpl.MODULE_NAME();

        // assertEq(address(0), address(_timedVotesModule));

        // points module data

        moduleData[1] = abi.encode(dao(), SNAPSHOT_TIMESTAMP, _holderType);
        moduleNames[1] = _baalPointsImpl.MODULE_NAME();

        console.log(factory().moduleTemplates(_timedVotesModuleImpl.MODULE_NAME()));
        console.log(address(_timedVotesModuleImpl));
        // choices module data
        BasicChoice[] memory choices = new BasicChoice[](3);
        bytes32[] memory choiceIds = new bytes32[](3);

        choices[0] = _choice1;
        choices[1] = _choice2;
        choices[2] = _choice3;

        choiceIds[0] = choice1();
        choiceIds[1] = choice2();
        choiceIds[2] = choice3();

        moduleData[2] = abi.encode(choices, choiceIds);
        moduleNames[2] = _prepopChoicesImpl.MODULE_NAME();

        // execution module data

        moduleData[3] = abi.encode("");
        moduleNames[3] = _executionModuleImpl.MODULE_NAME();

        bytes memory _contestInitData = abi.encode(moduleNames, moduleData);

        (address contestAddress, address[4] memory moduleAddresses) =
            factory().buildContest(_contestInitData, _contestImpl.CONTEST_VERSION(), false, false, "Filter Tag");

        _contest = Contest(contestAddress);
        _timedVotesModule = TimedVotes(moduleAddresses[0]);
        _baalPoints = BaalPointsV0(moduleAddresses[1]);
        _baalChoices = BaalGateV0(moduleAddresses[2]);
        _executionModule = EmptyExecution(moduleAddresses[3]);

        // bytes memory _contestInitData;
    }

    function __setupAskHausContest() internal {}

    function __setupAskHausSignalSession() internal {}

    function _setupVoters() internal {
        // vm.warp(DELEGATE_TIMESTAMP);
        _voters = new address[](5);

        _voters[0] = voter0();
        _voters[1] = voter1();
        _voters[2] = voter2();
        _voters[3] = voter3();
        _voters[4] = voter4();

        uint256[] memory balances = new uint256[](5);

        balances[0] = SHARE_AMOUNT;
        balances[1] = SHARE_AMOUNT;
        balances[2] = SHARE_AMOUNT;
        balances[3] = SHARE_AMOUNT;
        balances[4] = SHARE_AMOUNT;

        address avatar = dao().avatar();

        vm.startPrank(avatar);
        dao().mintShares(_voters, balances);

        balances = new uint256[](5);

        balances[0] = LOOT_AMOUNT;
        balances[1] = LOOT_AMOUNT;
        balances[2] = LOOT_AMOUNT;
        balances[3] = LOOT_AMOUNT;
        balances[4] = LOOT_AMOUNT;

        dao().mintLoot(_voters, balances);
        vm.stopPrank();
    }

    function _fastFactorySetup() internal {
        vm.startPrank(stemAdmin1());

        _factory = new FastFactory(stemAdmin1());

        factory().addAdmin(stemAdmin2());

        _contestImpl = new Contest();
        _baalPointsImpl = new BaalPointsV0();
        _baalChoicesImpl = new BaalGateV0();
        _prepopChoicesImpl = new Prepop();
        _timedVotesModuleImpl = new TimedVotes();

        console.log("TimedVotes impl address", address(_timedVotesModuleImpl));

        _executionModuleImpl = new EmptyExecution();

        factory().setContestTemplate(_contestImpl.CONTEST_VERSION(), address(_contestImpl), _mockMetadata);
        factory().setModuleTemplate(_baalPointsImpl.MODULE_NAME(), address(_baalPointsImpl), _mockMetadata);
        factory().setModuleTemplate(_baalChoicesImpl.MODULE_NAME(), address(_baalChoicesImpl), _mockMetadata);
        factory().setModuleTemplate(_prepopChoicesImpl.MODULE_NAME(), address(_prepopChoicesImpl), _mockMetadata);
        factory().setModuleTemplate(_timedVotesModuleImpl.MODULE_NAME(), address(_timedVotesModuleImpl), _mockMetadata);
        factory().setModuleTemplate(_executionModuleImpl.MODULE_NAME(), address(_executionModuleImpl), _mockMetadata);

        vm.stopPrank();

        assertTrue(factory().admins(stemAdmin1()));
        assertTrue(factory().admins(stemAdmin2()));

        console.log("Module template", factory().moduleTemplates(_timedVotesModuleImpl.MODULE_NAME()));

        assertEq(factory().contestTemplates(_contestImpl.CONTEST_VERSION()), address(_contestImpl));
        assertEq(factory().moduleTemplates(_baalPointsImpl.MODULE_NAME()), address(_baalPointsImpl));
        assertEq(factory().moduleTemplates(_baalChoicesImpl.MODULE_NAME()), address(_baalChoicesImpl));
        assertEq(factory().moduleTemplates(_prepopChoicesImpl.MODULE_NAME()), address(_prepopChoicesImpl));
        assertEq(factory().moduleTemplates(_timedVotesModuleImpl.MODULE_NAME()), address(_timedVotesModuleImpl));
        assertEq(factory().moduleTemplates(_executionModuleImpl.MODULE_NAME()), address(_executionModuleImpl));
    }

    // function choicesModule() public view returns (HatsAllowList) {
    //     return _choiceModule;
    // }

    // function pointsModule() public view returns (ERC20VotesPoints) {
    //     return _pointsModule;
    // }

    // function votesModule() public view returns (TimedVotes) {
    //     return _votesModule;
    // }

    // function executionModule() public view returns (EmptyExecution) {
    //     return _executionModule;
    // }

    // function contest() public view returns (Contest) {
    //     return _contest;
    // }

    function factory() public view returns (FastFactory) {
        return _factory;
    }
}
