// script/DeployMerklePoints.s.sol
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {MerklePoints} from "../src/modules/points/MerklePoints.sol";
import {console} from "forge-std/console.sol";

contract DeployMerklePoints is Script {
    // Replace this with the root from your TypeScript script
    bytes32 constant MERKLE_ROOT = 0xdc56428925fb0d14495de2f5d126f91282b8e6e69811397cf5b9f7e07f759902; // your root here

    function run() external {
        vm.startBroadcast();

        MerklePoints merklePoints = new MerklePoints();
        merklePoints.initialize(msg.sender, abi.encode(MERKLE_ROOT));

        console.log("Contract deployed to:", address(merklePoints));

        vm.stopBroadcast();
    }
}
