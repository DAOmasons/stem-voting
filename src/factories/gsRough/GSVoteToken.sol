// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Pausable.sol";

import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract GSVotingToken is ERC20, Ownable {
    constructor(string memory name, string memory symbol, uint256 initialSupply, address _holder)
        ERC20(name, symbol)
        Ownable(msg.sender)
    {
        _mint(_holder, initialSupply);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burn(address account, uint256 amount) public onlyOwner {
        _burn(account, amount);
    }

    function _update(address from, address to, uint256 amount) internal override {
        require(from == address(0) || to == address(0), "SBT: Transfers are not allowed");
        super._update(from, to, amount);
    }
}
