// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MerklePoints} from "../../../src/modules/points/MerklePoints.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Accounts} from "../../setup/Accounts.t.sol";

contract MerklePointsTest is Test, Accounts {
    MerklePoints public merklePoints;
    address public contest;
    bytes32 public merkleRoot;

    address[] voters;
    uint256[] points;
    bytes32[] leaves;

    function setUp() public {
        contest = address(this);
        _setupVoters();

        console.log("\n=== Setting up voters ===");
        for (uint256 i = 0; i < voters.length; i++) {
            console.log("Voter", i, "address:");
            console.log(voters[i]);
            console.log("Voter", i, "points:", points[i]);
            console.log("Voter", i, "leaf:");
            console.logBytes32(leaves[i]);
            console.log("---");
        }

        merkleRoot = _calculateMerkleRoot(leaves);
        console.log("\nCalculated Merkle Root:");
        console.logBytes32(merkleRoot);

        merklePoints = new MerklePoints();
        // vm.expectEmit(true, true, true, true);
        // emit Initialized(contest, merkleRoot);
        merklePoints.initialize(contest, abi.encode(merkleRoot));
    }

    function testVerifyPointsForSingleVoter() public {
        // Test with just the first voter
        uint256 voterIndex = 4;
        address voter = voters[voterIndex];
        uint256 voterPoints = points[voterIndex];

        // console.log("\n=== Testing Single Voter ===");
        // console.log("Voter Address:", voter);
        // console.log("Voter Points:", voterPoints);

        // Log the leaf calculation
        bytes32 expectedLeaf = keccak256(abi.encodePacked(voter, voterPoints));
        // console.log("Expected Leaf: ");
        // console.logBytes32(expectedLeaf);

        // console.log("Stored Leaf:");
        // console.logBytes32(leaves[voterIndex]);

        // Generate and log proof
        bytes32[] memory proof = _generateProof(voterIndex);
        // console.log("\nProof Elements:");
        for (uint256 i = 0; i < proof.length; i++) {
            // console.log("Proof", i, ":");
            // console.logBytes32(proof[i]);
        }

        // Verify the path manually
        bytes32 currentHash = expectedLeaf;
        // console.log("\nVerification Path:");
        // console.log("Start with leaf:");
        console.logBytes32(currentHash);

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            if (uint256(currentHash) < uint256(proofElement)) {
                currentHash = keccak256(abi.encodePacked(currentHash, proofElement));
                // console.log("Hash left:");
                // console.logBytes32(currentHash);
            } else {
                currentHash = keccak256(abi.encodePacked(proofElement, currentHash));
                // console.log("Hash right:");
                // console.logBytes32(currentHash);
            }
        }

        // console.log("Final Hash:");
        // console.logBytes32(currentHash);
        // console.log("Expected Root:");
        // console.logBytes32(merkleRoot);

        // Perform the actual verification
        bool result = merklePoints.verifyPoints(voter, voterPoints, proof);
        // console.log("\nVerification Result:", result);
        assertTrue(result, "Merkle proof verification failed");
    }

    function testInvalidUserVerification() public {
        // Create a random address that isn't in our voter list
        address invalidUser = makeAddr("invalidUser");
        uint256 attemptedPoints = 100;

        console.log("\n=== Testing Invalid User ===");
        console.log("Invalid User Address:", invalidUser);
        console.log("Attempted Points:", attemptedPoints);

        // Try using the first voter's proof (it shouldn't work)
        bytes32[] memory proof = _generateProof(0);

        bool result = merklePoints.verifyPoints(invalidUser, attemptedPoints, proof);
        console.log("Verification Result (should be false):", result);

        assertTrue(!result, "Verification should fail for invalid user");

        // Also try with zero points
        result = merklePoints.verifyPoints(invalidUser, 0, proof);
        console.log("Verification Result with 0 points (should be false):", result);
        assertTrue(!result, "Verification should fail for invalid user with 0 points");

        // Try with a different amount of points
        result = merklePoints.verifyPoints(invalidUser, 1000, proof);
        console.log("Verification Result with different points (should be false):", result);
        assertTrue(!result, "Verification should fail for invalid user with different points");
    }

    function testAllVotersVerification() public {
        console.log("\n=== Testing All Voters ===");
        for (uint256 i = 0; i < voters.length; i++) {
            bytes32[] memory proof = _generateProof(i);

            console.log("\nTesting voter", i);
            console.log("Address:");
            console.log(voters[i]);
            console.log("Points:", points[i]);
            console.log("Proof elements:");
            for (uint256 j = 0; j < proof.length; j++) {
                console.log("Proof element", j);
                console.logBytes32(proof[j]);
            }

            bool result = merklePoints.verifyPoints(voters[i], points[i], proof);
            console.log("Verification result:", result);
            assertTrue(result, string.concat("Verification failed for voter ", vm.toString(i)));
        }
    }

    function _setupVoters() internal {
        voters = new address[](5);
        points = new uint256[](5);
        leaves = new bytes32[](5);

        voters[0] = voter1();
        voters[1] = voter2();
        voters[2] = voter3();
        voters[3] = voter4();
        voters[4] = voter5();

        for (uint256 i = 0; i < voters.length; i++) {
            points[i] = (i + 1) * 100;
            leaves[i] = keccak256(abi.encodePacked(voters[i], points[i]));
        }
    }

    function _calculateMerkleRoot(bytes32[] memory _leaves) internal pure returns (bytes32) {
        require(_leaves.length > 0, "No leaves");

        bytes32[] memory currentLevel = _leaves;

        while (currentLevel.length > 1) {
            uint256 nextLevelSize = (currentLevel.length + 1) / 2;
            bytes32[] memory nextLevel = new bytes32[](nextLevelSize);

            for (uint256 i = 0; i < currentLevel.length - 1; i += 2) {
                bytes32 left = currentLevel[i];
                bytes32 right = currentLevel[i + 1];
                nextLevel[i / 2] =
                    left < right ? keccak256(abi.encodePacked(left, right)) : keccak256(abi.encodePacked(right, left));
            }

            if (currentLevel.length % 2 == 1) {
                nextLevel[nextLevelSize - 1] = currentLevel[currentLevel.length - 1];
            }

            currentLevel = nextLevel;
        }

        return currentLevel[0];
    }

    function _generateProof(uint256 index) internal view returns (bytes32[] memory) {
        require(index < leaves.length, "Index out of bounds");

        uint256 numLevels = 0;
        uint256 n = leaves.length;
        while (n > 1) {
            n = (n + 1) / 2;
            numLevels++;
        }

        bytes32[] memory proof = new bytes32[](numLevels);
        uint256 proofIndex = 0;
        uint256 currentIndex = index;
        bytes32[] memory currentLevel = leaves;

        while (currentLevel.length > 1) {
            uint256 nextLevelSize = (currentLevel.length + 1) / 2;
            bytes32[] memory nextLevel = new bytes32[](nextLevelSize);

            for (uint256 i = 0; i < currentLevel.length - 1; i += 2) {
                bytes32 left = currentLevel[i];
                bytes32 right = currentLevel[i + 1];
                nextLevel[i / 2] =
                    left < right ? keccak256(abi.encodePacked(left, right)) : keccak256(abi.encodePacked(right, left));

                if (currentIndex == i || currentIndex == i + 1) {
                    proof[proofIndex++] = currentLevel[currentIndex ^ 1];
                    currentIndex = i / 2;
                }
            }

            if (currentLevel.length % 2 == 1) {
                nextLevel[nextLevelSize - 1] = currentLevel[currentLevel.length - 1];
                if (currentIndex == currentLevel.length - 1) {
                    currentIndex = nextLevelSize - 1;
                }
            }

            currentLevel = nextLevel;
        }

        return proof;
    }
}
