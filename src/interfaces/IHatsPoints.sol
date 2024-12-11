// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IHatsPoints {
    function getPointsByHat(uint256 _hatId) external view returns (uint256);
}
