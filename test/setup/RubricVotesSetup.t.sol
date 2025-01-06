// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Accounts} from "./Accounts.t.sol";
import {Hats} from "lib/hats-protocol/src/Hats.sol";
import {FastFactory} from "../../src/factories/gsRough/FastFactory.sol";
import {Contest} from "../../src/Contest.sol";
import {HatsAllowList} from "../../src/modules/choices/HatsAllowList.sol";
import {Metadata} from "../../src/core/Metadata.sol";
import {ContestStatus} from "../../src/core/ContestStatus.sol";
import {RubricVotes} from "../../src/modules/votes/RubricVotes.sol";
import {EmptyPoints} from "../../src/modules/points/EmptyPoints.sol";
import {EmptyExecution} from "../../src/modules/execution/EmptyExecution.sol";

contract RubricVotesSetup is Test, Accounts {
    address[] _judges;
    address[] _admins;

    uint256 constant MVPC = 1e18;

    Hats hats;
    uint256 topHatId;
    uint256 adminHatId;
    uint256 judgeHatId;

    FastFactory _factory;
    Contest _contest;
    HatsAllowList _choicesModule;
    EmptyPoints _pointsModule;
    RubricVotes _votesModule;
    EmptyExecution _executionModule;

    Metadata _mockMetadata = Metadata(1, "qm....");

    function __deployRubricVotes() internal {
        _setupHats();
        _lauchElection();
    }

    function _lauchElection() private {
        vm.startPrank(stemAdmin1());

        _factory = new FastFactory(stemAdmin1());
        factory().addAdmin(stemAdmin2());

        Contest _contestImpl = new Contest();
        HatsAllowList _choicesImpl = new HatsAllowList();
        EmptyPoints _pointsImpl = new EmptyPoints();
        RubricVotes _votesImpl = new RubricVotes();
        EmptyExecution _executionImpl = new EmptyExecution();

        factory().setContestTemplate(_contestImpl.CONTEST_VERSION(), address(_contestImpl), _mockMetadata);
        factory().setModuleTemplate(_choicesImpl.MODULE_NAME(), address(_choicesImpl), _mockMetadata);
        factory().setModuleTemplate(_pointsImpl.MODULE_NAME(), address(_pointsImpl), _mockMetadata);
        factory().setModuleTemplate(_votesImpl.MODULE_NAME(), address(_votesImpl), _mockMetadata);
        factory().setModuleTemplate(_executionImpl.MODULE_NAME(), address(_executionImpl), _mockMetadata);

        vm.stopPrank();

        assertTrue(factory().admins(stemAdmin1()));
        assertTrue(factory().admins(stemAdmin2()));

        assertTrue(factory().contestTemplates(_contestImpl.CONTEST_VERSION()) == address(_contestImpl));
        assertTrue(factory().moduleTemplates(_choicesImpl.MODULE_NAME()) == address(_choicesImpl));
        assertTrue(factory().moduleTemplates(_pointsImpl.MODULE_NAME()) == address(_pointsImpl));
        assertTrue(factory().moduleTemplates(_votesImpl.MODULE_NAME()) == address(_votesImpl));
        assertTrue(factory().moduleTemplates(_executionImpl.MODULE_NAME()) == address(_executionImpl));

        bytes[4] memory moduleData;
        string[4] memory moduleNames;
        bytes[] memory _noPrepPopData = new bytes[](0);

        // votes module data
        moduleData[0] = abi.encode(adminHatId, judgeHatId, MVPC, address(hats));
        moduleNames[0] = _votesImpl.MODULE_NAME();

        // points module data
        moduleData[1] = "";
        moduleNames[1] = _pointsImpl.MODULE_NAME();

        // choices module data
        moduleData[2] = abi.encode(address(hats), adminHatId, _noPrepPopData);
        moduleNames[2] = _choicesImpl.MODULE_NAME();

        // execution module data
        moduleData[3] = abi.encode("");
        moduleNames[3] = _executionImpl.MODULE_NAME();

        bytes memory _contestInitData = abi.encode(moduleNames, moduleData);

        (address _contestAddress, address[4] memory moduleAddress) = factory().buildContest(
            _mockMetadata,
            _contestInitData,
            _contestImpl.CONTEST_VERSION(),
            ContestStatus.Populating,
            true,
            "gg-application-select"
        );

        _contest = Contest(_contestAddress);
        _votesModule = RubricVotes(moduleAddress[0]);
        _pointsModule = EmptyPoints(moduleAddress[1]);
        _choicesModule = HatsAllowList(moduleAddress[2]);
        _executionModule = EmptyExecution(moduleAddress[3]);
    }

    function _setupHats() private {
        hats = new Hats("", "");

        topHatId = hats.mintTopHat(dummyDao(), "", "");

        vm.prank(dummyDao());
        adminHatId = hats.createHat(topHatId, "admin", 100, address(13), address(13), true, "");

        _admins.push(admin1());
        _admins.push(admin2());

        uint256[] memory adminIds = new uint256[](_admins.length);

        adminIds[0] = adminHatId;
        adminIds[1] = adminHatId;

        vm.prank(dummyDao());
        hats.batchMintHats(adminIds, _admins);

        vm.prank(admin1());
        judgeHatId = hats.createHat(adminHatId, "judge", 100, address(13), address(13), true, "");

        _judges.push(judge1());
        _judges.push(judge2());
        _judges.push(judge3());

        uint256[] memory judgeIds = new uint256[](_judges.length);

        judgeIds[0] = judgeHatId;
        judgeIds[1] = judgeHatId;
        judgeIds[2] = judgeHatId;

        vm.prank(dummyDao());
        hats.batchMintHats(judgeIds, _judges);
    }

    function factory() internal view returns (FastFactory) {
        return _factory;
    }

    function contest() internal view returns (Contest) {
        return _contest;
    }

    function choicesModule() internal view returns (HatsAllowList) {
        return _choicesModule;
    }

    function pointsModule() internal view returns (EmptyPoints) {
        return _pointsModule;
    }

    function votesModule() internal view returns (RubricVotes) {
        return _votesModule;
    }

    function executionModule() internal view returns (EmptyExecution) {
        return _executionModule;
    }
}
