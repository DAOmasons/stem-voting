// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import "forge-std/StdJson.sol";

import {IModule} from "../src/interfaces/IModule.sol";
import {FastFactory} from "../src/factories/gsRough/FastFactory.sol";
import {TimedVotes} from "../src/modules/votes/TimedVotes.sol";
import {Metadata} from "../src/core/Metadata.sol";

contract RunFactory is Script {
    string _network;

    using stdJson for string;

    string root = vm.projectRoot();

    string contestTag = "contest_v0_2_0";
    Metadata internal _contestMetadata = Metadata(
        6969420,
        "Contest: Contest contract that orchestrates custom voting, allocation, choice selection, and execution modules for TCR voting"
    );

    string baalPointsTag = "baalPoints_v0_2_0";
    Metadata internal _baalPointsMetadata = Metadata(
        6969420, "ERC20VotesPoints: Points module that uses OZ ERC20Votes V5. Made Specific for Moloch v3 DAOs (Baal)"
    );

    string timedVotesTag = "timedVotes_v0_2_0";
    Metadata internal _timedVotesMetadata =
        Metadata(6969420, "TimedVotes: Votes module that uses a time limit for voting");

    string DEPLOYMENTS_DIR = string.concat(root, "/deployments/factory.json");

    function run() external {
        console2.log("Deploying factory...");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.rememberKey(pk);

        _setEnvString();

        vm.startBroadcast(deployer);

        // _deployFactory(deployer);
        _registerModule(timedVotesTag, _timedVotesMetadata);
        // _deployTimedVotes();

        vm.stopBroadcast();
    }

    function _setEnvString() internal {
        uint256 key;

        assembly {
            key := chainid()
        }

        _network = vm.toString(key);
    }

    function _registerModule(string memory _moduleTag, Metadata memory _metadata) internal {
        (address _moduleAddress) = abi.decode(_getDeployment(_moduleTag), (address));

        IModule _module = IModule(_moduleAddress);

        factory().setModuleTemplate(_module.MODULE_NAME(), _moduleAddress, _metadata);
    }

    function _getDeployment(string memory _key) internal view returns (bytes memory) {
        string memory jsonString = vm.readFile(DEPLOYMENTS_DIR);

        bytes memory jsonBytes = vm.parseJson(jsonString, string.concat(".", _network, ".", _key));

        return jsonBytes;
    }

    function _deployFactory(address _deployer) internal {
        FastFactory _fastFactory = new FastFactory(_deployer);

        vm.writeJson(vm.toString(address(_fastFactory)), DEPLOYMENTS_DIR, string.concat(".", _network, ".factory"));

        console2.log("Factory address: %s", address(_fastFactory));
    }

    function _deployTimedVotes() internal {
        TimedVotes _timedVotes = new TimedVotes();

        vm.writeJson(
            vm.toString(address(_timedVotes)), DEPLOYMENTS_DIR, string.concat(".", _network, ".", timedVotesTag)
        );

        console2.log("TimedVotes address: %s", address(_timedVotes));
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
