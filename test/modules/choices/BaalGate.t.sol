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

    event Initialized(
        address contest,
        address daoAddress,
        address lootToken,
        address sharesToken,
        HolderType holderType,
        uint256 holderThreshold,
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

    BasicChoice basicChoice1 = BasicChoice(metadata, choiceData, true);
    BasicChoice basicChoice2 = BasicChoice(metadata2, choiceData2, true);
    BasicChoice basicChoice3 = BasicChoice(metadata3, choiceData3, true);

    uint256 TWO_WEEKS = 1209600;

    function setUp() public {
        vm.createSelectFork({blockNumber: 6668489, urlOrAlias: "sepolia"});

        __setupMockContest();

        __setUpBaalWithNewToken();

        choiceModule = new BaalGateV0();
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

    //////////////////////////////
    // Reverts
    //////////////////////////////

    //////////////////////////////
    // Helpers
    //////////////////////////////

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
        bytes memory _data = abi.encode(address(dao()), _startTime, _duration, _holderType, 1e17);

        bool timed = _startTime == 0 && _duration == 0 ? false : true;
        uint256 startTime = timed && _startTime == 0 ? block.timestamp : _startTime;

        vm.expectEmit(true, false, false, true);
        emit Initialized(
            address(mockContest()),
            address(dao()),
            address(loot()),
            address(shares()),
            _holderType,
            1e17,
            timed,
            startTime,
            startTime + _duration
        );

        choiceModule.initialize(address(mockContest()), _data);
    }
}