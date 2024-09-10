// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ModuleType} from "../core/ModuleType.sol";

interface IModule {
    function MODULE_NAME() external view returns (string memory);
    function MODULE_TYPE() external view returns (ModuleType);

    function initialize(address _contest, bytes calldata initData) external;
}
