// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MerkleSetup} from "./MerkleSetup.sol";
import {ContestStatus} from "../../src/core/ContestStatus.sol";

import {FastFactory} from "../../src/factories/gsRough/FastFactory.sol";
import {Metadata} from "../../src/core/Metadata.sol";
import {Contest} from "../../src/Contest.sol";
import {OpenChoices} from "../../src/modules/choices/OpenChoices.sol";
import {MerklePoints} from "../../src/modules/points/MerklePoints.sol";
import {TimedVotesV1} from "../../src/modules/votes/TimedVotesV1.sol";
import {TopChoiceHatter} from "../../src/modules/execution/TopChoiceHatter.sol";
import {TimerType} from "../../src/modules/votes/utils/VoteTimer.sol";
import {Hats} from "lib/hats-protocol/src/Hats.sol";

contract GGSetup is MerkleSetup, Test {
    address[] _voters;
    bytes32[][] _voterProofs;
    uint256 constant VOTE_AMOUNT = 1e18;
    uint256 constant TWO_WEEKS = 1209600;
    bytes32 public merkleRoot = 0xdc56428925fb0d14495de2f5d126f91282b8e6e69811397cf5b9f7e07f759902;

    Hats hats;
    uint256 topHatId;
    uint256 adminHatId;
    uint256 judgeHatId;
    address[] admins;

    FastFactory _factory;
    Contest _contest;
    OpenChoices _choicesModule;
    MerklePoints _pointsModule;
    TimedVotesV1 _votesModule;
    TopChoiceHatter _executionModule;
    Metadata _mockMetadata = Metadata(1, "qm....");

    function __deployGGElections() internal {
        _setupVoters();
        _setupHats();
        _launchElection();
    }

    function _launchElection() internal {
        vm.startPrank(stemAdmin1());

        _factory = new FastFactory(stemAdmin1());
        factory().addAdmin(stemAdmin2());

        Contest _contestImpl = new Contest();
        OpenChoices _choicesImpl = new OpenChoices();
        MerklePoints _pointsImpl = new MerklePoints();
        TimedVotesV1 _votesImpl = new TimedVotesV1();
        TopChoiceHatter _executionImpl = new TopChoiceHatter();

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

        // votes module data
        moduleData[0] = abi.encode(TWO_WEEKS, 0, TimerType.Auto, adminHatId, address(hats));
        moduleNames[0] = _votesImpl.MODULE_NAME();

        // points module data
        moduleData[1] = abi.encode(merkleRoot);
        moduleNames[1] = _pointsImpl.MODULE_NAME();

        // choices module data
        moduleData[2] = abi.encode(address(hats), adminHatId, true);
        moduleNames[2] = _choicesImpl.MODULE_NAME();

        // execution module data
        moduleData[3] = abi.encode(judgeHatId, adminHatId, 3, address(hats));
        moduleNames[3] = _executionImpl.MODULE_NAME();

        bytes memory _contestInitData = abi.encode(moduleNames, moduleData);

        (address _contestAddress, address[4] memory moduleAddress) = factory().buildContest(
            _mockMetadata,
            _contestInitData,
            _contestImpl.CONTEST_VERSION(),
            ContestStatus.Populating,
            true,
            "gg-election"
        );

        _contest = Contest(_contestAddress);
        _choicesModule = OpenChoices(moduleAddress[2]);
        _pointsModule = MerklePoints(moduleAddress[1]);
        _votesModule = TimedVotesV1(moduleAddress[0]);
        _executionModule = TopChoiceHatter(moduleAddress[3]);
    }

    function _setupVoters() internal {
        _voters.push(allowedUser1);
        _voters.push(allowedUser2);
        _voters.push(allowedUser3);
        _voters.push(allowedUser4);
        _voters.push(allowedUser5);

        _voterProofs.push(proof1);
        _voterProofs.push(proof2);
        _voterProofs.push(proof3);
        _voterProofs.push(proof4);
        _voterProofs.push(proof5);
    }

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
    }

    function openChoices() public view returns (OpenChoices) {
        return _choicesModule;
    }

    function merklePoints() public view returns (MerklePoints) {
        return _pointsModule;
    }

    function timedVotes() public view returns (TimedVotesV1) {
        return _votesModule;
    }

    function hatterExecution() public view returns (TopChoiceHatter) {
        return _executionModule;
    }

    function contest() public view returns (Contest) {
        return _contest;
    }

    function factory() public view returns (FastFactory) {
        return _factory;
    }

    function voter(uint256 _index) public view returns (address) {
        return _voters[_index];
    }

    function voterProof(uint256 _index) public view returns (bytes32[] memory) {
        return _voterProofs[_index];
    }
}
