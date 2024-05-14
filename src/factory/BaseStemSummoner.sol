// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin-contracts/contracts-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin-contracts/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin-contracts/contracts/proxy/Clones.sol";

contract StemSummoner is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    address public _contest;

    event ContestSummoned(address contest, bytes32 saltNonce, bytes32 referrer);
    event ModuleDeployed(address module, bytes32 saltNonce, bytes32 referrer);

    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    function deployModule(bytes calldata initializationParams, address predictedContestAddress)
        internal
        returns (address module)
    {
        (address template, bytes memory initDeployParams) = abi.decode(initializationParams, (address, bytes));
        require(template != address(0), "Summoner: template address is zero");
        // TODO: this might create collisions if the same template is used for different contests
        module = Clones.cloneDeterministic(template, keccak256(initDeployParams));
        require(module != address(0), "Summoner: module address is zero");
        emit ModuleDeployed(module, keccak256(initDeployParams), keccak256(abi.encodePacked(predictedContestAddress)));
    }

    function summonContest(
        address choiceAddress,
        address pointsAddress,
        address votesAddress,
        address executionAddress,
        bool isContinuous,
        bool isRetractable,
        bytes32 saltNonce,
        bytes32 referrer
    ) internal virtual returns (IContest contest) {
        IContest contest = Clones.cloneDeterministic(_contest, saltNonce);
        contest.initialize(choiceAddress, pointsAddress, votesAddress, executionAddress, isContinuous, isRetractable);

        emit ContestSummoned(address(contest), saltNonce, referrer);
    }

    function predictModuleAddress(address implementation, uint256 salt) external view returns (address predicted) {
        return Clones.predictDeterministicAddress(implementation, bytes32(salt), address(this));
    }

    function predictContestAddress(address implementation, uint256 salt) external view returns (address predicted) {
        return Clones.predictDeterministicAddress(_contest, bytes32(salt), address(this));
    }
}
