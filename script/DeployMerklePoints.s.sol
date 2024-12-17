// script/DeployMerklePoints.s.sol
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {MerklePoints} from "../src/modules/points/MerklePoints.sol";
import {console} from "forge-std/console.sol";

contract DeployMerklePoints is Script {
    // Replace this with the root from your TypeScript script
    bytes32 constant MERKLE_ROOT = 0xa058db2e5affe74298f18de54851c4f958a68b59a0ced4a9159cf8e4ee5f63ec; // your root here

    function run() external {
        vm.startBroadcast();

        MerklePoints merklePoints = new MerklePoints();
        merklePoints.initialize(msg.sender, abi.encode(MERKLE_ROOT));

        console.log("Contract deployed to:", address(merklePoints));

        vm.stopBroadcast();
    }
}
