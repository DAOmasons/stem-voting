// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
}
