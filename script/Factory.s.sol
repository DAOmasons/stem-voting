// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// lib
import {Script, console2} from "forge-std/Script.sol";
import "forge-std/StdJson.sol";

// core
import {IModule} from "../src/interfaces/IModule.sol";
import {FastFactory} from "../src/factories/gsRough/FastFactory.sol";
import {Contest} from "../src/Contest.sol";
import {Metadata} from "../src/core/Metadata.sol";

// modules
import {TimedVotes} from "../src/modules/votes/TimedVotes.sol";
import {BaalPointsV0} from "../src/modules/points/BaalPoints.sol";
import {BaalGateV0} from "../src/modules/choices/BaalGate.sol";
import {Prepop} from "../src/modules/choices/Prepop.sol";
import {EmptyExecution} from "../src/modules/execution/EmptyExecution.sol";

contract RunFactory is Script {
    string _network;

    using stdJson for string;

    string root = vm.projectRoot();

    address dev_jord = 0xDE6bcde54CF040088607199FC541f013bA53C21E;

    string contestTag = "contest_v0_2_0";
    Metadata internal _contestMetadata = Metadata(
        6969420,
        "Contest: Contest contract that orchestrates custom voting, allocation, choice selection, and execution modules for TCR voting"
    );

    string baalPointsTag = "baalPoints_v0_2_0";
    Metadata internal _baalPointsMetadata = Metadata(
        6969420, "ERC20VotesPoints: Points module that uses OZ ERC20Votes V5. Made Specific for Moloch v3 DAOs (Baal)"
    );

    string baalChoicesTag = "baalGateChoices_v0_2_0";
    Metadata internal _baalChoicesMetadata = Metadata(
        6969420, "BaalGateChoice: Choice Creation module that uses a Baal DAO tokens to gate who can set choices (Baal)"
    );

    string prePopTag = "prepop_v0_2_0";
    Metadata internal _prepopMetadata =
        Metadata(6969420, "Prepop: Choice Creation module that prepopulates choices on init");

    string emptyExecutionTag = "emptyExecution_v0_2_0";
    Metadata internal _executionMetadata = Metadata(6969420, "EmptyExecutionModule: Execution module that does nothing");

    string timedVotesTag = "timedVotes_v0_2_0";
    Metadata internal _timedVotesMetadata =
        Metadata(6969420, "TimedVotes: Votes module that uses a time limit for voting");

    string DEPLOYMENTS_DIR = string.concat(root, "/deployments/factory.json");

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.rememberKey(pk);

        _setEnvString();

        vm.startBroadcast(deployer);
        // _deployAll();

        _registerAll();
        // _deployFactory(deployer);
        // _addAdmin(dev_jord);

        vm.stopBroadcast();
    }

    function _setEnvString() internal {
        uint256 key;

        assembly {
            key := chainid()
        }

        _network = vm.toString(key);
    }

    function _addAdmin(address _admin) internal {
        factory().addAdmin(_admin);
    }

    function _registerModule(string memory _moduleTag, Metadata memory _metadata) internal {
        (address _moduleAddress) = abi.decode(_getDeployment(_moduleTag), (address));

        IModule _module = IModule(_moduleAddress);

        factory().setModuleTemplate(_module.MODULE_NAME(), _moduleAddress, _metadata);
    }

    function _registerContest() internal {
        (address _templateAddress) = abi.decode(_getDeployment("contest_v0_2_0"), (address));

        Contest _contest = new Contest();

        factory().setContestTemplate(_contest.CONTEST_VERSION(), _templateAddress, _contestMetadata);
    }

    function _getDeployment(string memory _key) internal view returns (bytes memory) {
        string memory jsonString = vm.readFile(DEPLOYMENTS_DIR);

        bytes memory jsonBytes = vm.parseJson(jsonString, string.concat(".", _network, ".", _key));

        return jsonBytes;
    }

    function _deployAll() internal {
        _deployPrepopChoices();
        _deployBaalPoints();
        _deployBaalChoices();
        _deployContest();
        _deployEmptyExecution();
        _deployTimedVotes();
    }

    function _registerAll() internal {
        _registerContest();

        _registerModule(baalPointsTag, _baalPointsMetadata);
        _registerModule(baalChoicesTag, _baalChoicesMetadata);
        _registerModule(prePopTag, _prepopMetadata);
        _registerModule(emptyExecutionTag, _executionMetadata);
        _registerModule(timedVotesTag, _timedVotesMetadata);
    }

    function _deployFactory(address _deployer) internal {
        FastFactory _fastFactory = new FastFactory(_deployer);

        vm.writeJson(vm.toString(address(_fastFactory)), DEPLOYMENTS_DIR, string.concat(".", _network, ".factory"));

        console2.log("Factory address: %s", address(_fastFactory));
    }

    function _deployContest() internal {
        Contest _contest = new Contest();

        vm.writeJson(vm.toString(address(_contest)), DEPLOYMENTS_DIR, string.concat(".", _network, ".", contestTag));

        console2.log("Contest address: %s", address(_contest));
    }

    function _deployTimedVotes() internal {
        TimedVotes _timedVotes = new TimedVotes();

        vm.writeJson(
            vm.toString(address(_timedVotes)), DEPLOYMENTS_DIR, string.concat(".", _network, ".", timedVotesTag)
        );

        console2.log("TimedVotes address: %s", address(_timedVotes));
    }

    function _deployBaalPoints() internal {
        BaalPointsV0 _baalPoints = new BaalPointsV0();

        vm.writeJson(
            vm.toString(address(_baalPoints)), DEPLOYMENTS_DIR, string.concat(".", _network, ".", baalPointsTag)
        );

        console2.log("BaalPoints address: %s", address(_baalPoints));
    }

    function _deployBaalChoices() internal {
        BaalGateV0 _baalChoices = new BaalGateV0();

        vm.writeJson(
            vm.toString(address(_baalChoices)), DEPLOYMENTS_DIR, string.concat(".", _network, ".", baalChoicesTag)
        );

        console2.log("BaalChoices address: %s", address(_baalChoices));
    }

    function _deployPrepopChoices() internal {
        Prepop _prepop = new Prepop();

        vm.writeJson(vm.toString(address(_prepop)), DEPLOYMENTS_DIR, string.concat(".", _network, ".", prePopTag));

        console2.log("Prepop address: %s", address(_prepop));
    }

    function _deployEmptyExecution() internal {
        EmptyExecution _execution = new EmptyExecution();

        vm.writeJson(
            vm.toString(address(_execution)), DEPLOYMENTS_DIR, string.concat(".", _network, ".", emptyExecutionTag)
        );

        console2.log("Execution address: %s", address(_execution));
    }

    function factory() internal view returns (FastFactory) {
        bytes memory json = _getDeployment("factory");
        (address _fastFactory) = abi.decode(json, (address));

        return FastFactory(_fastFactory);
    }

    function timedVotes() internal view returns (TimedVotes) {
        bytes memory json = _getDeployment(timedVotesTag);
        (address _timedVotes) = abi.decode(json, (address));

        return TimedVotes(_timedVotes);
    }
}
