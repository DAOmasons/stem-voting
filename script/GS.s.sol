// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {HatsAllowList} from "../src/modules/choices/HatsAllowList.sol";
import {ERC20VotesPoints} from "../src/modules/points/ERC20VotesPoints.sol";
import {FastFactory} from "../src/factories/gsRough/FastFactory.sol";
import {TimedVotes} from "../src/modules/votes/TimedVotes.sol";
import {Metadata} from "../src/core/Metadata.sol";
import {DummyVotingToken} from "./DummyVotingToken.sol";
import {Contest} from "../src/Contest.sol";

contract TemplateAddressesTest {
    address constant FAST_FACTORY_ADDRESS = 0x1670EEfb9B638243559b6Fcc7D6d3e6f9d4Ca5Fc;
    address constant CHOICES_ADDRESS = 0xF6fee573515E78F30b6dca745581Ce575677c761;
    address constant POINTS_ADDRESS = 0x3198166F2dAA2fe2dA8EFEe1f7a3Ca72da47fbf7;
    address constant VOTES_ADDRESS = 0x52f718fB325CAD186a4D69368765d5604d2483eC;
    address constant EXECUTION_ADDRESS = 0x0000000000000000000000000000000000000000;
    address constant CONTEST_ADDRESS = 0x3A594698b511D84c3756D99828aF11B9049dFf14;
    address constant DEV = 0xDE6bcde54CF040088607199FC541f013bA53C21E;
}

contract TemplateAddressesProd {
    address constant FAST_FACTORY_ADDRESS = 0x1670EEfb9B638243559b6Fcc7D6d3e6f9d4Ca5Fc;
    address constant CHOICES_ADDRESS = 0x1670EEfb9B638243559b6Fcc7D6d3e6f9d4Ca5Fc;
    address constant CONTEST_ADDRESS = 0x1670EEfb9B638243559b6Fcc7D6d3e6f9d4Ca5Fc;
    address constant POINTS_ADDRESS = 0x1670EEfb9B638243559b6Fcc7D6d3e6f9d4Ca5Fc;
    address constant VOTES_ADDRESS = 0x1670EEfb9B638243559b6Fcc7D6d3e6f9d4Ca5Fc;
    address constant EXECUTION_MODULE_ADDRESS = 0x0000000000000000000000000000000000000000;
}

contract DeployAndRegisterHatsAllowList is Script, TemplateAddressesTest {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.rememberKey(pk);

        vm.startBroadcast(deployer);

        HatsAllowList module = new HatsAllowList();

        FastFactory fastFactory = FastFactory(FAST_FACTORY_ADDRESS);

        fastFactory.setModuleTemplate(
            "HatsAllowList_v0.1.0",
            address(module),
            Metadata(0, "HatsAllowList: Choice Creation module that uses a hat ID to gate who can set choices")
        );

        vm.stopBroadcast();
    }
}

contract DeployAndRegisterERC20VotesPoints is Script, TemplateAddressesTest {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.rememberKey(pk);

        vm.startBroadcast(deployer);

        ERC20VotesPoints module = new ERC20VotesPoints();

        FastFactory fastFactory = FastFactory(FAST_FACTORY_ADDRESS);

        fastFactory.setModuleTemplate(
            "ERC20VotesPoints_v0.1.0",
            address(module),
            Metadata(
                0,
                "ERC20VotesPoints: Points module that uses IVotes ERC20 tokens for counting voting power at a given block"
            )
        );

        vm.stopBroadcast();
    }
}

contract DeployAndRegisterTimedVotes is Script, TemplateAddressesTest {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.rememberKey(pk);

        vm.startBroadcast(deployer);

        TimedVotes module = new TimedVotes();

        FastFactory fastFactory = FastFactory(FAST_FACTORY_ADDRESS);

        fastFactory.setModuleTemplate(
            "TimedVotes_v0.1.0",
            address(module),
            Metadata(0, "TimedVotes: Votes module that uses a time limit for voting")
        );

        vm.stopBroadcast();
    }
}

contract DeployAndRegisterContest is Script, TemplateAddressesTest {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.rememberKey(pk);

        vm.startBroadcast(deployer);

        Contest contest = new Contest();

        FastFactory fastFactory = FastFactory(FAST_FACTORY_ADDRESS);

        fastFactory.setContestTemplate(
            "v0.1.0",
            address(contest),
            Metadata(
                0,
                "Contest: Early v0.1.0 Contest contract that orchestrates custom voting, allocation, choice selection, and execution modules for TCR voting"
            )
        );

        vm.stopBroadcast();
    }
}

contract FastFactoryDeployAddAdmin is Script, TemplateAddressesTest {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.rememberKey(pk);

        vm.startBroadcast(deployer);

        FastFactory fastFactory = new FastFactory(deployer);

        fastFactory.addAdmin(DEV);

        vm.stopBroadcast();
    }
}

contract DeployDummyToken is Script, TemplateAddressesTest {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.rememberKey(pk);

        vm.startBroadcast(deployer);

        DummyVotingToken token =
            new DummyVotingToken("Dummy Voting Token", "DVT", 1_000_000_000000000000000000, deployer);

        address[5] memory voters;

        voters[0] = 0x57abda4ee50Bb3079A556C878b2c345310057569;
        voters[1] = 0xD800B05c70A2071BC1E5Eac5B3390Da1Eb67bC9D;
        voters[2] = 0x57ffb33cC9D786da4087d970b0B0053017f26afc;
        voters[3] = 0x511449dD36e5dB31980AA0452aAAB95b9a68ae99;
        voters[4] = 0x0e65b98A3836ad03Dd88A3eEb39fdCFBeC196c93;

        // transfer 1000 tokens to list of addresses

        vm.stopBroadcast();
    }
}
