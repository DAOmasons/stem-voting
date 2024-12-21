// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MerklePoints} from "../../../src/modules/points/MerklePoints.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Accounts} from "../../setup/Accounts.t.sol";
import {MerkleSetup} from "../../setup/MerkleSetup.sol";

contract MerklePointsTest is Test, MerkleSetup {
    MerklePoints public merklePoints;
    address public contest;
    bytes32 public merkleRoot = 0xdc56428925fb0d14495de2f5d126f91282b8e6e69811397cf5b9f7e07f759902;

    address[] voters;
    bytes32[][] proofs;

    function setUp() public {
        contest = address(this);

        merklePoints = new MerklePoints();
        _setupVoters();
    }

    function _setupVoters() internal {
        voters.push(allowedUser1);
        voters.push(allowedUser2);
        voters.push(allowedUser3);
        voters.push(allowedUser4);
        voters.push(allowedUser5);

        proofs.push(proof1);
        proofs.push(proof2);
        proofs.push(proof3);
        proofs.push(proof4);
        proofs.push(proof5);
    }

    function test() public {
        // _setupVoters();
    }

    function testInit() public {
        _initialize();

        assert(merklePoints.merkleRoot() == merkleRoot);
        assert(merklePoints.contest() == contest);
    }

    function testVerify() public {
        _initialize();
        bool isValid = _verify();

        console.log("isValid", isValid);

        assertTrue(isValid);
    }

    function _verify() public returns (bool _isValid) {
        _isValid = merklePoints.verifyPoints(voters[0], 1000000000000000000, proofs[1]);
    }

    function _initialize() public {
        vm.startPrank(contest);
        merklePoints.initialize(contest, abi.encode(merkleRoot));
    }
}
