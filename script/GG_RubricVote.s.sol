// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

// core
import {IModule} from "../src/interfaces/IModule.sol";
import {FastFactory} from "../src/factories/gsRough/FastFactory.sol";
import {Contest} from "../src/Contest.sol";
import {Metadata} from "../src/core/Metadata.sol";
import {RubricVotes} from "../src/modules/votes/RubricVotes.sol";
import {EmptyExecution} from "../src/modules/execution/EmptyExecution.sol";
import {EmptyPoints} from "../src/modules/points/EmptyPoints.sol";
import {HatsAllowList} from "../src/modules/choices/HatsAllowList.sol";

// modules
contract Deploy is Script {
    string _network;

    using stdJson for string;

    uint256 pk = vm.envUint("PRIVATE_KEY");
    address deployer = vm.rememberKey(pk);

    string root = vm.projectRoot();
    string DEPLOYMENTS_DIR = string.concat(root, "/deployments/factory.json");

    string contestTag = "contest_v0_2_1";
    Metadata internal _contestMetadata = Metadata(
        6969420,
        "Contest: Contest contract that orchestrates custom voting, allocation, choice selection, and execution modules for TCR voting"
    );

    string emptyExecutionTag = "emptyExecution_v0_2_0";
    Metadata internal _executionMetadata = Metadata(6969420, "EmptyExecutionModule: Execution module that does nothing");

    string emptyPointTag = "emptyPoints_v0_1_0";
    Metadata internal _pointsMetadata = Metadata(6969420, "EmptyPointsModule: Points module that does nothing");

    string rubricVotesTag = "rubricVotes_v0_1_0";
    Metadata internal _rubricVotesMetadata = Metadata(
        6969420,
        "RubricVotes: Votes module that allows judges to use votes to score based on a rubric or grading device."
    );

    string hatsAllowListTag = "hatsAllowList_v0_1_1";
    Metadata internal _hatsAllowListMetadata =
        Metadata(6969420, "HatsAllowList: Choice Creation module that uses a hat ID to gate who can set choices");

    function run() public {
        _setEnvString();

        vm.startBroadcast(deployer);

        _deployAll();

        vm.stopBroadcast();
    }

    function _setEnvString() internal {
        uint256 key;

        assembly {
            key := chainid()
        }

        _network = vm.toString(key);
    }

    function _deployAll() internal {
        // _deployContest();
        // _deployRubricVotes();
        // _deployEmptyExecution();
        // _deployEmptyPoints();
        // _deployHatsAllowList();
    }

    function _deployContest() internal {
        Contest _contest = new Contest();

        vm.writeJson(vm.toString(address(_contest)), DEPLOYMENTS_DIR, string.concat(".", _network, ".", contestTag));

        console2.log("Contest address: %s", address(_contest));
    }

    function _deployRubricVotes() internal {
        RubricVotes _rubricVotes = new RubricVotes();

        vm.writeJson(
            vm.toString(address(_rubricVotes)), DEPLOYMENTS_DIR, string.concat(".", _network, ".", rubricVotesTag)
        );

        console2.log("RubricVotes address: %s", address(_rubricVotes));
    }

    function _deployEmptyExecution() internal {
        EmptyExecution _emptyExecution = new EmptyExecution();

        vm.writeJson(
            vm.toString(address(_emptyExecution)), DEPLOYMENTS_DIR, string.concat(".", _network, ".", emptyExecutionTag)
        );

        console2.log("Execution address: %s", address(_emptyExecution));
    }

    function _deployEmptyPoints() internal {
        EmptyPoints _emptyPoints = new EmptyPoints();

        vm.writeJson(
            vm.toString(address(_emptyPoints)), DEPLOYMENTS_DIR, string.concat(".", _network, ".", emptyPointTag)
        );

        console2.log("Points address: %s", address(_emptyPoints));
    }

    function _deployHatsAllowList() internal {
        HatsAllowList _hatsAllowList = new HatsAllowList();

        vm.writeJson(
            vm.toString(address(_hatsAllowList)), DEPLOYMENTS_DIR, string.concat(".", _network, ".", hatsAllowListTag)
        );

        console2.log("HatsAllowList address: %s", address(_hatsAllowList));
    }

    function _getDeployment(string memory _key) internal view returns (bytes memory) {
        string memory jsonString = vm.readFile(DEPLOYMENTS_DIR);

        console2.log("Network: ", _network);

        bytes memory jsonBytes = vm.parseJson(jsonString, string.concat(".", _network, ".", _key));

        return jsonBytes;
    }

    function factory() internal view returns (FastFactory) {
        bytes memory json = _getDeployment("factory");
        (address _fastFactory) = abi.decode(json, (address));

        return FastFactory(_fastFactory);
    }
}
