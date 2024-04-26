// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../interfaces/IChoices.sol";

// Allow listed choice contract
contract AllowList is IChoices {
    struct ChoiceData {
        string uri;
        bytes data;
    }

    mapping(bytes32 => ChoiceData) private choices;
    mapping(address => bool) public allowedAccounts;

    address public owner;

    constructor(address[] memory _allowedAccounts) {
        owner = msg.sender;
        for (uint i = 0; i < _allowedAccounts.length; i++) {
            allowedAccounts[_allowedAccounts[i]] = true;
        }
    }

    modifier onlyAllowed() {
        require(allowedAccounts[msg.sender], "Caller is not allowed");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    function registerChoice(
        bytes32 choiceId,
        string calldata uri,
        bytes calldata data
    ) external override onlyAllowed {
        choices[choiceId] = ChoiceData(uri, data);
    }

    function getChoice(
        bytes32 choiceId
    ) external view override returns (string memory, bytes memory) {
        return (choices[choiceId].uri, choices[choiceId].data);
    }

    function addAllowedAccount(address account) external onlyOwner {
        allowedAccounts[account] = true;
    }

    function removeAllowedAccount(address account) external onlyOwner {
        allowedAccounts[account] = false;
    }
}
