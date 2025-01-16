// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IGTC} from "../../src/interfaces/IGTC.sol";

contract GTCTokenSetup {
    IGTC _gtc;

    address _gtcWhale;

    function __setupGTCToken() public {
        _gtc = IGTC(0x7f9a7DB853Ca816B9A138AEe3380Ef34c437dEe0);

        _gtcWhale = 0xd2747B3e715483A870793a6Cfa04006C00Cd597D;
    }

    function gtcToken() public view returns (IGTC) {
        return _gtc;
    }

    function gtcWhale() public view returns (address) {
        return _gtcWhale;
    }
}
