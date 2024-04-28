// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Hats} from "hats-protocol/Hats.sol";

import {Accounts} from "../setup/Accounts.t.sol";

contract HatsSetup is Accounts {
    struct HatWearer {
        address wearer;
        uint256 id;
    }

    Hats internal _hats;

    HatWearer internal _topHat;

    function __setupHats() public {
        _hats = new Hats("Devs Hats", "");

        uint256 topHatId = hats().mintTopHat(mockDAOAddr(), "Top Hat", "https://wwww/tophat.com/");
        _topHat = HatWearer(mockDAOAddr(), topHatId);

        hats().createHat()
    }

    function hats() public view returns (Hats) {
        return _hats;
    }
}
