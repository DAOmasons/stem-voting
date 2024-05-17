// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ReentrancyGuard} from "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

import "./interfaces/IFinalizationStrategy.sol";
import "./interfaces/IVotes.sol";
import "./interfaces/IPoints.sol";
import "./interfaces/IChoices.sol";
import "./interfaces/IContest.sol";

import {ContestStatus} from "./core/ContestStatus.sol";

contract Contest is ReentrancyGuard {
    string public constant CONTEST_VERSION = "0.1.0";

    IVotes public votesModule;

    IPoints public pointsModule;

    IChoices public choicesModule;

    address public executionModule;

    ContestStatus public contestStatus;

    bool public isContinuous;

    bool public isRetractable;

    mapping(bytes32 => uint256) public choicesIdx;

    bytes32[] public choiceList;

    event ContestStarted(uint256 startTime, uint256 endTime);

    modifier onlyVotingPeriod() {
        require(
            contestStatus == ContestStatus.Voting || (contestStatus == ContestStatus.Continuous && isContinuous),
            "Contest is not in voting state"
        );
        _;
    }

    modifier onlyValidChoice(bytes32 choiceId) {
        require(choicesModule.isValidChoice(choiceId), "Choice does not exist");
        _;
    }

    modifier onlyCanAllocate(address _voter, uint256 _amount) {
        require(pointsModule.hasVotingPoints(_voter, _amount), "Insufficient points available");
        _;
    }

    modifier onlyHasAllocated(address _voter, uint256 _amount) {
        require(pointsModule.hasAllocatedPoints(_voter, _amount), "Insufficient points allocated");
        _;
    }

    modifier onlyContestRetractable() {
        require(isRetractable, "Votes are not retractable");
        _;
    }

    constructor() {}

    function initialize(bytes memory _initData) public {
        (
            address _votesContract,
            address _pointsContract,
            address _choicesContract,
            address _executionContract,
            bool _isContinuous,
            bool _isRetractable
        ) = abi.decode(_initData, (address, address, address, address, bool, bool));

        votesModule = IVotes(_votesContract);
        pointsModule = IPoints(_pointsContract);
        choicesModule = IChoices(_choicesContract);
        executionModule = _executionContract;
        isRetractable = _isRetractable;

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

    function vote(bytes32 choiceId, uint256 amount, bytes memory _data)
        public
        virtual
        nonReentrant
        onlyVotingPeriod
        onlyValidChoice(choiceId)
        onlyCanAllocate(msg.sender, amount)
    {
        _vote(choiceId, amount, _data);
    }

    function retractVote(bytes32 choiceId, uint256 amount, bytes memory _data)
        public
        virtual
        nonReentrant
        onlyVotingPeriod
        onlyContestRetractable
        onlyValidChoice(choiceId)
        onlyHasAllocated(msg.sender, amount)
    {
        _retractVote(choiceId, amount, _data);
    }

    function changeVote(bytes32 _oldChoiceId, bytes32 _newChoiceId, uint256 _amount, bytes memory _data)
        public
        virtual
        nonReentrant
        onlyVotingPeriod
        onlyContestRetractable
        onlyValidChoice(_oldChoiceId)
        onlyValidChoice(_newChoiceId)
        onlyHasAllocated(msg.sender, _amount)
    {
        _retractVote(_oldChoiceId, _amount, _data);

        // Review: Is this proveably redundant? Or does this serve a purpose for CEI?
        require(pointsModule.hasVotingPoints(msg.sender, _amount), "Insufficient points available");
        _vote(_newChoiceId, _amount, _data);
    }

    function batchVote(bytes32[] memory choiceIds, uint256[] memory amounts, bytes[] memory _data, uint256 _totalAmount)
        public
        virtual
        nonReentrant
        onlyVotingPeriod
        onlyCanAllocate(msg.sender, _totalAmount)
    {
        require(
            choiceIds.length == amounts.length && choiceIds.length == _data.length,
            "Array mismatch: Invalid input length"
        );

        uint256 totalAmount = 0;

        for (uint256 i = 0; i < choiceIds.length;) {
            require(choicesModule.isValidChoice(choiceIds[i]), "Choice does not exist");
            totalAmount += amounts[i];

            _vote(choiceIds[i], amounts[i], _data[i]);

            unchecked {
                i++;
            }
        }

        require(totalAmount == _totalAmount, "Invalid total amount");
    }

    function batchRetractVote(
        bytes32[] memory choiceIds,
        uint256[] memory amounts,
        bytes[] memory _data,
        uint256 _totalAmount
    ) public virtual nonReentrant onlyVotingPeriod onlyContestRetractable onlyHasAllocated(msg.sender, _totalAmount) {
        require(
            choiceIds.length == amounts.length && choiceIds.length == _data.length,
            "Array mismatch: Invalid input length"
        );

        uint256 totalAmount = 0;

        for (uint256 i = 0; i < choiceIds.length;) {
            require(choicesModule.isValidChoice(choiceIds[i]), "Choice does not exist");
            totalAmount += amounts[i];

            _retractVote(choiceIds[i], amounts[i], _data[i]);

            unchecked {
                i++;
            }
        }

        require(totalAmount == _totalAmount, "Invalid total amount");
    }

    function _vote(bytes32 choiceId, uint256 amount, bytes memory _data) internal {
        pointsModule.allocatePoints(msg.sender, amount);
        votesModule.vote(msg.sender, choiceId, amount, _data);
    }

    function _retractVote(bytes32 choiceId, uint256 amount, bytes memory _data) internal {
        pointsModule.releasePoints(msg.sender, amount);
        votesModule.retractVote(msg.sender, choiceId, amount, _data);
    }

    function finalizeChoices() external {
        require(contestStatus == ContestStatus.Populating, "Contest is not in populating state");
        require(msg.sender == address(choicesModule), "Only choices module");
        contestStatus = ContestStatus.Voting;
    }

    function finalizeVoting() external onlyVotingPeriod {
        require(msg.sender == address(votesModule), "Only votes module");
        contestStatus = ContestStatus.Finalized;
    }

    function finalizeContinuous() external {
        require(contestStatus == ContestStatus.Continuous, "Contest is not continuous");
        require(
            msg.sender == address(votesModule) || msg.sender == address(choicesModule), "Only votes or choices module"
        );
        contestStatus = ContestStatus.Finalized;
    }

    function execute() public virtual {
        require(contestStatus == ContestStatus.Finalized, "Contest is not finalized");
        require(msg.sender == address(executionModule), "Only execution module");
        contestStatus = ContestStatus.Executed;
    }

    function getStatus() public view returns (ContestStatus) {
        return contestStatus;
    }

    function isStatus(ContestStatus _status) public view returns (bool) {
        return contestStatus == _status;
    }
}
