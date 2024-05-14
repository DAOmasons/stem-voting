// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/access/Ownable.sol";

// TODO: this should probably be upgradable too
contract HOSStem is Ownable {
    string public constant name = "STEM:0.0.1";
    address public stemSummoner;

    mapping(address => bool) public allowlistTemplates;

    constructor(address _stemSummoner, address[] memory _allowlistTemplates) public {
        stemSummoner = IBaseStemSummoner(_stemSummoner);
        for (uint256 i = 0; i < _allowlistTemplates.length; i++) {
            allowlistTemplates[_allowlistTemplates[i]] = true;
        }
    }

    function isTemplateInAllowlist(address template) internal view returns (bool) {
        return allowlistTemplates[template];
    }

    function setAllowlistTemplate(address _template, bool allowed) public onlyOwner {
        allowlistTemplates[_template] = allowed;
    }

    function setStemSummoner(address _stemSummoner) public onlyOwner {
        stemSummoner = _stemSummoner;
    }

    function summonStemContest(
        bytes calldata initializationChoiceParams,
        bytes calldata initializationPointsParams,
        bytes calldata initializationVotesParams,
        bytes calldata initializationExecutionParams,
        uint256 saltNonce
    ) external returns (IContest contest) {
        address predictedContestAddress = stemSummoner.predictContestAddress(saltNonce);

        address choiceAddress = deployModule(predictedContestAddress, initializationChoiceParams);
        address pointsAddress = deployModule(predictedContestAddress, initializationPointsParams);
        address votesAddress = deployModule(predictedContestAddress, initializationVotesParams);
        address executionAddress = deployModule(predictedContestAddress, initializationExecutionParams);

        contest = stemSummoner.summonContest(
            choiceAddress,
            pointsAddress,
            votesAddress,
            executionAddress,
            isContinuous,
            isRetractable,
            saltNonce,
            bytes32(bytes(name))
        );
    }

    function deployModule(bytes calldata initializationParams, address predictedContestAddress)
        internal
        returns (address module)
    {
        (address template, bytes memory initDeployParams) = abi.decode(initializationParams, (address, bytes));
        require(template != address(0), "Summoner: template address is zero");
        require(isTemplateInAllowlist(template), "Summoner: template not in allowlist");
        stemSummoner.deployModule(initializationParams, predictedContestAddress);
    }
}
