// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IHats} from "hats-protocol/Interfaces/IHats.sol";

import {Metadata} from "../../core/Metadata.sol";

contract HatPoster {
    event PostEvent(string tag, Metadata content);

    event PostRecord(bytes32 nonce, Metadata content);

    uint256 public hatId;

    IHats public hats;

    mapping(bytes32 => Metadata) public records;

    constructor() {}

    modifier onlyWearer() {
        require(hats.isWearerOfHat(msg.sender, hatId), "HatPoster: only wearer");
        _;
    }

    function initialize(uint256 _hatId, address _hatsAddress) public {
        hatId = _hatId;
        hats = IHats(_hatsAddress);
    }

    function postUpdate(string memory _tag, Metadata memory _content) external onlyWearer {
        emit PostEvent(_tag, _content);
    }

    function postRecord(bytes32 _nonce, Metadata memory _content) external onlyWearer {
        require(records[_nonce].protocol == 0, "HatPoster: record exists");

        records[_nonce] = _content;
        emit PostRecord(_nonce, _content);
    }
}
