// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../../interfaces/IChoices.sol";
import "../../core/ModuleType.sol";

// Allow listed choice contract
contract AllowList is IChoices {
    struct ChoiceData {
        string uri;
        bytes data;
    }

    /// @notice The name and version of the module
    string public constant MODULE_NAME = "AllowList_v0.0.0";

    /// @notice The type of module
    ModuleType public constant MODULE_TYPE = ModuleType.Choices;

    mapping(bytes32 => ChoiceData) private choices;
    mapping(address => bool) public allowedAccounts;

    address public owner;

    modifier onlyAllowed() {
        require(allowedAccounts[msg.sender], "Caller is not allowed");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    constructor() {}

    function initialize(address _contest, bytes calldata _initData) external override {
        owner = _contest;

        (address[] memory _allowedAccounts) = abi.decode(_initData, (address[]));

        for (uint256 i = 0; i < _allowedAccounts.length; i++) {
            allowedAccounts[_allowedAccounts[i]] = true;
        }
    }

    function registerChoice(bytes32 choiceId, bytes calldata _data) external override onlyAllowed {
        (string memory _uri, bytes memory _choiceData) = abi.decode(_data, (string, bytes));

        choices[choiceId] = ChoiceData(_uri, _choiceData);
    }

    function removeChoice(bytes32 choiceId, bytes calldata _data) external override onlyAllowed {
        (string memory _uri, bytes memory _choiceData) = abi.decode(_data, (string, bytes));

        choices[choiceId] = ChoiceData(_uri, _choiceData);
    }

    function getChoice(bytes32 choiceId) external view returns (string memory, bytes memory) {
        return (choices[choiceId].uri, choices[choiceId].data);
    }

    function addAllowedAccount(address account) external onlyOwner {
        allowedAccounts[account] = true;
    }

    function removeAllowedAccount(address account) external onlyOwner {
        allowedAccounts[account] = false;
    }

    function isValidChoice(bytes32 choiceId) external view override returns (bool) {
        return choices[choiceId].data.length > 0;
    }
}
