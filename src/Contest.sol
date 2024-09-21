// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

import "./interfaces/IFinalizationStrategy.sol";
import "./interfaces/IVotes.sol";
import "./interfaces/IPoints.sol";
import "./interfaces/IChoices.sol";
import "./interfaces/IContest.sol";

import {ContestStatus} from "./core/ContestStatus.sol";
import {Metadata} from "./core/Metadata.sol";

/// @title Stem Contest
/// @author @jord<https://github.com/jordanlesich>, @dekanbro<https://github.com/dekanbro>
/// @notice Simple, minimalistic TCR Voting contract that composes voting, allocation, choices, and execution modules and orders their interactions
contract Contest is ReentrancyGuard, Initializable {
    /// ===============================
    /// ========== Events =============
    /// ===============================

    /// @notice Emitted when the Contest is initialized
    event ContestInitialized(
        Metadata metadata,
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

    event BatchVote(
        address indexed voter, bytes32[] choices, uint256[] amounts, uint256 totalAmount, Metadata metadata
    );

    event BatchRetractVote(
        address indexed voter, bytes32[] choices, uint256[] amounts, uint256 totalAmount, Metadata metadata
    );

    event BatchChangeVote(
        address indexed voter, bytes32[] choices, uint256[] amounts, uint256 totalAmount, Metadata metadata
    );

    /// @notice Contest version
    string public constant CONTEST_VERSION = "0.2.0";

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
    modifier onlyCanAllocate(address _voter, uint256 _amount, bytes memory _data) {
        require(pointsModule.hasVotingPoints(_voter, _amount, _data), "Insufficient points available");
        _;
    }

    /// @notice Modifier to check if the voter has enough points allocated
    /// @dev Throws if voter does not have enough points allocated
    modifier onlyHasAllocated(address _voter, uint256 _amount, bytes memory _data) {
        require(pointsModule.hasAllocatedPoints(_voter, _amount, _data), "Insufficient points allocated");
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
    function initialize(bytes memory _initData) public initializer {
        (
            Metadata memory _metadata,
            address _votesContract,
            address _pointsContract,
            address _choicesContract,
            address _executionContract,
            ContestStatus _contestStatus,
            bool _isRetractable
        ) = abi.decode(_initData, (Metadata, address, address, address, address, ContestStatus, bool));

        votesModule = IVotes(_votesContract);
        pointsModule = IPoints(_pointsContract);
        choicesModule = IChoices(_choicesContract);
        executionModule = _executionContract;
        isRetractable = _isRetractable;

        contestStatus = _contestStatus;

        if (contestStatus == ContestStatus.Continuous) {
            isContinuous = true;
        }

        emit ContestInitialized(
            _metadata,
            _votesContract,
            _pointsContract,
            _choicesContract,
            _executionContract,
            isContinuous,
            _isRetractable,
            contestStatus
        );
    }

    /// ===============================
    /// ====== Module Interactions ====
    /// ===============================

    /// @notice Claim points from the Points module
    function claimPoints(bytes memory _data) public virtual onlyVotingPeriod {
        pointsModule.claimPoints(msg.sender, _data);
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
        onlyCanAllocate(msg.sender, _amount, _data)
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
        onlyHasAllocated(msg.sender, _amount, _data)
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
        onlyHasAllocated(msg.sender, _amount, _data)
    {
        _retractVote(_oldChoiceId, _amount, _data);
        require(pointsModule.hasVotingPoints(msg.sender, _amount, _data), "Insufficient points available");
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
        uint256 _totalAmount,
        Metadata memory _metadata
    ) public virtual nonReentrant onlyVotingPeriod {
        require(
            _choiceIds.length == _amounts.length && _choiceIds.length == _data.length,
            "Array mismatch: Invalid input length"
        );

        uint256 totalAmount = 0;

        for (uint256 i = 0; i < _choiceIds.length;) {
            require(pointsModule.hasVotingPoints(msg.sender, _amounts[i], _data[i]), "Insufficient points available");
            require(choicesModule.isValidChoice(_choiceIds[i]), "Choice does not exist");
            totalAmount += _amounts[i];

            _vote(_choiceIds[i], _amounts[i], _data[i]);

            unchecked {
                i++;
            }
        }

        require(totalAmount == _totalAmount, "Invalid total amount");

        if (_metadata.protocol != 0) {
            // This event is an optional event to emit on batch transtions
            // it helps by emitting user Metadata and total change in connection
            // to a single user interaction instead of events triggered for each vote
            // which can be difficult to index.
            emit BatchVote(msg.sender, _choiceIds, _amounts, _totalAmount, _metadata);
        }
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
        uint256 _totalAmount,
        Metadata memory _metadata
    ) public virtual nonReentrant onlyVotingPeriod onlyContestRetractable {
        require(
            _choiceIds.length == _amounts.length && _choiceIds.length == _data.length,
            "Array mismatch: Invalid input length"
        );

        uint256 totalAmount = 0;

        for (uint256 i = 0; i < _choiceIds.length;) {
            require(pointsModule.hasAllocatedPoints(msg.sender, _amounts[i], _data[i]), "Insufficient points allocated");
            require(choicesModule.isValidChoice(_choiceIds[i]), "Choice does not exist");
            totalAmount += _amounts[i];

            _retractVote(_choiceIds[i], _amounts[i], _data[i]);

            unchecked {
                i++;
            }
        }

        require(totalAmount == _totalAmount, "Invalid total amount");

        if (_metadata.protocol != 0) {
            // This event is an optional event to emit on batch transtions
            // it helps by emitting user Metadata and total change in connection
            // to a single user interaction instead of events triggered for each vote
            // which can be difficult to index.
            emit BatchRetractVote(msg.sender, _choiceIds, _amounts, _totalAmount, _metadata);
        }
    }

    function batchChangeVote(
        bytes32[] memory _retractChoiceIds,
        uint256[] memory _retractAmounts,
        bytes[] memory _retractData,
        uint256 _totalRetract,
        bytes32[] memory _voteChoiceIds,
        uint256[] memory _voteAmounts,
        bytes[] memory _voteData,
        uint256 _totalVote,
        Metadata[2] memory _metadata
    ) public virtual nonReentrant onlyVotingPeriod onlyContestRetractable {
        // totalRetract and totalVote are each tested against of thee sum of their respective amounts
        // in batchRetractVote and batchVote respectively.
        require(_totalRetract == _totalVote, "Amount retracted and amount voted must be equal");

        batchRetractVote(_retractChoiceIds, _retractAmounts, _retractData, _totalRetract, _metadata[0]);
        batchVote(_voteChoiceIds, _voteAmounts, _voteData, _totalVote, _metadata[1]);
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
        pointsModule.allocatePoints(msg.sender, _amount, _data);
        votesModule.vote(msg.sender, _choiceId, _amount, _data);
    }

    /// @notice Internal function to retract a vote on a choice
    /// @param _choiceId The ID of the choice to retract the vote from
    /// @param _amount The amount of points to retract
    /// @param _data Additional data to include with the retraction
    function _retractVote(bytes32 _choiceId, uint256 _amount, bytes memory _data) internal {
        pointsModule.releasePoints(msg.sender, _amount, _data);
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
