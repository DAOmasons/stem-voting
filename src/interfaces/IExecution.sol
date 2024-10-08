// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IModule} from "../interfaces/IModule.sol";

interface IExecution is IModule {
    function execute(bytes memory _data) external;
}
