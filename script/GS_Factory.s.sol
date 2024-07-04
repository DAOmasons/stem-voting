// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import {HatsAllowList} from "../src/modules/choices/HatsAllowList.sol";
import {ERC20VotesPoints} from "../src/modules/points/ERC20VotesPoints.sol";
import {SBTBalancePoints} from "../src/modules/points/SBTBalancePoints.sol";
import {FastFactory} from "../src/factories/gsRough/FastFactory.sol";
import {TimedVotes} from "../src/modules/votes/TimedVotes.sol";
import {Metadata} from "../src/core/Metadata.sol";
import {DummyVotingToken} from "./DummyVotingToken.sol";
import {Contest} from "../src/Contest.sol";
import {EmptyExecution} from "../src/modules/execution/EmptyExecution.sol";
import {IModule} from "../src/interfaces/IModule.sol";
import {HatsPoster} from "../src/factories/gsRough/HatsPoster.sol";

contract RunFactory is Script {
    string GS_VOTING_VERSION = "v0.2.0";
    string TAG_PREFIX = "grantShips_sbt_deployment_";
    address constant DEV_ADDRESS = 0xDE6bcde54CF040088607199FC541f013bA53C21E;

    using stdJson for string;

    string _network;
    string root = vm.projectRoot();

    string TEMPLATES_DIR = string.concat(root, "/deployments/gs_templates.json");
    string DEPLOYMENTS_DIR = string.concat(root, "/deployments/gs_recentDeployments.json");
    string NETWORK_DIR = string.concat(root, "/deployments/gs_networkSpecific.json");

    uint256 _blockNumber = block.number;

    FastFactory internal _fastFactory;
    HatsAllowList internal _choicesTemplate;
    ERC20VotesPoints internal _pointsTemplate;
    SBTBalancePoints internal _sbtPointsTemplate;
    TimedVotes internal _votesTemplate;
    EmptyExecution internal _executionTemplate;
    HatsPoster internal _hatsPoster;

    Contest internal _contest;

    uint256[] hatsIds;

    Metadata internal _choicesMetadata =
        Metadata(0, "HatsAllowList: Choice Creation module that uses a hat ID to gate who can set choices");
    Metadata internal _pointsMetadata = Metadata(
        0, "ERC20VotesPoints: Points module that uses IVotes ERC20 tokens for counting voting power at a given block"
    );
    Metadata internal _sbtPointsMetadata =
        Metadata(0, "SBTBalancePoints: Points module that uses SBT balance for counting voting power");
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

        // _addSBTPointsModule();

        __buildGrantShips();
        // __buildHatsPoster();

        // __setupNewFactoryWithModules(deployer);

        vm.stopBroadcast();
    }

    function _setEnvString() internal {
        // string memory str = vm.envString(_key);

        uint256 key;

        assembly {
            key := chainid()
        }

        _network = vm.toString(key);

        if (key == 421614) {
            _blockNumber = 6033741;
        } else {
            _blockNumber = block.number;
        }
    }

    /// ===============================
    /// =========== Macro =============
    /// ===============================

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

    function _addSBTPointsModule() internal {
        _deploySBTPointsModule();
        _setSbtPointsTemplate();
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

    function _deploySBTPointsModule() internal {
        _sbtPointsTemplate = new SBTBalancePoints();
        vm.writeJson(
            vm.toString(address(_sbtPointsTemplate)), TEMPLATES_DIR, string.concat(".", _network, ".sbtPoints")
        );
        console2.log("SBT Points module address: %s", address(_sbtPointsTemplate));
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

    function _deployHatsPoster() internal {
        _hatsPoster = new HatsPoster();

        vm.writeJson(vm.toString(address(_hatsPoster)), DEPLOYMENTS_DIR, string.concat(".", _network, ".hatsPoster"));

        console2.log("HatsPoster address: %s", address(_hatsPoster));
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

    function _setSbtPointsTemplate() internal {
        factory().setModuleTemplate(_sbtPointsTemplate.MODULE_NAME(), address(_sbtPointsTemplate), _sbtPointsMetadata);
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

    /// ===============================
    /// ========== Build ==============
    /// ===============================

    function __buildGrantShips() internal {
        bytes[4] memory moduleData;
        string[4] memory moduleNames;

        FastFactory fastFactory = FastFactory(getDeploymentAddress("factory"));
        // ERC20VotesPoints pointsTemplate = ERC20VotesPoints(getTemplateAddress("points"));
        SBTBalancePoints pointsTemplate = SBTBalancePoints(getTemplateAddress("sbtPoints"));

        console2.log("Points template address: %s", address(pointsTemplate));

        TimedVotes votesTemplate = TimedVotes(getTemplateAddress("votes"));
        HatsAllowList choicesTemplate = HatsAllowList(getTemplateAddress("choices"));
        EmptyExecution executionTemplate = EmptyExecution(getTemplateAddress("execution"));
        Contest contestTemplate = Contest(getTemplateAddress("contest"));

        // votes module data
        moduleData[0] = abi.encode(voteTime());
        moduleNames[0] = votesTemplate.MODULE_NAME();

        // points module data
        // moduleData[1] = abi.encode(tokenAddress(), _blockNumber);
        moduleData[1] = abi.encode(tokenAddress());
        moduleNames[1] = pointsTemplate.MODULE_NAME();

        // // choices module data
        moduleData[2] = abi.encode(hatsAddress(), facilitatorHatId(), new bytes[](0));
        moduleNames[2] = choicesTemplate.MODULE_NAME();

        // // execution module data
        moduleData[3] = abi.encode(0);
        moduleNames[3] = executionTemplate.MODULE_NAME();

        bytes memory _contestInitData = abi.encode(moduleNames, moduleData);

        (address contestAddress, address[4] memory moduleAddress) = fastFactory.buildContest(
            _contestInitData,
            contestTemplate.CONTEST_VERSION(),
            false,
            false,
            string.concat(TAG_PREFIX, vm.toString(deploymentNonce()))
        );

        console2.log("Contest address: %s", contestAddress);
        vm.writeJson(vm.toString(address(contestAddress)), DEPLOYMENTS_DIR, string.concat(".", _network, ".contest"));
        console2.log("Votes module address: %s", moduleAddress[0]);
        vm.writeJson(vm.toString(moduleAddress[0]), DEPLOYMENTS_DIR, string.concat(".", _network, ".votes"));
        console2.log("Points module address: %s", moduleAddress[1]);
        // vm.writeJson(vm.toString(moduleAddress[1]), DEPLOYMENTS_DIR, string.concat(".", _network, ".points"));
        vm.writeJson(vm.toString(moduleAddress[1]), DEPLOYMENTS_DIR, string.concat(".", _network, ".sbtPoints"));
        console2.log("Choices module address: %s", moduleAddress[2]);
        vm.writeJson(vm.toString(moduleAddress[2]), DEPLOYMENTS_DIR, string.concat(".", _network, ".choices"));
        console2.log("Execution module address: %s", moduleAddress[3]);
        vm.writeJson(vm.toString(moduleAddress[3]), DEPLOYMENTS_DIR, string.concat(".", _network, ".execution"));

        vm.writeJson(vm.toString(deploymentNonce() + 1), NETWORK_DIR, string.concat(".", _network, ".deploymentNonce"));
    }

    function __buildHatsPoster() internal {
        _deployHatsPoster();

        hatsIds.push(facilitatorHatId());
        hatsIds.push(shipId1());
        hatsIds.push(shipId2());
        hatsIds.push(shipId3());

        _hatsPoster.initialize(hatsIds, hatsAddress());
    }

    /// ===============================
    /// ========== GetJSON ============
    /// ===============================

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

    function factory() internal view returns (FastFactory) {
        bytes memory json = _getNetworkConfigValue("factory");
        (address _factory) = abi.decode(json, (address));
        return FastFactory(_factory);
    }

    function facilitatorHatId() internal view returns (uint256) {
        bytes memory json = _getNetworkConfigValue("facilitatorHatId");
        (uint256 _hatId) = abi.decode(json, (uint256));
        return _hatId;
    }

    function shipId1() internal view returns (uint256) {
        bytes memory json = _getNetworkConfigValue("shipId1");
        (uint256 _shipId) = abi.decode(json, (uint256));
        return _shipId;
    }

    function shipId2() internal view returns (uint256) {
        bytes memory json = _getNetworkConfigValue("shipId2");
        (uint256 _shipId) = abi.decode(json, (uint256));
        return _shipId;
    }

    function shipId3() internal view returns (uint256) {
        bytes memory json = _getNetworkConfigValue("shipId3");
        (uint256 _shipId) = abi.decode(json, (uint256));
        return _shipId;
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

    function deploymentNonce() internal view returns (uint256) {
        bytes memory json = _getNetworkConfigValue("deploymentNonce");
        (uint256 _deploymentNonce) = abi.decode(json, (uint256));
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
