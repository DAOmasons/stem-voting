// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import {HatsAllowList} from "../src/modules/choices/HatsAllowList.sol";
import {ERC20VotesPoints} from "../src/modules/points/ERC20VotesPoints.sol";
import {FastFactory} from "../src/factories/gsRough/FastFactory.sol";
import {TimedVotes} from "../src/modules/votes/TimedVotes.sol";
import {Metadata} from "../src/core/Metadata.sol";
import {DummyVotingToken} from "./DummyVotingToken.sol";
import {Contest} from "../src/Contest.sol";
import {EmptyExecution} from "../src/modules/execution/EmptyExecution.sol";
import {IModule} from "../src/interfaces/IModule.sol";

contract RunFactory is Script {
    string GS_VOTING_VERSION = "v0.1.0";
    string TAG_PREFIX = "grantShips_deployment_";
    address constant DEV_ADDRESS = 0xDE6bcde54CF040088607199FC541f013bA53C21E;

    using stdJson for string;

    string _network;
    string root = vm.projectRoot();

    string TEMPLATES_DIR = string.concat(root, "/deployments/gs_templates.json");
    string DEPLOYMENTS_DIR = string.concat(root, "/deployments/gs_recentDeployments.json");
    string NETWORK_DIR = string.concat(root, "/deployments/gs_networkSpecific.json");

    FastFactory internal _fastFactory;
    HatsAllowList internal _choicesTemplate;
    ERC20VotesPoints internal _pointsTemplate;
    TimedVotes internal _votesTemplate;
    EmptyExecution internal _executionTemplate;

    Contest internal _contest;

    Metadata internal _choicesMetadata =
        Metadata(0, "HatsAllowList: Choice Creation module that uses a hat ID to gate who can set choices");
    Metadata internal _pointsMetadata = Metadata(
        0, "ERC20VotesPoints: Points module that uses IVotes ERC20 tokens for counting voting power at a given block"
    );
    Metadata internal _votesMetadata = Metadata(0, "TimedVotes: Votes module that uses a time limit for voting");
    Metadata internal _executionMetadata = Metadata(0, "EmptyExecutionModule: Execution module that does nothing");
    Metadata internal _contestMetadata = Metadata(
        0,
        "Contest: Early v0.1.0 Contest contract that orchestrates custom voting, allocation, choice selection, and execution modules for TCR voting"
    );

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.rememberKey(pk);

        vm.startBroadcast(deployer);
        _setEnvString();

        __buildGrantShips();

        // __setupNewFactoryWithModules(deployer);

        vm.stopBroadcast();
    }

    /// ===============================
    /// =========== Macro =============
    /// ===============================

    function _setEnvString() internal {
        // string memory str = vm.envString(_key);

        uint256 key;

        assembly {
            key := chainid()
        }

        _network = vm.toString(key);
    }

    function __setupNewFactory(address _deployer) internal {
        _deployFactory(_deployer);
        _addAdmin(DEV_ADDRESS);
    }

    function __setupNewFactoryWithModules(address _deployer) internal {
        _deployFactory(_deployer);
        _addAdmin(DEV_ADDRESS);
        __deployModules();
        __setModuleTemplates();
    }

    function __deployModules() internal {
        console2.log("Deploying modules...");
        _deployContestTemplate();
        _deployChoicesModule();
        _deployPointsModule();
        _deployVotesModule();
        _deployExecutionModule();
    }

    function __setModuleTemplates() internal {
        _setContestTemplate();
        _setChoicesTemplate();
        _setPointsTemplate();
        _setVotesTemplate();
        _setExecutionTemplate();
    }

    /// ===============================
    /// =========== Deploy ============
    /// ===============================

    function _deployFactory(address _deployer) internal {
        _fastFactory = new FastFactory(_deployer);

        vm.writeJson(vm.toString(address(_fastFactory)), DEPLOYMENTS_DIR, string.concat(".", _network, ".factory"));

        console2.log("Factory address: %s", address(_fastFactory));
    }

    function _deployContestTemplate() internal {
        _contest = new Contest();

        vm.writeJson(vm.toString(address(_contest)), TEMPLATES_DIR, string.concat(".", _network, ".contest"));

        console2.log("Contest address: %s", address(_contest));
    }

    function _deployChoicesModule() internal {
        _choicesTemplate = new HatsAllowList();

        vm.writeJson(vm.toString(address(_choicesTemplate)), TEMPLATES_DIR, string.concat(".", _network, ".choices"));

        console2.log("Choices module address: %s", address(_choicesTemplate));
    }

    function _deployPointsModule() internal {
        _pointsTemplate = new ERC20VotesPoints();

        vm.writeJson(vm.toString(address(_pointsTemplate)), TEMPLATES_DIR, string.concat(".", _network, ".points"));

        console2.log("Points module address: %s", address(_pointsTemplate));
    }

    function _deployVotesModule() internal {
        _votesTemplate = new TimedVotes();

        vm.writeJson(vm.toString(address(_votesTemplate)), TEMPLATES_DIR, string.concat(".", _network, ".votes"));

        console2.log("Votes module address: %s", address(_votesTemplate));
    }

    function _deployExecutionModule() internal {
        _executionTemplate = new EmptyExecution();

        vm.writeJson(
            vm.toString(address(_executionTemplate)), TEMPLATES_DIR, string.concat(".", _network, ".execution")
        );

        console2.log("Execution module address: %s", address(_executionTemplate));
    }

    /// ===============================
    /// =========== Roles =============
    /// ===============================

    function _addAdmin(address _admin) internal {
        _fastFactory.addAdmin(_admin);
    }

    function _removeAdmin(address _admin) internal {
        _fastFactory.removeAdmin(_admin);
    }

    /// ===============================
    /// ========== Register ===========
    /// ===============================

    function _setChoicesTemplate() internal {
        _fastFactory.setModuleTemplate(_choicesTemplate.MODULE_NAME(), address(_choicesTemplate), _choicesMetadata);
    }

    function _setPointsTemplate() internal {
        _fastFactory.setModuleTemplate(_pointsTemplate.MODULE_NAME(), address(_pointsTemplate), _pointsMetadata);
    }

    function _setVotesTemplate() internal {
        _fastFactory.setModuleTemplate(_votesTemplate.MODULE_NAME(), address(_votesTemplate), _votesMetadata);
    }

    function _setExecutionTemplate() internal {
        _fastFactory.setModuleTemplate(
            _executionTemplate.MODULE_NAME(), address(_executionTemplate), _executionMetadata
        );
    }

    function _setContestTemplate() internal {
        _fastFactory.setContestTemplate(_contest.CONTEST_VERSION(), address(_contest), _contestMetadata);
    }

    function __buildGrantShips() internal {
        bytes[4] memory moduleData;
        string[4] memory moduleNames;

        FastFactory fastFactory = FastFactory(getDeploymentAddress("factory"));
        ERC20VotesPoints pointsTemplate = ERC20VotesPoints(getTemplateAddress("points"));
        TimedVotes votesTemplate = TimedVotes(getTemplateAddress("votes"));
        HatsAllowList choicesTemplate = HatsAllowList(getTemplateAddress("choices"));
        EmptyExecution executionTemplate = EmptyExecution(getTemplateAddress("execution"));
        Contest contestTemplate = Contest(getTemplateAddress("contest"));

        // votes module data
        moduleData[0] = abi.encode(voteTime());
        moduleNames[0] = votesTemplate.MODULE_NAME();

        // points module data
        moduleData[1] = abi.encode(tokenAddress(), block.number);
        moduleNames[1] = pointsTemplate.MODULE_NAME();

        // // choices module data
        moduleData[2] = abi.encode(hatsAddress(), hatId(), new bytes[](0));
        moduleNames[2] = choicesTemplate.MODULE_NAME();

        // // execution module data
        moduleData[3] = abi.encode(0);
        moduleNames[3] = executionTemplate.MODULE_NAME();

        bytes memory _contestInitData = abi.encode(moduleNames, moduleData);

        (address contestAddress, address[4] memory moduleAddress) =
            fastFactory.buildContest(_contestInitData, contestTemplate.CONTEST_VERSION(), false, false, TAG_PREFIX);

        console2.log("Contest address: %s", contestAddress);
        vm.writeJson(vm.toString(address(contestAddress)), DEPLOYMENTS_DIR, string.concat(".", _network, ".contest"));
        console2.log("Votes module address: %s", moduleAddress[0]);
        vm.writeJson(vm.toString(moduleAddress[0]), DEPLOYMENTS_DIR, string.concat(".", _network, ".votes"));
        console2.log("Points module address: %s", moduleAddress[1]);
        vm.writeJson(vm.toString(moduleAddress[1]), DEPLOYMENTS_DIR, string.concat(".", _network, ".points"));
        console2.log("Choices module address: %s", moduleAddress[2]);
        vm.writeJson(vm.toString(moduleAddress[2]), DEPLOYMENTS_DIR, string.concat(".", _network, ".choices"));
        console2.log("Execution module address: %s", moduleAddress[3]);
        vm.writeJson(vm.toString(moduleAddress[3]), DEPLOYMENTS_DIR, string.concat(".", _network, ".execution"));

        vm.writeJson(
            vm.toString(vm.parseInt(deploymentNonce()) + 1),
            NETWORK_DIR,
            string.concat(".", _network, ".deploymentNonce")
        );
    }

    function _getNetworkConfigValue(string memory _key) internal view returns (bytes memory) {
        string memory jsonString = vm.readFile(NETWORK_DIR);

        bytes memory jsonBytes = vm.parseJson(jsonString, string.concat(".", _network, ".", _key));

        return jsonBytes;
    }

    function networkName() internal view returns (string memory) {
        bytes memory json = _getNetworkConfigValue("networkName");
        (string memory _networkName) = abi.decode(json, (string));
        return _networkName;
    }

    function hatId() internal view returns (uint256) {
        bytes memory json = _getNetworkConfigValue("hatId");
        (uint256 _hatId) = abi.decode(json, (uint256));
        return _hatId;
    }

    function hatsAddress() internal view returns (address) {
        bytes memory json = _getNetworkConfigValue("hatsAddress");
        (address _hatsAddress) = abi.decode(json, (address));
        return _hatsAddress;
    }

    function voteTime() internal view returns (uint256) {
        bytes memory json = _getNetworkConfigValue("voteTime");
        (uint256 _testTime) = abi.decode(json, (uint256));
        return _testTime;
    }

    function tokenAddress() internal view returns (address) {
        bytes memory json = _getNetworkConfigValue("tokenAddress");
        (address _tokenAddress) = abi.decode(json, (address));
        return _tokenAddress;
    }

    function deploymentNonce() internal view returns (string memory) {
        bytes memory json = _getNetworkConfigValue("deploymentNonce");
        (string memory _deploymentNonce) = abi.decode(json, (string));
        return _deploymentNonce;
    }

    function getTemplateAddress(string memory _key) internal view returns (address) {
        string memory jsonString = vm.readFile(TEMPLATES_DIR);

        bytes memory jsonBytes = vm.parseJson(jsonString, string.concat(".", _network, ".", _key));

        (address _templateAddress) = abi.decode(jsonBytes, (address));
        return _templateAddress;
    }

    function getDeploymentAddress(string memory _key) internal view returns (address) {
        string memory jsonString = vm.readFile(DEPLOYMENTS_DIR);

        bytes memory jsonBytes = vm.parseJson(jsonString, string.concat(".", _network, ".", _key));

        (address _deploymentAddress) = abi.decode(jsonBytes, (address));
        return _deploymentAddress;
    }
}

// contract DeployAndRegisterHatsAllowList is Script, ConstantsTest {
// function run() external {
//     uint256 pk = vm.envUint("PRIVATE_KEY");
//     address deployer = vm.rememberKey(pk);

//     vm.startBroadcast(deployer);

//     HatsAllowList module = new HatsAllowList();

//     FastFactory fastFactory = FastFactory(FACTORY_TEMPLATE_ADDRESS);

//     fastFactory.setModuleTemplate(
//         module.MODULE_NAME(),
//         address(module),
//         Metadata(0, "HatsAllowList: Choice Creation module that uses a hat ID to gate who can set choices")
//     );

//     vm.stopBroadcast();
// }
// }

// contract DeployAndRegisterERC20VotesPoints is Script, ConstantsTest {
//     function run() external {
//         uint256 pk = vm.envUint("PRIVATE_KEY");
//         address deployer = vm.rememberKey(pk);

//         vm.startBroadcast(deployer);

//         ERC20VotesPoints module = new ERC20VotesPoints();

//         FastFactory fastFactory = FastFactory(FACTORY_TEMPLATE_ADDRESS);

//         fastFactory.setModuleTemplate(
//             module.MODULE_NAME(),
//             address(module),
//             Metadata(
//                 0,
//                 "ERC20VotesPoints: Points module that uses IVotes ERC20 tokens for counting voting power at a given block"
//             )
//         );

//         vm.stopBroadcast();
//     }
// }

// contract DeployAndRegisterTimedVotes is Script, ConstantsTest {
//     function run() external {
//         uint256 pk = vm.envUint("PRIVATE_KEY");
//         address deployer = vm.rememberKey(pk);

//         vm.startBroadcast(deployer);

//         TimedVotes module = new TimedVotes();

//         FastFactory fastFactory = FastFactory(FACTORY_TEMPLATE_ADDRESS);

//         fastFactory.setModuleTemplate(
//             module.MODULE_NAME(),
//             address(module),
//             Metadata(0, "TimedVotes: Votes module that uses a time limit for voting")
//         );

//         vm.stopBroadcast();
//     }
// }

// contract DeployAndRegisterMockExecution is Script, ConstantsTest {
//     function run() external {
//         uint256 pk = vm.envUint("PRIVATE_KEY");
//         address deployer = vm.rememberKey(pk);

//         vm.startBroadcast(deployer);

//         EmptyExecution module = new EmptyExecution();

//         FastFactory fastFactory = FastFactory(FACTORY_TEMPLATE_ADDRESS);

//         fastFactory.setModuleTemplate(
//             module.MODULE_NAME(),
//             address(module),
//             Metadata(0, "EmptyExecutionModule: Execution module that does nothing")
//         );

//         vm.stopBroadcast();
//     }
// }

// contract DeployAndRegisterContest is Script, ConstantsTest {
//     function run() external {
//         uint256 pk = vm.envUint("PRIVATE_KEY");
//         address deployer = vm.rememberKey(pk);

//         vm.startBroadcast(deployer);

//         Contest contest = new Contest();

//         FastFactory fastFactory = FastFactory(FACTORY_TEMPLATE_ADDRESS);

//         fastFactory.setContestTemplate(
//             "v0.1.0",
//             address(contest),
//             Metadata(
//                 0,
//                 "Contest: Early v0.1.0 Contest contract that orchestrates custom voting, allocation, choice selection, and execution modules for TCR voting"
//             )
//         );

//         vm.stopBroadcast();
//     }
// }

// contract DeleteAndAddContestTemplate is Script, ConstantsTest {
//     function run() external {
//         uint256 pk = vm.envUint("PRIVATE_KEY");
//         address deployer = vm.rememberKey(pk);

//         vm.startBroadcast(deployer);

//         FastFactory fastFactory = FastFactory(FACTORY_TEMPLATE_ADDRESS);

//         fastFactory.setContestTemplate(
//             "should be deleted",
//             address(CONTEST_TEMPLATE_ADDRESS),
//             Metadata(
//                 0,
//                 "Contest: Early v0.1.0 Contest contract that orchestrates custom voting, allocation, choice selection, and execution modules for TCR voting"
//             )
//         );

//         fastFactory.removeContestTemplate("should be deleted");

//         vm.stopBroadcast();
//     }
// }

// contract DeleteAndAddModuleTemplate is Script, ConstantsTest {
//     function run() external {
//         uint256 pk = vm.envUint("PRIVATE_KEY");
//         address deployer = vm.rememberKey(pk);

//         vm.startBroadcast(deployer);

//         FastFactory fastFactory = FastFactory(FACTORY_TEMPLATE_ADDRESS);

//         fastFactory.setModuleTemplate(
//             "should be deleted",
//             address(POINTS_TEMPLATE_ADDRESS),
//             Metadata(
//                 0,
//                 "ERC20VotesPoints: Points module that uses IVotes ERC20 tokens for counting voting power at a given block"
//             )
//         );

//         fastFactory.removeModuleTemplate("should be deleted");

//         vm.stopBroadcast();
//     }
// }

// contract FastFactoryDeployAddAdmin is Script, ConstantsTest {
//     function run() external {
//         uint256 pk = vm.envUint("PRIVATE_KEY");
//         address deployer = vm.rememberKey(pk);

//         vm.startBroadcast(deployer);

//         FastFactory fastFactory = new FastFactory(deployer);

//         fastFactory.addAdmin(DEV_ADDRESS);

//         vm.stopBroadcast();
//     }
// }

// contract AddModulesAndVersions is Script, ConstantsTest {
//     function run() external {
//         uint256 pk = vm.envUint("PRIVATE_KEY");
//         address deployer = vm.rememberKey(pk);

//         vm.startBroadcast(deployer);

//         FastFactory fastFactory = FastFactory(FACTORY_TEMPLATE_ADDRESS);

//         TimedVotes votesModule = TimedVotes(VOTES_TEMPLATE_ADDRESS);
//         ERC20VotesPoints pointsModule = ERC20VotesPoints(POINTS_TEMPLATE_ADDRESS);
//         HatsAllowList choicesModule = HatsAllowList(CHOICES_TEMPLATE_ADDRESS);
//         EmptyExecution executionModule = EmptyExecution(EXECUTION_TEMPLATE_ADDRESS);

//         Contest contest = Contest(CONTEST_TEMPLATE_ADDRESS);

//         fastFactory.setContestTemplate(
//             contest.CONTEST_VERSION(),
//             address(CONTEST_TEMPLATE_ADDRESS),
//             Metadata(
//                 0,
//                 "Contest: Early v0.1.0 Contest contract that orchestrates custom voting, allocation, choice selection, and execution modules for TCR voting"
//             )
//         );

//         fastFactory.setModuleTemplate(
//             pointsModule.MODULE_NAME(),
//             address(POINTS_TEMPLATE_ADDRESS),
//             Metadata(
//                 0,
//                 "ERC20VotesPoints: Points module that uses IVotes ERC20 tokens for counting voting power at a given block"
//             )
//         );

//         fastFactory.setModuleTemplate(
//             votesModule.MODULE_NAME(),
//             VOTES_TEMPLATE_ADDRESS,
//             Metadata(0, "TimedVotes: Votes module that uses a time limit for voting")
//         );

//         fastFactory.setModuleTemplate(
//             choicesModule.MODULE_NAME(),
//             CHOICES_TEMPLATE_ADDRESS,
//             Metadata(0, "HatsAllowList: Choice Creation module that uses a hat ID to gate who can set choices")
//         );

//         fastFactory.setModuleTemplate(
//             executionModule.MODULE_NAME(),
//             EXECUTION_TEMPLATE_ADDRESS,
//             Metadata(0, "EmptyExecutionModule: Execution module that does nothing")
//         );

//         vm.stopBroadcast();
//     }
// }

// contract BuildGSContest is Script, ConstantsTest {
//     function run() external {
//         uint256 pk = vm.envUint("PRIVATE_KEY");
//         address deployer = vm.rememberKey(pk);

//         vm.startBroadcast(deployer);

//         FastFactory fastFactory = FastFactory(FACTORY_TEMPLATE_ADDRESS);

//         bytes[4] memory moduleData;
//         string[4] memory moduleNames;

//         TimedVotes votesModule = TimedVotes(VOTES_TEMPLATE_ADDRESS);
//         ERC20VotesPoints pointsModule = ERC20VotesPoints(POINTS_TEMPLATE_ADDRESS);
//         HatsAllowList choicesModule = HatsAllowList(CHOICES_TEMPLATE_ADDRESS);
//         EmptyExecution executionModule = EmptyExecution(EXECUTION_TEMPLATE_ADDRESS);

//         // votes module data
//         moduleData[0] = abi.encode(TEN_MINUTES);
//         moduleNames[0] = votesModule.MODULE_NAME();

//         // points module data
//         moduleData[1] = abi.encode(TOKEN_ADDRESS, V_TOKEN_CHECKPOINT);
//         moduleNames[1] = pointsModule.MODULE_NAME();

//         // choices module data
//         moduleData[2] = abi.encode(HATS, FACILITATOR_HAT_ID, new bytes[](0));
//         moduleNames[2] = choicesModule.MODULE_NAME();

//         // execution module data
//         moduleData[3] = abi.encode(0);
//         moduleNames[3] = executionModule.MODULE_NAME();

//         bytes memory _contestInitData = abi.encode(moduleNames, moduleData);

//         (address contestAddress, address[4] memory moduleAddress) =
//             fastFactory.buildContest(_contestInitData, GS_VOTING_VERSION, false, false, FILTER_TAG);

//         console2.log("Contest address: %s", contestAddress);
//         console2.log("Votes module address: %s", moduleAddress[0]);
//         console2.log("Points module address: %s", moduleAddress[1]);
//         console2.log("Choices module address: %s", moduleAddress[2]);
//         console2.log("Execution module address: %s", moduleAddress[3]);

//         vm.stopBroadcast();
//     }
// }

// contract DeployDummyToken is Script, ConstantsTest {
//     function run() external {
//         uint256 pk = vm.envUint("PRIVATE_KEY");
//         address deployer = vm.rememberKey(pk);

//         vm.startBroadcast(deployer);

//         new DummyVotingToken("TEST", "TTT", 1_000_000_000000000000000000, deployer);

//         // address[5] memory voters;

//         // voters[0] = 0x57abda4ee50Bb3079A556C878b2c345310057569;
//         // voters[1] = 0xD800B05c70A2071BC1E5Eac5B3390Da1Eb67bC9D;
//         // voters[2] = 0x57ffb33cC9D786da4087d970b0B0053017f26afc;
//         // voters[3] = 0x27773b203954FBBb3e98DFa1a85A99e1c2f40f56;
//         // voters[4] = 0x67243d6c3c3bDc2F59D2f74ba1949a02973a529d;

//         // for (uint256 i = 0; i < voters.length; i++) {
//         //     token.transfer(voters[i], 10_000_000000000000000000);
//         // }
//         // token.transfer(DEV_ADDRESS, 300_000_000000000000000000);

//         vm.stopBroadcast();
//     }
// }
