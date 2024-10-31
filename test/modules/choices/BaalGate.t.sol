// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {BaalGateV0} from "../../../src/modules/choices/BaalGate.sol";
import {Metadata} from "../../../src/core/Metadata.sol";
import {Accounts} from "../../setup/Accounts.t.sol";
import {BasicChoice} from "../../../src/core/Choice.sol";
import {BaalSetupLive} from "../../setup/BaalSetup.t.sol";
import {HolderType} from "../../../src/core/BaalUtils.sol";
import {ContestStatus} from "../../../src/core/ContestStatus.sol";
import {MockContestSetup} from "../../setup/MockContest.sol";

contract BaalGateTest is Test, Accounts, MockContestSetup, BaalSetupLive {
    error InvalidInitialization();
    // @notice Emitted when a choice is registered

    event Registered(bytes32 choiceId, BasicChoice choiceData, address contest);

    // @notice Emitted when a choice is removed
    event Removed(bytes32 choiceId, address contest);

    // @notice Emitted when the contract is initialized
    event Initialized(
        address contest,
        address daoAddress,
        address lootToken,
        address sharesToken,
        HolderType holderType,
        uint256 holderThreshold,
        uint256 checkpoint,
        bool timed,
        uint256 startTime,
        uint256 endTime
    );

    BaalGateV0 choiceModule;

    Metadata metadata = Metadata(1, "QmWmyoMoctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWeVdD");
    Metadata metadata2 = Metadata(2, "QmBa4oMoctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWe2zF");
    Metadata metadata3 = Metadata(3, "QmHi23fctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWzt32");

    bytes choiceData = "choice1";
    bytes choiceData2 = "choice2";
    bytes choiceData3 = "choice3";

    uint256 TWO_WEEKS = 1209600;

    uint256 voteAmount = 1000e18;

    address[] _voters;

    uint256 _mintTime;
    uint256 _voteTime;

    uint256 constant ONE_HOUR = 3600;

    function setUp() public {
        vm.createSelectFork({blockNumber: 6668489, urlOrAlias: "sepolia"});

        __setupMockContest();

        __setUpBaalWithNewToken();

        choiceModule = new BaalGateV0();
        _setupVoters();
    }

    //////////////////////////////
    // Unit Tests
    //////////////////////////////

    function test_init_notTimed() public {
        _init_notTimed(HolderType.Share);

        assertEq(address(choiceModule.contest()), address(mockContest()));
        assertEq(address(choiceModule.dao()), address(dao()));
        assertEq(address(choiceModule.lootToken()), address(loot()));
        assertEq(address(choiceModule.sharesToken()), address(shares()));
        assertEq(uint8(choiceModule.holderType()), uint8(HolderType.Share));
        assertEq(choiceModule.holderThreshold(), 1e17);
        assertEq(choiceModule.timed(), false);
        assertEq(choiceModule.startTime(), 0);
        assertEq(choiceModule.endTime(), 0);
    }

    function test_init_now() public {
        _init_now(HolderType.Share);

        assertEq(address(choiceModule.contest()), address(mockContest()));
        assertEq(address(choiceModule.dao()), address(dao()));
        assertEq(address(choiceModule.lootToken()), address(loot()));
        assertEq(address(choiceModule.sharesToken()), address(shares()));
        assertEq(uint8(choiceModule.holderType()), uint8(HolderType.Share));
        assertEq(choiceModule.holderThreshold(), 1e17);
        assertEq(choiceModule.timed(), true);
        assertEq(choiceModule.startTime(), block.timestamp);
        assertEq(choiceModule.endTime(), block.timestamp + TWO_WEEKS);
    }

    function test_init_later() public {
        _init_later(HolderType.Share);

        assertEq(address(choiceModule.contest()), address(mockContest()));
        assertEq(address(choiceModule.dao()), address(dao()));
        assertEq(address(choiceModule.lootToken()), address(loot()));
        assertEq(address(choiceModule.sharesToken()), address(shares()));
        assertEq(uint8(choiceModule.holderType()), uint8(HolderType.Share));
        assertEq(choiceModule.holderThreshold(), 1e17);
        assertEq(choiceModule.timed(), true);
        assertEq(choiceModule.startTime(), block.timestamp + TWO_WEEKS);
        assertEq(choiceModule.endTime(), block.timestamp + TWO_WEEKS + TWO_WEEKS);
    }

    function test_registerChoice_initNotTimed() public {
        _init_notTimed(HolderType.Share);
        _register(voter1());

        BasicChoice memory registeredChoice = choiceModule.getChoice(choice1());
        assertEq(registeredChoice.metadata.protocol, metadata.protocol);
        assertEq(registeredChoice.metadata.pointer, metadata.pointer);
        assertEq(registeredChoice.data, choiceData);
        assertEq(registeredChoice.exists, true);
    }

    function test_registerChoice_initNow() public {
        _init_now(HolderType.Share);
        _register(voter1());

        BasicChoice memory registeredChoice = choiceModule.getChoice(choice1());
        assertEq(registeredChoice.metadata.protocol, metadata.protocol);
        assertEq(registeredChoice.metadata.pointer, metadata.pointer);
        assertEq(registeredChoice.data, choiceData);
        assertEq(registeredChoice.exists, true);
    }

    function test_registerChoice_initLater() public {
        _init_later(HolderType.Share);
        vm.warp(block.timestamp + TWO_WEEKS);

        _register(voter1());

        BasicChoice memory registeredChoice = choiceModule.getChoice(choice1());
        assertEq(registeredChoice.metadata.protocol, metadata.protocol);
        assertEq(registeredChoice.metadata.pointer, metadata.pointer);
        assertEq(registeredChoice.data, choiceData);
        assertEq(registeredChoice.exists, true);
    }

    function test_remove_choice() public {
        _init_now(HolderType.Share);
        _register(voter1());
        _remove(voter1());

        BasicChoice memory registeredChoice = choiceModule.getChoice(choice1());

        assertEq(registeredChoice.metadata.pointer, "");
        assertEq(registeredChoice.data, "");
        assertEq(registeredChoice.metadata.protocol, 0);
        assertEq(registeredChoice.exists, false);
    }

    function test_finalize_now() public {
        _init_now(HolderType.Share);
        _register(voter1());
        _remove(voter1());

        vm.warp(block.timestamp + TWO_WEEKS);
        choiceModule.finalizeChoices();
    }

    function test_finalize_later() public {
        _init_later(HolderType.Share);
        vm.warp(block.timestamp + TWO_WEEKS);
        _register(voter1());
        _remove(voter1());

        vm.warp(block.timestamp + TWO_WEEKS + TWO_WEEKS);
        choiceModule.finalizeChoices();
    }

    //////////////////////////////
    // Reverts
    //////////////////////////////

    function testRevert_init_nonZero() public {
        bytes memory _data = abi.encode(address(0), 0, TWO_WEEKS, HolderType.Share, _voteTime - 1, 1e17);

        vm.expectRevert("Uninitialized parameters provided");
        choiceModule.initialize(address(mockContest()), _data);

        _data = abi.encode(address(dao()), 0, TWO_WEEKS, HolderType.None, _voteTime - 1, 1e17);

        vm.expectRevert("Uninitialized parameters provided");
        choiceModule.initialize(address(mockContest()), _data);

        _data = abi.encode(address(dao()), 0, TWO_WEEKS, HolderType.Loot, 0, 1e17);

        vm.expectRevert("Uninitialized parameters provided");
        choiceModule.initialize(address(mockContest()), _data);

        _data = abi.encode(address(dao()), 0, TWO_WEEKS, HolderType.Both, _voteTime - 1, 1e17);

        vm.expectRevert("Uninitialized parameters provided");
        choiceModule.initialize(address(0), _data);
    }

    function testRevert_init_startsInPast() public {
        bytes memory _data =
            abi.encode(address(dao()), block.timestamp - 1, TWO_WEEKS, HolderType.Share, _voteTime - 1, 1e17);

        vm.expectRevert("Start time must be in the future");
        choiceModule.initialize(address(mockContest()), _data);
    }

    function testRevert_register_nonInit() public {
        bytes memory _data = abi.encode(choiceData, metadata);

        vm.expectRevert("Not initialized");
        vm.startPrank(voter1());
        choiceModule.registerChoice(choice1(), _data);
        vm.stopPrank();
    }

    function testRevert_register_before() public {
        _init_later(HolderType.Share);

        bytes memory _data = abi.encode(choiceData, metadata);

        vm.expectRevert("Not during population period");
        vm.startPrank(voter1());
        choiceModule.registerChoice(choice1(), _data);
        vm.stopPrank();

        vm.warp(block.timestamp + TWO_WEEKS);

        vm.startPrank(voter1());
        choiceModule.registerChoice(choice1(), _data);
        vm.stopPrank();
    }

    function testRevert_register_after() public {
        _init_later(HolderType.Share);

        bytes memory _data = abi.encode(choiceData, metadata);

        vm.warp(block.timestamp + TWO_WEEKS + TWO_WEEKS + 1);

        vm.expectRevert("Not during population period");
        vm.startPrank(voter1());
        choiceModule.registerChoice(choice1(), _data);
        vm.stopPrank();
    }

    //check to ensure that non-timed rounds bypass onlyValidTime modifier
    function testAlt_register_nonTimed() public {
        _init_notTimed(HolderType.Share);

        bytes memory _data = abi.encode(choiceData, metadata);

        vm.startPrank(voter1());
        choiceModule.registerChoice(choice1(), _data);
        vm.stopPrank();
    }

    function testRevert_register_onlyContestPopulating() public {
        _init_now(HolderType.Share);
        bytes memory _data = abi.encode(choiceData, metadata);

        mockContest().cheatStatus(ContestStatus.Voting);

        vm.expectRevert("Contest is not in populating state");
        vm.startPrank(voter1());
        choiceModule.registerChoice(choice1(), _data);
        vm.stopPrank();
    }

    function testRevert_register_onlyHolder_share() public {
        _init_now(HolderType.Share);
        bytes memory _data = abi.encode(choiceData, metadata);

        vm.expectRevert("Insufficient share balance");
        vm.startPrank(someGuy());
        choiceModule.registerChoice(choice1(), _data);
        vm.stopPrank();
    }

    function testRevert_register_onlyHolder_loot() public {
        _init_now(HolderType.Loot);
        bytes memory _data = abi.encode(choiceData, metadata);

        vm.expectRevert("Insufficient loot balance");
        vm.startPrank(someGuy());
        choiceModule.registerChoice(choice1(), _data);
        vm.stopPrank();
    }

    function testRevert_register_onlyHolder_both() public {
        _init_now(HolderType.Both);
        bytes memory _data = abi.encode(choiceData, metadata);

        vm.expectRevert("Insufficient balance");
        vm.startPrank(someGuy());
        choiceModule.registerChoice(choice1(), _data);
        vm.stopPrank();
    }

    function testRevert_removeChoice_invalidChoice() public {
        _init_now(HolderType.Both);
        _register(voter1());

        vm.expectRevert("Choice does not exist");
        vm.startPrank(voter1());
        choiceModule.removeChoice(choice2(), "");
        vm.stopPrank();
    }

    function testRevert_removeChoice_onlyRegistrar() public {
        _init_now(HolderType.Both);
        _register(voter1());

        vm.expectRevert("Only registrar can remove choice");
        vm.startPrank(voter2());
        choiceModule.removeChoice(choice1(), "");
        vm.stopPrank();
    }

    function testRevert_finalize_beforePeriodComplete() public {
        _init_now(HolderType.Share);
        _register(voter1());

        vm.expectRevert("Population period has not ended");
        vm.startPrank(voter1());
        choiceModule.finalizeChoices();
        vm.stopPrank();
    }

    function testRevert_finalize_notPopulating() public {
        _init_now(HolderType.Share);
        _register(voter1());

        mockContest().cheatStatus(ContestStatus.Voting);

        vm.expectRevert("Contest is not in populating state");
        vm.startPrank(voter1());
        choiceModule.finalizeChoices();
        vm.stopPrank();
    }

    function testRevert_finalize_isContinuous() public {
        _init_now(HolderType.Share);
        _register(voter1());

        vm.warp(block.timestamp + TWO_WEEKS + 1);

        mockContest().cheatContinuous(true);

        vm.expectRevert("Contest is continuous");
        vm.startPrank(voter1());
        choiceModule.finalizeChoices();
        vm.stopPrank();
    }

    //////////////////////////////
    // Helpers
    //////////////////////////////

    function _remove(address _registrar) public {
        vm.expectEmit(true, false, false, true);
        emit Removed(choice1(), address(mockContest()));

        vm.startPrank(_registrar);
        choiceModule.removeChoice(choice1(), "");
        vm.stopPrank();
    }

    function _register(address _registrar) public {
        bytes memory _data = abi.encode(choiceData, metadata);

        vm.expectEmit(true, false, false, true);
        emit Registered(choice1(), BasicChoice(metadata, choiceData, true, _registrar), address(mockContest()));
        vm.startPrank(_registrar);
        choiceModule.registerChoice(choice1(), _data);
        vm.stopPrank();
    }

    function _init_notTimed(HolderType _holderType) public {
        _init(0, 0, _holderType);
    }

    function _init_later(HolderType _holderType) public {
        _init(block.timestamp + TWO_WEEKS, TWO_WEEKS, _holderType);
    }

    function _init_now(HolderType _holderType) public {
        _init(0, TWO_WEEKS, _holderType);
    }

    function _init(uint256 _startTime, uint256 _duration, HolderType _holderType) public {
        bytes memory _data = abi.encode(address(dao()), _startTime, _duration, _holderType, _voteTime - 1, 1e17);

        bool timed = _startTime == 0 && _duration == 0 ? false : true;
        uint256 startTime = timed && _startTime == 0 ? block.timestamp : _startTime;

        mockContest().cheatStatus(ContestStatus.Populating);

        vm.expectEmit(true, false, false, true);

        emit Initialized(
            address(mockContest()),
            address(dao()),
            address(loot()),
            address(shares()),
            _holderType,
            1e17,
            _voteTime - 1,
            timed,
            startTime,
            startTime + _duration
        );

        choiceModule.initialize(address(mockContest()), _data);
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
        dao().mintLoot(_voters, balances);
        vm.stopPrank();

        _mintTime = block.timestamp;
        _voteTime = _mintTime + ONE_HOUR;

        vm.warp(_voteTime);
    }
}
