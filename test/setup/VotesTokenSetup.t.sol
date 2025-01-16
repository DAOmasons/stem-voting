// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {ERC20Votes} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract ARBTokenSetupLive {
    ERC20Votes _arbToken;

    address _arbWhale;

    function __setupArbToken() public {
        _arbToken = ERC20Votes(0x912CE59144191C1204E64559FE8253a0e49E6548);
        // Binance Wallet on Arbitrum.
        // EOA with lots of ARB for testing live
        _arbWhale = 0xB38e8c17e38363aF6EbdCb3dAE12e0243582891D;
    }

    function arbToken() internal view returns (ERC20Votes) {
        return _arbToken;
    }

    function arbWhale() internal view returns (address) {
        return _arbWhale;
    }
}
