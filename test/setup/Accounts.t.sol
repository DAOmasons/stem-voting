// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/StdCheats.sol";

contract Accounts is StdCheats {
    // //////////////////////
    // Vote Admins
    // //////////////////////

    function admin1() public returns (address) {
        return makeAddr("admin_1");
    }

    function admin2() public returns (address) {
        return makeAddr("admin_2");
    }

    function admin3() public returns (address) {
        return makeAddr("admin_3");
    }

    // //////////////////////
    // Voters
    // //////////////////////

    function voter1() public returns (address) {
        return makeAddr("voter_1");
    }

    function voter2() public returns (address) {
        return makeAddr("voter_2");
    }

    function voter3() public returns (address) {
        return makeAddr("voter_3");
    }

    function voter4() public returns (address) {
        return makeAddr("voter_4");
    }

    function voter5() public returns (address) {
        return makeAddr("voter_5");
    }

    function voter6() public returns (address) {
        return makeAddr("voter_6");
    }

    function voter7() public returns (address) {
        return makeAddr("voter_7");
    }

    function voter8() public returns (address) {
        return makeAddr("voter_8");
    }

    function voter9() public returns (address) {
        return makeAddr("voter_9");
    }

    function voter10() public returns (address) {
        return makeAddr("voter_10");
    }

    // //////////////////////
    // Mocks
    // //////////////////////

    function mockContest() public returns (address) {
        return makeAddr("mock_contest");
    }

    //////////////////////
    // Choices
    //////////////////////

    function choice1() public pure returns (bytes32) {
        return keccak256(abi.encodePacked("choiceId"));
    }

    function choice2() public pure returns (bytes32) {
        return keccak256(abi.encodePacked("choiceId2"));
    }

    function choice3() public pure returns (bytes32) {
        return keccak256(abi.encodePacked("choiceId3"));
    }

    function choice4() public pure returns (bytes32) {
        return keccak256(abi.encodePacked("choiceId4"));
    }

    function choice5() public pure returns (bytes32) {
        return keccak256(abi.encodePacked("choiceId5"));
    }

    function choice6() public pure returns (bytes32) {
        return keccak256(abi.encodePacked("choiceId6"));
    }
}
