// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MerklePoints} from "../../../src/modules/points/MerklePoints.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Accounts} from "../../setup/Accounts.t.sol";
import {MerkleSetup} from "../../setup/MerkleSetup.sol";
import {Metadata} from "../../../src/core/Metadata.sol";

contract MerklePointsTest is Test, MerkleSetup {
    MerklePoints public merklePoints;
    address public contest;
    bytes32 public merkleRoot = 0xdc56428925fb0d14495de2f5d126f91282b8e6e69811397cf5b9f7e07f759902;

    address[] voters;
    bytes32[][] proofs;

    Metadata _reason = Metadata(1, "reason");

    function setUp() public {
        contest = address(this);

        merklePoints = new MerklePoints();
        _setupVoters();
    }

    //////////////////////////////
    // Unit Tests
    //////////////////////////////

    function testInit() public {
        _initialize();

        assert(merklePoints.merkleRoot() == merkleRoot);
        assert(merklePoints.contest() == contest);
    }

    function testSingleVote() public {
        _initialize();
        _allocatePoints(0);

        assert(merklePoints.allocatedPoints(voters[0]) == 1e18);
    }

    function testPartialVotes() public {
        _initialize();
        merklePoints.allocatePoints(voters[0], 0.5e18, abi.encode(abi.encode(_reason), abi.encode(proofs[0], 1e18)));
        merklePoints.allocatePoints(voters[0], 0.5e18, abi.encode(abi.encode(_reason), abi.encode(proofs[0], 1e18)));
    }

    function testAllVoters() public {
        _initialize();
        _allocatePoints(0);
        _allocatePoints(1);
        _allocatePoints(2);
        _allocatePoints(3);
        _allocatePoints(4);

        assert(merklePoints.allocatedPoints(voters[0]) == 1e18);
        assert(merklePoints.allocatedPoints(voters[1]) == 1e18);
        assert(merklePoints.allocatedPoints(voters[2]) == 1e18);
        assert(merklePoints.allocatedPoints(voters[3]) == 1e18);
        assert(merklePoints.allocatedPoints(voters[4]) == 1e18);
    }

    function testRetractSingle() public {
        _initialize();
        _allocatePoints(0);

        assert(merklePoints.allocatedPoints(voters[0]) == 1e18);

        _retractPoints(0);

        assert(merklePoints.allocatedPoints(voters[0]) == 0);
    }

    function testRetractAll() public {
        _initialize();
        _allocatePoints(0);
        _allocatePoints(1);
        _allocatePoints(2);
        _allocatePoints(3);
        _allocatePoints(4);

        assert(merklePoints.allocatedPoints(voters[0]) == 1e18);
        assert(merklePoints.allocatedPoints(voters[1]) == 1e18);
        assert(merklePoints.allocatedPoints(voters[2]) == 1e18);
        assert(merklePoints.allocatedPoints(voters[3]) == 1e18);
        assert(merklePoints.allocatedPoints(voters[4]) == 1e18);

        _retractPoints(0);
        _retractPoints(1);
        _retractPoints(2);
        _retractPoints(3);
        _retractPoints(4);

        assert(merklePoints.allocatedPoints(voters[0]) == 0);
        assert(merklePoints.allocatedPoints(voters[1]) == 0);
        assert(merklePoints.allocatedPoints(voters[2]) == 0);
        assert(merklePoints.allocatedPoints(voters[3]) == 0);
        assert(merklePoints.allocatedPoints(voters[4]) == 0);
    }

    //////////////////////////////
    // Reverts
    //////////////////////////////

    //////////////////////////////
    // Adversarial
    //////////////////////////////

    // try to vote with more voting power than you actually have.
    function testRevert_spoofAmount() public {
        _initialize();

        vm.expectRevert("User input data does not match merkle proof");
        merklePoints.allocatePoints(voters[0], 2e18, abi.encode(abi.encode(_reason), abi.encode(proofs[0], 2e18)));
    }

    //////////////////////////////
    // Getters
    //////////////////////////////

    function testVerify() public {
        _initialize();
        bool isValid = _verify();

        assertTrue(isValid);
    }

    //////////////////////////////
    // Helpers
    //////////////////////////////

    function _retractPoints(uint256 _index) public {
        merklePoints.releasePoints(voters[_index], 1e18, "");
    }

    function _allocatePoints(uint256 _index) public {
        merklePoints.allocatePoints(
            voters[_index], 1e18, abi.encode(abi.encode(_reason), abi.encode(proofs[_index], 1e18))
        );
    }

    function _verify() public view returns (bool _isValid) {
        _isValid = merklePoints.verifyPoints(voters[0], 1e18, proofs[0]);
    }

    function _initialize() public {
        vm.startPrank(contest);
        merklePoints.initialize(contest, abi.encode(merkleRoot));
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
}
