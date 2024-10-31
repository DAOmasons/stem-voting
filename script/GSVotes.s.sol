// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {TimedVotes} from "../src/modules/votes/TimedVotes.sol";
import {Contest} from "../src/Contest.sol";
import {Metadata} from "../src/core/Metadata.sol";

contract CurrentDeployment {
    address VOTE_MODULE_ADDRESS = 0x08Efc63577f631A3Be5cf2a79f0E1965B1Fc39B2;
    address CONTEST_ADDRESS = 0x828d27E685DF55EeD09c7e68802F8cB0Fbb9435a;
    Metadata emptyMetadata = Metadata(0, "");
    Metadata SHIP1_REASON = Metadata(0, "This is Ship 1");
    Metadata SHIP2_REASON = Metadata(0, "This is Ship 2");
    Metadata SHIP3_REASON = Metadata(0, "This is Ship 3");

    bytes32 SHIP1_ID = keccak256(abi.encodePacked("ship1"));
    bytes32 SHIP2_ID = keccak256(abi.encodePacked("ship2"));
    bytes32 SHIP3_ID = keccak256(abi.encodePacked("ship3"));
}

contract ManageVotes is Script, CurrentDeployment {
    TimedVotes votesModule = TimedVotes(VOTE_MODULE_ADDRESS);
    Contest contest = Contest(CONTEST_ADDRESS);
    bytes32[] shipIds;
    uint256[] amounts;
    bytes[] reasons;

    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address caller = vm.rememberKey(pk);
        vm.startBroadcast(caller);

        // _setupVoting();
        // _voteForShips();
        _finalizeVoting();

        vm.stopBroadcast();
    }

    function _setupVoting() internal {
        votesModule.setVotingTime(0);
    }

    function _voteForShips() internal {
        shipIds.push(SHIP1_ID);
        shipIds.push(SHIP2_ID);
        shipIds.push(SHIP3_ID);

        amounts.push(150_000_000000000000000000);
        amounts.push(200_000_000000000000000000);
        amounts.push(300_000_000000000000000000);
        reasons.push(abi.encode(SHIP1_REASON));
        reasons.push(abi.encode(SHIP2_REASON));
        reasons.push(abi.encode(SHIP3_REASON));

        contest.batchVote(shipIds, amounts, reasons, amounts[0] + amounts[1] + amounts[2], emptyMetadata);
    }

    function _retractShipVotes() internal {
        shipIds.push(SHIP1_ID);
        shipIds.push(SHIP2_ID);
        shipIds.push(SHIP3_ID);

        amounts.push(150_000_000000000000000000);
        amounts.push(200_000_000000000000000000);
        amounts.push(300_000_000000000000000000);

        reasons.push(abi.encode(SHIP1_REASON));
        reasons.push(abi.encode(SHIP2_REASON));
        reasons.push(abi.encode(SHIP3_REASON));

        contest.batchRetractVote(shipIds, amounts, reasons, 3000, emptyMetadata);
    }

    function _finalizeVoting() internal {
        votesModule.finalizeVoting();
    }
}
