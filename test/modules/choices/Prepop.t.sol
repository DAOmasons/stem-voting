// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Prepop} from "../../../src/modules/choices/Prepop.sol";
import {Metadata} from "../../../src/core/Metadata.sol";
import {Accounts} from "../../setup/Accounts.t.sol";
import {BasicChoice} from "../../../src/core/Choice.sol";
import {ContestStatus} from "../../../src/core/ContestStatus.sol";
import {MockContestSetup} from "../../setup/MockContest.sol";

contract PrepopTest is Test, Accounts, MockContestSetup {
    error InvalidInitialization();

    /// @notice Emitted when the contract is initialized
    event Initialized(address contest);

    /// @notice Emitted when a choice is registered
    event Registered(bytes32 choiceId, BasicChoice choiceData, address contest);

    Prepop choiceModule;

    Metadata metadata = Metadata(1, "QmWmyoMoctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWeVdD");
    Metadata metadata2 = Metadata(2, "QmBa4oMoctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWe2zF");
    Metadata metadata3 = Metadata(3, "QmHi23fctfbAaiEsLPSqEtP6xTBm9vLkRZPJ5pSRWzt32");

    bytes choiceData = "choice1";
    bytes choiceData2 = "choice2";
    bytes choiceData3 = "choice3";

    BasicChoice basicChoice1 = BasicChoice(metadata, choiceData, true, address(1));
    BasicChoice basicChoice2 = BasicChoice(metadata2, choiceData2, true, address(1));
    BasicChoice basicChoice3 = BasicChoice(metadata3, choiceData3, true, address(1));

    function setUp() public {
        __setupMockContest();
        choiceModule = new Prepop();
    }

    //////////////////////////////
    // Unit Tests
    //////////////////////////////

    function test_init() public {
        _initalize();

        assertEq(address(choiceModule.contest()), address(mockContest()));

        (Metadata memory _metadata1, bytes memory _choiceData1, bool _exists1, address _registrar1) =
            choiceModule.choices(choice1());
        (Metadata memory _metadata2, bytes memory _choiceData2, bool _exists2, address _registrar2) =
            choiceModule.choices(choice2());
        (Metadata memory _metadata3, bytes memory _choiceData3, bool _exists3, address _registrar3) =
            choiceModule.choices(choice3());

        assertEq(_metadata1.protocol, metadata.protocol);
        assertEq(_metadata1.pointer, metadata.pointer);
        assertEq(_choiceData1, choiceData);
        assertEq(_registrar1, address(1));
        assertEq(_exists1, true);

        assertEq(_metadata2.protocol, metadata2.protocol);
        assertEq(_metadata2.pointer, metadata2.pointer);
        assertEq(_choiceData2, choiceData2);
        assertEq(_registrar2, address(1));
        assertEq(_exists2, true);

        assertEq(_metadata3.protocol, metadata3.protocol);
        assertEq(_metadata3.pointer, metadata3.pointer);
        assertEq(_choiceData3, choiceData3);
        assertEq(_registrar3, address(1));
        assertEq(_exists3, true);

        // assertEq(uint8(mockContest().contestStatus()), uint8(ContestStatus.Voting));
    }

    //////////////////////////////
    // Reverts
    //////////////////////////////

    function testRevert_nonZero() public {
        bytes32[] memory choiceIds = new bytes32[](3);

        choiceIds[0] = choice1();
        choiceIds[1] = choice2();
        choiceIds[2] = choice3();

        BasicChoice[] memory choices = new BasicChoice[](3);

        choices[0] = basicChoice1;
        choices[1] = basicChoice2;
        choices[2] = basicChoice3;

        vm.expectRevert("Prepop requires a valid contest");
        choiceModule.initialize(address(0), abi.encode(choices, choiceIds));
    }

    function testRevert_atLeastTwoChoices() public {
        bytes32[] memory choiceIds = new bytes32[](1);

        choiceIds[0] = choice1();

        BasicChoice[] memory choices = new BasicChoice[](1);

        choices[0] = basicChoice1;

        vm.expectRevert("Prepop requires at least 2 choices");
        choiceModule.initialize(address(mockContest()), abi.encode(choices, choiceIds));
    }

    function testRevert_arrayMismatch() public {
        bytes32[] memory choiceIds = new bytes32[](3);

        choiceIds[0] = choice1();
        choiceIds[1] = choice2();
        choiceIds[2] = choice3();

        BasicChoice[] memory choices = new BasicChoice[](2);

        choices[0] = basicChoice1;
        choices[1] = basicChoice2;

        vm.expectRevert("Array lengths do not match");
        choiceModule.initialize(address(mockContest()), abi.encode(choices, choiceIds));
    }

    function testRevert_init_twice() public {
        _initalize();

        bytes32[] memory choiceIds = new bytes32[](3);

        choiceIds[0] = choice1();
        choiceIds[1] = choice2();
        choiceIds[2] = choice3();

        BasicChoice[] memory choices = new BasicChoice[](3);

        choices[0] = basicChoice1;
        choices[1] = basicChoice2;
        choices[2] = basicChoice3;

        vm.expectRevert(InvalidInitialization.selector);
        choiceModule.initialize(address(mockContest()), abi.encode(choices, choiceIds));
    }

    function testRevert_registerChoice() public {
        _initalize();

        vm.expectRevert("Prepop does not implement registerChoice");

        choiceModule.registerChoice("", "");
    }

    function testRevert_removeChoice() public {
        _initalize();

        vm.expectRevert("Prepop does not implement removeChoice");

        choiceModule.removeChoice("", "");
    }

    //////////////////////////////
    // Getters
    //////////////////////////////

    function testValidChoice() public {
        _initalize();

        assertTrue(choiceModule.isValidChoice(choice1()));
        assertTrue(choiceModule.isValidChoice(choice2()));
        assertTrue(choiceModule.isValidChoice(choice3()));
    }

    //////////////////////////////
    // Helpers
    //////////////////////////////

    function _initalize() public {
        bytes32[] memory choiceIds = new bytes32[](3);

        choiceIds[0] = choice1();
        choiceIds[1] = choice2();
        choiceIds[2] = choice3();

        BasicChoice[] memory choices = new BasicChoice[](3);

        choices[0] = basicChoice1;
        choices[1] = basicChoice2;
        choices[2] = basicChoice3;

        vm.expectEmit(true, false, false, true);

        emit Initialized(address(mockContest()));

        emit Registered(choice1(), basicChoice1, address(mockContest()));
        emit Registered(choice2(), basicChoice2, address(mockContest()));
        emit Registered(choice3(), basicChoice3, address(mockContest()));

        choiceModule.initialize(address(mockContest()), abi.encode(choices, choiceIds));
    }
}
