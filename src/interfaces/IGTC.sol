// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IGTC {
    function balanceOf(address account) external view returns (uint256);
    function name() external view returns (string memory);
    function getPriorVotes(address account, uint256 blockNumber) external view returns (uint96);
    function transfer(address dst, uint256 rawAmount) external returns (bool);
    function delegate(address delegatee) external;
}
