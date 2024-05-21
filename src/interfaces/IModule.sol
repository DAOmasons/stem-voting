// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IModule {
    function initialize(address _contest, bytes calldata initData) external;
}
