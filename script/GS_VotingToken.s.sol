// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Script, console2} from "forge-std/Script.sol";
import {GSVotingToken} from "../src/factories/gsRough/GSVoteToken.sol";

contract DeploySBT is Script {
    function run() public {
        // Deploy the Voting Token

        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.rememberKey(pk);

        vm.startBroadcast(deployer);
        console2.log("Deploying Voting Token");
        _deployToken();
        vm.stopBroadcast();
        // new GSVotingToken("GSVotingToken", "GSVoting", "GSV", 0, 0xacB3Afa9Ca0b4edeAc41a98E1F90ba6300b6D217);
    }

    function _deployToken() internal {
        new GSVotingToken("Grant Ships Voting Token", "GSV", 0, 0xacB3Afa9Ca0b4edeAc41a98E1F90ba6300b6D217);
    }
}
