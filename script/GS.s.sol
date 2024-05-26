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
import {EmptyExecution} from "../src/modules/execution/EmptyExecution.sol";

// Instructions to deploy a new GS Voting without updating contracts
// 1. Bump the FILTER_TAG in ConstantsAgnostic
// 2. Update deployment inheritance depending on the network (ex. ConstantsTest for TESTNET)
// 3. Ensure environment variables are correctly set
// 2. Run the following script:
// for TESTNET
// forge script script/GS.s.sol:FastFactoryBuildGSContest --rpc-url $ARB_SEPOLIA_RPC_URL --broadcast --verify

contract ConstantsAgnostic {
    uint256 ONE_WEEK = 604800;
    uint256 TEN_MINUTES = 600;
    string VOTES_MODULE_NAME = "TimedVotes_v0.1.0";
    string POINTS_MODULE_NAME = "ERC20VotesPoints_v0.1.0";
    string CHOICES_MODULE_NAME = "HatsAllowList_v0.1.0";
    string EXECUTION_MODULE_NAME = "EmptyExecutionModule_v0.1.0";
    string CONTEST_MODULE_VERSION = "v0.1.0";
    string GS_VOTING_VERSION = "v0.1.0";
    // bump this to the next version when you want to deploy a new contest
    string FILTER_TAG = "v0.0.4";
    address HATS = 0x3bc1A0Ad72417f2d411118085256fC53CBdDd137;
    uint256 FACILITATOR_HAT_ID = 2210716038082491793464205775877905354575872088332293351845461877587968;
}

contract ConstantsTest is ConstantsAgnostic {
    address constant FAST_FACTORY_ADDRESS = 0x3a190e45f300cbb8AB1153a90b23EE3333b02D9d;
    address constant CHOICES_ADDRESS = 0xF6fee573515E78F30b6dca745581Ce575677c761;
    address constant POINTS_ADDRESS = 0x3198166F2dAA2fe2dA8EFEe1f7a3Ca72da47fbf7;
    address constant VOTES_ADDRESS = 0x52f718fB325CAD186a4D69368765d5604d2483eC;
    address constant EXECUTION_ADDRESS = 0xb60274DE6dEF245dA0fF46bfC61DafbF312c2BAf;
    address constant CONTEST_ADDRESS = 0x3A594698b511D84c3756D99828aF11B9049dFf14;
    address constant DEV = 0xDE6bcde54CF040088607199FC541f013bA53C21E;
    address constant TOKEN = 0xd00CEdA81e6Ce6B47BFC6B19e8981C24aEa58368;
    uint256 CHECKPOINT = 5980010;
}

contract TemplateAddressesProd is ConstantsAgnostic {
    address constant FAST_FACTORY_ADDRESS = 0x1670EEfb9B638243559b6Fcc7D6d3e6f9d4Ca5Fc;
    address constant CHOICES_ADDRESS = 0x1670EEfb9B638243559b6Fcc7D6d3e6f9d4Ca5Fc;
    address constant CONTEST_ADDRESS = 0x1670EEfb9B638243559b6Fcc7D6d3e6f9d4Ca5Fc;
    address constant POINTS_ADDRESS = 0x1670EEfb9B638243559b6Fcc7D6d3e6f9d4Ca5Fc;
    address constant VOTES_ADDRESS = 0x1670EEfb9B638243559b6Fcc7D6d3e6f9d4Ca5Fc;
    address constant EXECUTION_MODULE_ADDRESS = 0x0000000000000000000000000000000000000000;
}

contract DeployAndRegisterHatsAllowList is Script, ConstantsTest {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.rememberKey(pk);

        vm.startBroadcast(deployer);

        HatsAllowList module = new HatsAllowList();

        FastFactory fastFactory = FastFactory(FAST_FACTORY_ADDRESS);

        fastFactory.setModuleTemplate(
            CHOICES_MODULE_NAME,
            address(module),
            Metadata(0, "HatsAllowList: Choice Creation module that uses a hat ID to gate who can set choices")
        );

        vm.stopBroadcast();
    }
}

contract DeployAndRegisterERC20VotesPoints is Script, ConstantsTest {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.rememberKey(pk);

        vm.startBroadcast(deployer);

        ERC20VotesPoints module = new ERC20VotesPoints();

        FastFactory fastFactory = FastFactory(FAST_FACTORY_ADDRESS);

        fastFactory.setModuleTemplate(
            POINTS_MODULE_NAME,
            address(module),
            Metadata(
                0,
                "ERC20VotesPoints: Points module that uses IVotes ERC20 tokens for counting voting power at a given block"
            )
        );

        vm.stopBroadcast();
    }
}

contract DeployAndRegisterTimedVotes is Script, ConstantsTest {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.rememberKey(pk);

        vm.startBroadcast(deployer);

        TimedVotes module = new TimedVotes();

        FastFactory fastFactory = FastFactory(FAST_FACTORY_ADDRESS);

        fastFactory.setModuleTemplate(
            VOTES_MODULE_NAME,
            address(module),
            Metadata(0, "TimedVotes: Votes module that uses a time limit for voting")
        );

        vm.stopBroadcast();
    }
}

contract DeployAndRegisterMockExecution is Script, ConstantsTest {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.rememberKey(pk);

        vm.startBroadcast(deployer);

        EmptyExecution module = new EmptyExecution();

        FastFactory fastFactory = FastFactory(FAST_FACTORY_ADDRESS);

        fastFactory.setModuleTemplate(
            EXECUTION_MODULE_NAME,
            address(module),
            Metadata(0, "EmptyExecutionModule: Execution module that does nothing")
        );

        vm.stopBroadcast();
    }
}

contract DeployAndRegisterContest is Script, ConstantsTest {
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

contract DeleteAndAddContestTemplate is Script, ConstantsTest {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.rememberKey(pk);

        vm.startBroadcast(deployer);

        FastFactory fastFactory = FastFactory(FAST_FACTORY_ADDRESS);

        fastFactory.setContestTemplate(
            "should be deleted",
            address(CONTEST_ADDRESS),
            Metadata(
                0,
                "Contest: Early v0.1.0 Contest contract that orchestrates custom voting, allocation, choice selection, and execution modules for TCR voting"
            )
        );

        fastFactory.removeContestTemplate("should be deleted");

        vm.stopBroadcast();
    }
}

contract DeleteAndAddModuleTemplate is Script, ConstantsTest {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.rememberKey(pk);

        vm.startBroadcast(deployer);

        FastFactory fastFactory = FastFactory(FAST_FACTORY_ADDRESS);

        fastFactory.setModuleTemplate(
            "should be deleted",
            address(POINTS_ADDRESS),
            Metadata(
                0,
                "ERC20VotesPoints: Points module that uses IVotes ERC20 tokens for counting voting power at a given block"
            )
        );

        fastFactory.removeModuleTemplate("should be deleted");

        vm.stopBroadcast();
    }
}

contract FastFactoryDeployAddAdmin is Script, ConstantsTest {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.rememberKey(pk);

        vm.startBroadcast(deployer);

        FastFactory fastFactory = new FastFactory(deployer);

        fastFactory.addAdmin(DEV);

        vm.stopBroadcast();
    }
}

contract AddModulesAndVersions is Script, ConstantsTest {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.rememberKey(pk);

        vm.startBroadcast(deployer);

        FastFactory fastFactory = FastFactory(FAST_FACTORY_ADDRESS);

        fastFactory.setContestTemplate(
            CONTEST_MODULE_VERSION,
            address(CONTEST_ADDRESS),
            Metadata(
                0,
                "Contest: Early v0.1.0 Contest contract that orchestrates custom voting, allocation, choice selection, and execution modules for TCR voting"
            )
        );

        fastFactory.setModuleTemplate(
            POINTS_MODULE_NAME,
            address(POINTS_ADDRESS),
            Metadata(
                0,
                "ERC20VotesPoints: Points module that uses IVotes ERC20 tokens for counting voting power at a given block"
            )
        );

        fastFactory.setModuleTemplate(
            VOTES_MODULE_NAME, VOTES_ADDRESS, Metadata(0, "TimedVotes: Votes module that uses a time limit for voting")
        );

        fastFactory.setModuleTemplate(
            CHOICES_MODULE_NAME,
            CHOICES_ADDRESS,
            Metadata(0, "HatsAllowList: Choice Creation module that uses a hat ID to gate who can set choices")
        );

        fastFactory.setModuleTemplate(
            EXECUTION_MODULE_NAME,
            EXECUTION_ADDRESS,
            Metadata(0, "EmptyExecutionModule: Execution module that does nothing")
        );

        vm.stopBroadcast();
    }
}

contract BuildGSContest is Script, ConstantsTest {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.rememberKey(pk);

        vm.startBroadcast(deployer);

        FastFactory fastFactory = FastFactory(FAST_FACTORY_ADDRESS);

        bytes[4] memory moduleData;
        string[4] memory moduleNames;

        // votes module data
        moduleData[0] = abi.encode(TEN_MINUTES);
        moduleNames[0] = VOTES_MODULE_NAME;

        // points module data
        moduleData[1] = abi.encode(TOKEN, CHECKPOINT);
        moduleNames[1] = POINTS_MODULE_NAME;

        // choices module data
        moduleData[2] = abi.encode(HATS, FACILITATOR_HAT_ID, new bytes[](0));
        moduleNames[2] = CHOICES_MODULE_NAME;

        // execution module data
        moduleData[3] = abi.encode(0);
        moduleNames[3] = EXECUTION_MODULE_NAME;

        bytes memory _contestInitData = abi.encode(moduleNames, moduleData);

        (address contestAddress, address[4] memory moduleAddress) =
            fastFactory.buildContest(_contestInitData, GS_VOTING_VERSION, false, false, FILTER_TAG);

        console2.log("Contest address: %s", contestAddress);
        console2.log("Votes module address: %s", moduleAddress[0]);
        console2.log("Points module address: %s", moduleAddress[1]);
        console2.log("Choices module address: %s", moduleAddress[2]);
        console2.log("Execution module address: %s", moduleAddress[3]);

        vm.stopBroadcast();
    }
}

contract DeployDummyToken is Script, ConstantsTest {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.rememberKey(pk);

        vm.startBroadcast(deployer);

        DummyVotingToken token = new DummyVotingToken("TEST", "TTT", 1_000_000_000000000000000000, deployer);

        // address[5] memory voters;

        // voters[0] = 0x57abda4ee50Bb3079A556C878b2c345310057569;
        // voters[1] = 0xD800B05c70A2071BC1E5Eac5B3390Da1Eb67bC9D;
        // voters[2] = 0x57ffb33cC9D786da4087d970b0B0053017f26afc;
        // voters[3] = 0x27773b203954FBBb3e98DFa1a85A99e1c2f40f56;
        // voters[4] = 0x67243d6c3c3bDc2F59D2f74ba1949a02973a529d;

        // for (uint256 i = 0; i < voters.length; i++) {
        //     token.transfer(voters[i], 10_000_000000000000000000);
        // }
        // token.transfer(DEV, 300_000_000000000000000000);

        vm.stopBroadcast();
    }
}
