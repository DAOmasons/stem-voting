// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {IVotes} from "../../interfaces/IVotes.sol";
import {Contest} from "../../Contest.sol";
import {ModuleType} from "../../core/ModuleType.sol";
import {VoteTimer, TimerType} from "./utils/VoteTimer.sol";
import {Metadata} from "../../core/Metadata.sol";
import {IHatsPoints} from "../../interfaces/IHatsPoints.sol";
import {IHats} from "lib/hats-protocol/src/Interfaces/IHats.sol";
import {ContestStatus} from "../../core/ContestStatus.sol";

contract RubricVotes is IVotes, Initializable {
    /// @notice Emitted when the contract is initialized
    event Initialized(address _contest, uint256 _adminHatId, uint256 _judgeHatId);

    /// @notice Emitted when a vote is cast
    event VoteCast(address voter, bytes32 choiceId, uint256 amount);

    /// @notice Emitted when a vote is retracted
    event VoteRetracted(address voter, bytes32 choiceId, uint256 amount);

    /// @notice Reference to the contest contract
    Contest public contest;

    /// @notice The name and version of the module
    string public constant MODULE_NAME = "RubricVotes_v0.1.0";

    /// @notice The type of module
    ModuleType public constant MODULE_TYPE = ModuleType.Votes;

    /// @notice Mapping of choiceId to voter to vote amount
    /// @dev choiceId => voter => amount
    mapping(bytes32 => mapping(address => uint256)) public votes;

    /// @notice Mapping of choiceId to total votes for that choice
    /// @dev choiceId => totalVotes
    mapping(bytes32 => uint256) public totalVotesForChoice;

    /// @notice the maximum amount of votes that can be cast for a choice
    uint256 public maxVotesForChoice;

    /// @notice points module address
    address pointsModule;

    /// @notice admin hat id
    uint256 public adminHatId;

    /// @notice judge hat id
    uint256 public judgeHatId;

    /// @notice Reference to the Hats Protocol contract
    IHats hats;

    /// ===============================
    /// ========== Modifiers ==========
    /// ===============================

    /// @notice Only the contest contract can call this function
    /// @dev The caller must be the contest contract
    modifier onlyContest() {
        require(msg.sender == address(contest), "Only contest");
        _;
    }

    modifier onlyWearer(uint256 hatId, address _caller) {
        require(hats.isWearerOfHat(_caller, hatId), "Only wearer");
        _;
    }

    /// ===============================
    /// ========== Init ===============
    /// ===============================

    constructor() {}

    /// @notice Initializes the timed voting module
    /// @param _contest The address of the contest contract
    /// @param _initParams The initialization data
    /// @dev Bytes data includes the duration of the voting period
    function initialize(address _contest, bytes memory _initParams) public initializer {
        (uint256 _adminHatId, uint256 _judgeHatId, uint256 _maxVotesForChoice, address _hats) =
            abi.decode(_initParams, (uint256, uint256, uint256, address));

        require(
            _adminHatId != 0 && _judgeHatId != 0 && _maxVotesForChoice != 0 && _hats != address(0)
                && _contest != address(0),
            "Invalid init params"
        );

        hats = IHats(_hats);
        contest = Contest(_contest);
        adminHatId = _adminHatId;
        judgeHatId = _judgeHatId;
        maxVotesForChoice = _maxVotesForChoice;

        emit Initialized(_contest, _adminHatId, _judgeHatId);
    }

    /// @notice Casts a vote for a choice based on the total voting power of all hats referenced in the Hats Points contract
    /// @param _voter The address of the voter
    /// @param _choiceId The unique identifier for the choice
    /// @param _amount The amount of votes to cast
    function vote(address _voter, bytes32 _choiceId, uint256 _amount, bytes memory)
        external
        onlyContest
        onlyWearer(judgeHatId, _voter)
    {
        require(_amount != 0, "Amount must be greater than 0");
        require(_amount <= maxVotesForChoice, "Amount must be less than or equal to maxVotesForChoice");

        uint256 amountAlreadyVoted = votes[_choiceId][_voter];
        require(amountAlreadyVoted + _amount <= maxVotesForChoice, "Amount exceeds maxVotesForChoice");

        votes[_choiceId][_voter] += _amount;
        totalVotesForChoice[_choiceId] += _amount;

        emit VoteCast(_voter, _choiceId, _amount);
    }

    /// @notice Retracts a vote for a choice
    /// @param _voter The address of the voter
    /// @param _choiceId The unique identifier for the choice
    /// @param _amount The amount of votes to retract
    function retractVote(address _voter, bytes32 _choiceId, uint256 _amount, bytes memory)
        external
        onlyContest
        onlyWearer(judgeHatId, _voter)
    {
        require(_amount != 0, "Amount must be greater than 0");

        uint256 amountAlreadyVoted = votes[_choiceId][_voter];
        require(amountAlreadyVoted >= _amount, "Amount exceeds amount already voted");

        votes[_choiceId][_voter] -= _amount;
        totalVotesForChoice[_choiceId] -= _amount;

        emit VoteRetracted(_voter, _choiceId, _amount);
    }

    /// @notice Finalizes the voting period
    function finalizeVotes() external onlyWearer(adminHatId, msg.sender) {
        require(
            contest.isStatus(ContestStatus.Voting) || contest.isStatus(ContestStatus.Continuous),
            "Contest is not in voting state"
        );
        contest.finalizeVoting();
    }

    /// @notice Gets the total votes for a choice
    /// @param _choiceId The unique identifier for the choice
    /// @return The total votes for the choice
    function getTotalVotesForChoice(bytes32 _choiceId) external view returns (uint256) {
        return totalVotesForChoice[_choiceId];
    }
}
