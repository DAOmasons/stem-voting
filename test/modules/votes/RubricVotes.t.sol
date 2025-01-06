// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Hats} from "lib/hats-protocol/src/Hats.sol";
import {Accounts} from "../../setup/Accounts.t.sol";

contract RubricVotesTest is Test, Accounts {
    Hats hats;
    uint256 topHatId;
    uint256 adminHatId;
    uint256 judgeHatId;
    address[] admins;
    address[] judges;

    function setUp() public {
        _setupHats();
    }

    function test() public {}

    function _setupHats() private {
        hats = new Hats("", "");

        topHatId = hats.mintTopHat(dummyDao(), "", "");

        vm.prank(dummyDao());
        adminHatId = hats.createHat(topHatId, "admin", 100, address(13), address(13), true, "");

        admins.push(admin1());
        admins.push(admin2());

        uint256[] memory adminIds = new uint256[](admins.length);

        adminIds[0] = adminHatId;
        adminIds[1] = adminHatId;

        vm.prank(dummyDao());
        hats.batchMintHats(adminIds, admins);

        vm.prank(admin1());
        judgeHatId = hats.createHat(adminHatId, "judge", 100, address(13), address(13), true, "");

        judges.push(judge1());
        judges.push(judge2());
        judges.push(judge3());

        uint256[] memory judgeIds = new uint256[](judges.length);

        judgeIds[0] = judgeHatId;
        judgeIds[1] = judgeHatId;
        judgeIds[2] = judgeHatId;

        vm.prank(dummyDao());
        hats.batchMintHats(judgeIds, judges);

        assertTrue(hats.isWearerOfHat(admin1(), adminHatId));
        assertTrue(hats.isWearerOfHat(admin2(), adminHatId));
        assertTrue(hats.isWearerOfHat(judge1(), judgeHatId));
        assertTrue(hats.isWearerOfHat(judge2(), judgeHatId));
        assertTrue(hats.isWearerOfHat(judge3(), judgeHatId));
    }
}
