// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IFinalizationStrategy.sol";
import "./interfaces/IVotes.sol";
import "./interfaces/IPoints.sol";
import "./interfaces/IChoices.sol";
import "./interfaces/IContest.sol";

import {ContestStatus} from "./core/ContestStatus.sol";

contract Contest {
    IVotes public votesModule;

    IPoints public pointsModule;

    IChoices public choicesModule;

    ContestStatus public contestStatus;

    address public executionContract;

    bool public isContinuous;

    mapping(bytes32 => uint256) public choicesIdx;

    bytes32[] public choiceList;

    event ContestStarted(uint256 startTime, uint256 endTime);

    modifier onlyChoicesModule() {
        require(msg.sender == address(choicesModule), "Only choices contract");
        _;
    }

    modifier onlyVotingModule() {
        require(msg.sender == address(votesModule), "Only votes contract");
        _;
    }

    modifier onlyVotingPeriod() {
        require(
            contestStatus == ContestStatus.Voting || (contestStatus == ContestStatus.Continuous && isContinuous),
            "Contest is not in voting state"
        );
        _;
    }

    modifier onlyPopulatingPeriod() {
        require(
            contestStatus == ContestStatus.Populating || (contestStatus == ContestStatus.Continuous && isContinuous),
            "Contest is not in populating state"
        );
        _;
    }

    modifier onlyFinalized() {
        require(contestStatus == ContestStatus.Finalized, "Contest is not finalized");
        _;
    }

    constructor() {}

    function initialize(bytes memory _initData) public {
        (
            address _votesContract,
            address _pointsContract,
            address _choicesContract,
            address _executionContract,
            bool _isContinuous
        ) = abi.decode(_initData, (address, address, address, address, bool));

        votesModule = IVotes(_votesContract);
        pointsModule = IPoints(_pointsContract);
        choicesModule = IChoices(_choicesContract);
        executionContract = _executionContract;

        if (isContinuous) {
            contestStatus = ContestStatus.Continuous;
        } else {
            contestStatus = ContestStatus.Populating;
        }

        isContinuous = _isContinuous;
    }

    function claimPoints() public virtual onlyVotingPeriod {
        pointsModule.claimPoints();
    }

    function vote(bytes32 choiceId, uint256 amount, bytes memory _data) public virtual onlyVotingPeriod {
        pointsModule.allocatePoints(msg.sender, amount);
        votesModule.vote(msg.sender, choiceId, amount, _data);
    }

    function retractVote(bytes32 choiceId, uint256 amount, bytes memory _data) public virtual onlyVotingPeriod {
        pointsModule.releasePoints(msg.sender, amount);
        votesModule.retractVote(msg.sender, choiceId, amount, _data);
    }

    function changeVote(bytes32 oldChoiceId, bytes32 newChoiceId, uint256 amount, bytes memory _data)
        public
        virtual
        onlyVotingPeriod
    {
        retractVote(oldChoiceId, amount, _data);
        vote(newChoiceId, amount, _data);
    }

    function finalizeChoices() external onlyPopulatingPeriod onlyChoicesModule {
        contestStatus = ContestStatus.Voting;
    }

    function finalizeVotes() external onlyVotingPeriod onlyVotingModule {
        contestStatus = ContestStatus.Finalized;
    }

    function execute() public virtual onlyFinalized {
        contestStatus = ContestStatus.Executed;
    }
}
