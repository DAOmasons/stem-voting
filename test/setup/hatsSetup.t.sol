// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Hats} from "hats-protocol/Hats.sol";
import {IHats} from "hats-protocol/Interfaces/IHats.sol";

import {Accounts} from "../setup/Accounts.t.sol";

contract AdminEligibilityModule {
    IHats hats;

    constructor(address _hats) {
        hats = IHats(_hats);
    }

    function setStanding(uint256 _targetHatId, address _wearer, bool _newStanding) public {
        require(hats.isAdminOfHat(msg.sender, _targetHatId), "Only hat admin can set standing");

        hats.setHatWearerStatus(_targetHatId, _wearer, hats.isEligible(_wearer, _targetHatId), _newStanding);
    }

    function setEligibility(uint256 _targetHatId, address _wearer, bool _newEligibility) public {
        require(hats.isAdminOfHat(msg.sender, _targetHatId), "Only hat admin can set eligibility");

        hats.setHatWearerStatus(_targetHatId, _wearer, _newEligibility, hats.isInGoodStanding(_wearer, _targetHatId));
    }
}

contract HatsSetup is Accounts, Test {
    struct HatWearer {
        address wearer;
        uint256 id;
    }

    // //////////////////////
    // State
    // //////////////////////

    Hats internal _hats;
    AdminEligibilityModule internal _eligibility;
    address internal _toggle = makeAddr("toggle");

    HatWearer internal _topHat;

    HatWearer internal _facilitator1;
    HatWearer internal _facilitator2;
    HatWearer internal _facilitator3;

    // //////////////////////
    // Setup
    // //////////////////////

    function __setupHats() public {
        _hats = new Hats("Devs Hats", "");

        uint256 topHatId = hats().mintTopHat(mockDAOAddr(), "Top Hat", "https://wwww/tophat.com/");
        _topHat = HatWearer(mockDAOAddr(), topHatId);

        _eligibility = new AdminEligibilityModule(address(hats()));

        vm.startPrank(topHat().wearer);

        uint256 facilitatorId =
            hats().createHat(topHat().id, "Facilitator", 3, address(_eligibility), _toggle, true, "");

        hats().mintHat(facilitatorId, admin1());
        hats().mintHat(facilitatorId, admin2());
        hats().mintHat(facilitatorId, admin3());

        _facilitator1 = HatWearer(admin1(), facilitatorId);
        _facilitator2 = HatWearer(admin2(), facilitatorId);
        _facilitator3 = HatWearer(admin3(), facilitatorId);

        assertTrue(hats().isWearerOfHat(admin1(), facilitatorId));
        assertTrue(hats().isWearerOfHat(admin2(), facilitatorId));
        assertTrue(hats().isWearerOfHat(admin3(), facilitatorId));

        assertTrue(hats().isInGoodStanding(admin1(), facilitatorId));
        assertTrue(hats().isInGoodStanding(admin2(), facilitatorId));
        assertTrue(hats().isInGoodStanding(admin3(), facilitatorId));

        vm.stopPrank();
    }

    function hats() public view returns (Hats) {
        return _hats;
    }

    function eligibility() public view returns (AdminEligibilityModule) {
        return _eligibility;
    }

    // //////////////////////
    // Wearers
    // //////////////////////

    function topHat() public view returns (HatWearer memory) {
        return _topHat;
    }

    function facilitator1() public view returns (HatWearer memory) {
        return _facilitator1;
    }

    function facilitator2() public view returns (HatWearer memory) {
        return _facilitator2;
    }

    function facilitator3() public view returns (HatWearer memory) {
        return _facilitator3;
    }
}
