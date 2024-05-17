// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ReentrancyGuard} from "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

import "./interfaces/IFinalizationStrategy.sol";
import "./interfaces/IVotes.sol";
import "./interfaces/IPoints.sol";
import "./interfaces/IChoices.sol";
import "./interfaces/IContest.sol";

import {ContestStatus} from "./core/ContestStatus.sol";

/// @title Stem Contest
/// @author @jord<https://github.com/jordanlesich>, @dekanbro<https://github.com/dekanbro>
/// @notice Simple, minimalistic TCR Voting contract that composes voting, allocation, choices, and execution modules and orders their interactions
contract Contest is ReentrancyGuard {
    /// ===============================
    /// ========== Events =============
    /// ===============================

    /// @notice Emitted when the Contest is initialized
    event ContestInitialized(
        address votesModule,
        address pointsModule,
        address choicesModule,
        address executionModule,
        bool isContinuous,
        bool isRetractable,
        ContestStatus status
    );

    /// @notice Emitted when the Contest Status is updated to a new status
    event ContestStatusChanged(ContestStatus status);

    /// ================================
    /// ========== Storage =============
    /// ================================

    /// @notice Contest version
    string public constant CONTEST_VERSION = "0.1.0";

    /// @notice Reference to the Voting contract module.
    IVotes public votesModule;

    /// @notice Reference to the Points contract module.
    IPoints public pointsModule;

    /// @notice Reference to the Choices contract module.
    IChoices public choicesModule;

    /// @notice Address of the Execution contract module.
    address public executionModule;

    /// @notice Current status of the Contest.
    ContestStatus public contestStatus;

    /// @notice Flag to determine if the contest is continuous.
    bool public isContinuous;

    /// @notice Flag to determine if voting is retractable.
    bool public isRetractable;

    /// ===============================
    /// ======== Modifiers ============
    /// ===============================

    modifier onlyVotingPeriod() {
        require(
            contestStatus == ContestStatus.Voting || (contestStatus == ContestStatus.Continuous && isContinuous),
            "Contest is not in voting state"
        );
        _;
    }

    /// @notice Modifier to check if the choice is valid (usually used to check if the choice exists)
    /// @dev Throws if the choice does not exist or is invalid
    modifier onlyValidChoice(bytes32 choiceId) {
        require(choicesModule.isValidChoice(choiceId), "Choice does not exist");
        _;
    }

    /// @notice Modifier to check if the voter has enough points to allocate
    /// @dev Throws if voter does not have enough points to allocate
    modifier onlyCanAllocate(address _voter, uint256 _amount) {
        require(pointsModule.hasVotingPoints(_voter, _amount), "Insufficient points available");
        _;
    }

    /// @notice Modifier to check if the voter has enough points allocated
    /// @dev Throws if voter does not have enough points allocated
    modifier onlyHasAllocated(address _voter, uint256 _amount) {
        require(pointsModule.hasAllocatedPoints(_voter, _amount), "Insufficient points allocated");
        _;
    }

    /// @notice Modifier to check if the contest is retractable
    /// @dev Throws if the contest is not retractable
    modifier onlyContestRetractable() {
        require(isRetractable, "Votes are not retractable");
        _;
    }

    /// ===============================
    /// ========= Initialize ==========
    /// ===============================

    constructor() {}

    /// @notice Initialize the strategy
    /// @param  _initData The data to initialize the contest (votes, points, choices, execution, isContinuous, isRetractable)
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

        emit ContestInitialized(
            _votesContract,
            _pointsContract,
            _choicesContract,
            _executionContract,
            _isContinuous,
            _isRetractable,
            contestStatus
        );
    }

    /// ===============================
    /// ====== Module Interactions ====
    /// ===============================

    /// @notice Claim points from the Points module
    function claimPoints() public virtual onlyVotingPeriod {
        pointsModule.claimPoints();
    }

    /// @notice Vote on a choice
    /// @param _choiceId The ID of the choice to vote on
    /// @param _amount The amount of points to vote with
    /// @param _data Additional data to include with the vote
    function vote(bytes32 _choiceId, uint256 _amount, bytes memory _data)
        public
        virtual
        nonReentrant
        onlyVotingPeriod
        onlyValidChoice(_choiceId)
        onlyCanAllocate(msg.sender, _amount)
    {
        _vote(_choiceId, _amount, _data);
    }

    /// @notice Retract a vote on a choice
    /// @param _choiceId The ID of the choice to retract the vote from
    /// @param _amount The amount of points to retract
    /// @param _data Additional data to include with the retraction
    function retractVote(bytes32 _choiceId, uint256 _amount, bytes memory _data)
        public
        virtual
        nonReentrant
        onlyVotingPeriod
        onlyContestRetractable
        onlyValidChoice(_choiceId)
        onlyHasAllocated(msg.sender, _amount)
    {
        _retractVote(_choiceId, _amount, _data);
    }

    /// @notice Change a vote from one choice to another
    /// @param _oldChoiceId The ID of the choice to retract the vote from
    /// @param _newChoiceId The ID of the choice to vote on
    /// @param _amount The amount of points to vote with
    /// @param _data Additional data to include with the vote
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
        require(pointsModule.hasVotingPoints(msg.sender, _amount), "Insufficient points available");
        _vote(_newChoiceId, _amount, _data);
    }

    /// @notice Batch vote on multiple choices
    /// @param _choiceIds The IDs of the choices to vote on
    /// @param _amounts The amounts of points to vote with
    /// @param _data Additional data to include with the votes
    /// @param _totalAmount The total amount of points to vote with
    function batchVote(
        bytes32[] memory _choiceIds,
        uint256[] memory _amounts,
        bytes[] memory _data,
        uint256 _totalAmount
    ) public virtual nonReentrant onlyVotingPeriod onlyCanAllocate(msg.sender, _totalAmount) {
        require(
            _choiceIds.length == _amounts.length && _choiceIds.length == _data.length,
            "Array mismatch: Invalid input length"
        );

        uint256 totalAmount = 0;

        for (uint256 i = 0; i < _choiceIds.length;) {
            require(choicesModule.isValidChoice(_choiceIds[i]), "Choice does not exist");
            totalAmount += _amounts[i];

            _vote(_choiceIds[i], _amounts[i], _data[i]);

            unchecked {
                i++;
            }
        }

        require(totalAmount == _totalAmount, "Invalid total amount");
    }

    /// @notice Batch retract votes on multiple choices
    /// @param _choiceIds The IDs of the choices to retract votes from
    /// @param _amounts The amounts of points to retract
    /// @param _data Additional data to include with the retractions
    /// @param _totalAmount The total amount of points to retract
    function batchRetractVote(
        bytes32[] memory _choiceIds,
        uint256[] memory _amounts,
        bytes[] memory _data,
        uint256 _totalAmount
    ) public virtual nonReentrant onlyVotingPeriod onlyContestRetractable onlyHasAllocated(msg.sender, _totalAmount) {
        require(
            _choiceIds.length == _amounts.length && _choiceIds.length == _data.length,
            "Array mismatch: Invalid input length"
        );

        uint256 totalAmount = 0;

        for (uint256 i = 0; i < _choiceIds.length;) {
            require(choicesModule.isValidChoice(_choiceIds[i]), "Choice does not exist");
            totalAmount += _amounts[i];

            _retractVote(_choiceIds[i], _amounts[i], _data[i]);

            unchecked {
                i++;
            }
        }

        require(totalAmount == _totalAmount, "Invalid total amount");
    }

    /// ===============================
    /// ========== Setters ============
    /// ===============================

    /// @notice Finalize the choices
    /// @dev Only callable by the Choices module
    function finalizeChoices() external {
        require(contestStatus == ContestStatus.Populating, "Contest is not in populating state");
        require(msg.sender == address(choicesModule), "Only choices module");
        contestStatus = ContestStatus.Voting;

        emit ContestStatusChanged(ContestStatus.Voting);
    }

    /// @notice Finalize the voting period
    /// @dev Only callable by the Votes module
    function finalizeVoting() external onlyVotingPeriod {
        require(msg.sender == address(votesModule), "Only votes module");
        contestStatus = ContestStatus.Finalized;

        emit ContestStatusChanged(ContestStatus.Finalized);
    }

    /// @notice Finalize the continuous voting period
    /// @dev Only callable by the Votes or Choices module
    function finalizeContinuous() external {
        require(contestStatus == ContestStatus.Continuous, "Contest is not continuous");
        require(
            msg.sender == address(votesModule) || msg.sender == address(choicesModule), "Only votes or choices module"
        );
        contestStatus = ContestStatus.Finalized;

        emit ContestStatusChanged(ContestStatus.Finalized);
    }

    /// @notice Execute the contest
    /// @dev Only callable by the Execution module
    function execute() public virtual {
        require(contestStatus == ContestStatus.Finalized, "Contest is not finalized");
        require(msg.sender == address(executionModule), "Only execution module");
        contestStatus = ContestStatus.Executed;

        emit ContestStatusChanged(ContestStatus.Executed);
    }

    /// ===============================
    /// ========== Internal ===========
    /// ===============================

    /// @notice Internal function to vote on a choice
    /// @param _choiceId The ID of the choice to vote on
    /// @param _amount The amount of points to vote with
    /// @param _data Additional data to include with the vote
    function _vote(bytes32 _choiceId, uint256 _amount, bytes memory _data) internal {
        pointsModule.allocatePoints(msg.sender, _amount);
        votesModule.vote(msg.sender, _choiceId, _amount, _data);
    }

    /// @notice Internal function to retract a vote on a choice
    /// @param _choiceId The ID of the choice to retract the vote from
    /// @param _amount The amount of points to retract
    /// @param _data Additional data to include with the retraction
    function _retractVote(bytes32 _choiceId, uint256 _amount, bytes memory _data) internal {
        pointsModule.releasePoints(msg.sender, _amount);
        votesModule.retractVote(msg.sender, _choiceId, _amount, _data);
    }

    /// ===============================
    /// ========== Getters ============
    /// ===============================

    /// @notice Get the current status of the Contest
    /// @return The current status of the Contest
    function getStatus() public view returns (ContestStatus) {
        return contestStatus;
    }

    /// @notice Check if the Contest is in a specific status
    /// @param _status The status to check
    /// @return True if the Contest is in the specified status
    function isStatus(ContestStatus _status) public view returns (bool) {
        return contestStatus == _status;
    }
}
