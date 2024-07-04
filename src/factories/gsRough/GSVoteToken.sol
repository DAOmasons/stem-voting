// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Pausable.sol";

import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract GSVotingToken is ERC20, Ownable {
    constructor(string memory name, string memory symbol, uint256 initialSupply, address _holder) ERC20(name, symbol) {
        _mint(_holder, initialSupply);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burn(address account, uint256 amount) public onlyOwner {
        _burn(account, amount);
    }

    function _transfer(address, address, uint256) internal pure override {
        require(false, "SBT: Transfers are not allowed");
    }

    function transfer(address, uint256) public pure override returns (bool) {
        require(false, "SBT: Transfers are not allowed");
    }

    function transferFrom(address, address, uint256) public pure override returns (bool) {
        require(false, "SBT: Transfers are not allowed");
    }
}
