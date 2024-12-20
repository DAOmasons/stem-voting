// script/DeployMerklePoints.s.sol
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {MerklePoints} from "../src/modules/points/MerklePoints.sol";
import {console} from "forge-std/console.sol";

contract DeployMerklePoints is Script {
    // Replace this with the root from your TypeScript script
    bytes32 constant MERKLE_ROOT = 0xab743e2023cb59fbee44e8db2d954875524c9538e274ebb5b381aa02c39f481f; // your root here

    function run() external {
        vm.startBroadcast();

        MerklePoints merklePoints = new MerklePoints();
        merklePoints.initialize(msg.sender, abi.encode(MERKLE_ROOT));

        console.log("Contract deployed to:", address(merklePoints));

        vm.stopBroadcast();
    }
}
