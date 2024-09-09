// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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
        // _setEnvString();
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
        GSVotingToken token = GSVotingToken(0x1Bb2f247fAa9D2C9aE9c98d941D1049b0a7d7540);

        // // Projects
        // token.mint(0x80bB9ae0cC89FdB7d197a92c190cf69B3bd267F1, 5506e18);
        // token.mint(0xED47B5f719eA74405Eb96ff700C11D1685b953B1, 10031e18);
        // token.mint(0xEb1b4d0Fb00287E2168983Df9B20DEb24Df5165A, 4831e18);
        // token.mint(0x627Bcf9Ba14B621f6621Ae62dF9cfdD1e4df6E06, 4818e18);
        // token.mint(0xa345C3Fd5d34047eEf8D96C1Cd61B79e45A4Cc40, 4474e18);
        // token.mint(0x41D2a18E1DdACdAbFDdADB62e9AEE67c63070b76, 2839e18);
        // token.mint(0x4b7866e717f27Fa1C38313D25F647aE0598571BD, 2588e18);
        // token.mint(0xeBdaaF37Ad563201F1b0FD8521214cb6A031D65C, 4917e18);

        // // Ships
        // token.mint(0x68c9e2a623fC56e96626c939009DD3Ec8cd2A14f, 6667e18);
        // token.mint(0xb62E762Af637b49Eb4870BCe8fE21bffF189e495, 6667e18);
        // token.mint(0x2aa64E6d80390F5C017F0313cB908051BE2FD35e, 6667e18);

        // // Judges & Community
        // token.mint(0x5fB2A7793A08dE719b0b750fb2961F1281D893a5, 3636e18);
        // token.mint(0x00De4B13153673BCAE2616b67bf822500d325Fc3, 3636e18);
        // token.mint(0xC3268DDB8E38302763fFdC9191FCEbD4C948fe1b, 3636e18);
        // token.mint(0x15C6AC4Cf1b5E49c44332Fb0a1043Ccab19db80a, 3636e18);
        // token.mint(0x516cAfD745Ec780D20f61c0d71fe258eA765222D, 3636e18);
        // token.mint(0x603185043f3B4E1342B734dFE77c0d3e0297fC7a, 3636e18);
        // token.mint(0xCED608Aa29bB92185D9b6340Adcbfa263DAe075b, 3636e18);
        token.mint(0xdfBecC0b4aEF80b96Da27aB483feb0892472eaC2, 3636e18);
        // token.mint(0xcBf407C33d68a55CB594Ffc8f4fD1416Bba39DA5, 3636e18);
        // token.mint(0x1421d52714B01298E2e9AA969e14c9317B3E1CFA, 3636e18);
        // token.mint(0x01Cf9fD2efa5Fdf178bd635c3E2adF25B2052712, 3636e18);
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
