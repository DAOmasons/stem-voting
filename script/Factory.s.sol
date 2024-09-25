// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import "forge-std/StdJson.sol";

import {FastFactory} from "../src/factories/gsRough/FastFactory.sol";

contract RunFactory is Script {
    string _network;

    using stdJson for string;

    string root = vm.projectRoot();

    string DEPLOYMENTS_DIR = string.concat(root, "/deployments/factory.json");

    function run() external {
        console2.log("Deploying factory...");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.rememberKey(pk);

        _setEnvString();

        vm.startBroadcast(deployer);

        _deployFactory(deployer);

        vm.stopBroadcast();
    }

    function _setEnvString() internal {
        uint256 key;

        assembly {
            key := chainid()
        }

        _network = vm.toString(key);
    }

    function _deployFactory(address _deployer) internal {
        FastFactory _fastFactory = new FastFactory(_deployer);

        vm.writeJson(vm.toString(address(_fastFactory)), DEPLOYMENTS_DIR, string.concat(".", _network, ".factory"));

        console2.log("Factory address: %s", address(_fastFactory));
    }

    function _getDeployment(string memory _key) internal view returns (bytes memory) {
        string memory jsonString = vm.readFile(DEPLOYMENTS_DIR);

        bytes memory jsonBytes = vm.parseJson(jsonString, string.concat(".", _network, ".", _key));

        return jsonBytes;
    }

    function factory() internal view returns (FastFactory) {
        bytes memory json = _getDeployment("factory");
        (address _fastFactory) = abi.decode(json, (address));

        return FastFactory(_fastFactory);
    }
}
