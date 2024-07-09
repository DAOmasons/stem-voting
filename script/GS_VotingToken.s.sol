// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Script, console2} from "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import {GSVotingToken} from "../src/factories/gsRough/GSVoteToken.sol";

contract ManageSBT is Script {
    using stdJson for string;

    string root = vm.projectRoot();
    string NETWORK_DIR = string.concat(root, "/deployments/gs_networkSpecific.json");

    string _network;

    function run() public {
        // Deploy the Voting Token

        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.rememberKey(pk);

        vm.startBroadcast(deployer);
        _setEnvString();
        // _deployToken();

        _mintToVoters();
        vm.stopBroadcast();
        // new GSVotingToken("GSVotingToken", "GSVoting", "GSV", 0, 0xacB3Afa9Ca0b4edeAc41a98E1F90ba6300b6D217);
    }

    function _setEnvString() internal {
        // string memory str = vm.envString(_key);

        uint256 key;

        assembly {
            key := chainid()
        }

        _network = vm.toString(key);
    }

    function _deployToken() internal {
        console2.log("Deploying Voting Token");
        new GSVotingToken("Grant Ships Voting Token", "GSV", 0, 0xacB3Afa9Ca0b4edeAc41a98E1F90ba6300b6D217);
    }

    function _mintToVoters() internal {
        GSVotingToken token = GSVotingToken(sbtTokenAddress());

        token.mint(0xAc8618BeECBd3C950e1f684bEe22969e38EC629F, 10_000e18);
        token.mint(0x0c19299D30AfC4748369c85f92ADC50D4df5B7b9, 10_000e18);
        token.mint(0xB336b490eeAB1e0Dd514d1160c791D26F23b1283, 10_000e18);
    }

    function _getNetworkConfigValue(string memory _key) internal view returns (bytes memory) {
        string memory jsonString = vm.readFile(NETWORK_DIR);

        bytes memory jsonBytes = vm.parseJson(jsonString, string.concat(".", _network, ".", _key));

        return jsonBytes;
    }

    function sbtTokenAddress() internal view returns (address) {
        bytes memory json = _getNetworkConfigValue("sbtTokenAddress");
        (address _sbtToken) = abi.decode(json, (address));
        return _sbtToken;
    }
}
