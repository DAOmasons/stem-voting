// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {HatsAllowList} from "../src/modules/choices/HatsAllowList.sol";
import {Metadata} from "../src/core/Metadata.sol";

contract CurrentDeployment {
    address CHOICE_MODULE_ADDRESS = 0xb3177343D025F0aD93C7c6FEC2ac01edD3775d80;
    address FACILITATOR = 0x57abda4ee50Bb3079A556C878b2c345310057569;
    bytes DUMMY_DATA = "0x";
    Metadata SHIP1_METADATA = Metadata(0, "This is Ship 1");
    Metadata SHIP2_METADATA = Metadata(0, "This is Ship 2");
    Metadata SHIP3_METADATA = Metadata(0, "This is Ship 3");

    bytes32 SHIP1_ID = keccak256(abi.encodePacked("ship1"));
    bytes32 SHIP2_ID = keccak256(abi.encodePacked("ship2"));
    bytes32 SHIP3_ID = keccak256(abi.encodePacked("ship3"));
}

contract ManageChoices is Script, CurrentDeployment {
    HatsAllowList choiceModule = HatsAllowList(CHOICE_MODULE_ADDRESS);

    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address caller = vm.rememberKey(pk);
        vm.startBroadcast(caller);

        _registerChoices();
        // _removeChoices();

        vm.stopBroadcast();
    }

    function _registerChoices() internal {
        bytes memory choice1Data = abi.encode(DUMMY_DATA, SHIP1_METADATA);
        bytes memory choice2Data = abi.encode(DUMMY_DATA, SHIP2_METADATA);
        bytes memory choice3Data = abi.encode(DUMMY_DATA, SHIP3_METADATA);

        choiceModule.registerChoice(SHIP1_ID, choice1Data);
        choiceModule.registerChoice(SHIP2_ID, choice2Data);
        choiceModule.registerChoice(SHIP3_ID, choice3Data);
    }

    function _removeChoices() internal {
        choiceModule.removeChoice(SHIP1_ID, "");
        choiceModule.removeChoice(SHIP2_ID, "");
        choiceModule.removeChoice(SHIP3_ID, "");
    }
}
