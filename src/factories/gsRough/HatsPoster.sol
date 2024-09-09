// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IHats} from "hats-protocol/Interfaces/IHats.sol";

import {Metadata} from "../../core/Metadata.sol";

contract HatsPoster {
    struct Record {
        uint256 protocol;
        string pointer;
        bool exists;
    }

    event PostEvent(string tag, uint256 hatId, Metadata content);

    event PostRecord(string tag, bytes32 nonce, uint256 hatId, Metadata content);

    event Initialized(address hatsAddress, uint256[] hatIds);

    IHats public hats;

    mapping(bytes32 => Record) public records;
    mapping(uint256 => bool) public hatIds;

    constructor() {}

    modifier onlyWearer(uint256 _hatId) {
        require(hats.isWearerOfHat(msg.sender, _hatId), "HatPoster: only wearer");
        _;
    }

    modifier onlyValidId(uint256 _hatId) {
        require(hatIds[_hatId], "HatPoster: invalid hatId");
        _;
    }

    function initialize(uint256[] calldata _hatIds, address _hatsAddress) public {
        hats = IHats(_hatsAddress);

        for (uint256 i = 0; i < _hatIds.length; i++) {
            hatIds[_hatIds[i]] = true;
        }

        emit Initialized(_hatsAddress, _hatIds);
    }

    // Posts an event with a tag and content. Potentially ephemerally stored with EIP-4444
    function postUpdate(string memory _tag, uint256 _hatId, Metadata memory _content)
        external
        onlyValidId(_hatId)
        onlyWearer(_hatId)
    {
        emit PostEvent(_tag, _hatId, _content);
    }

    // Posts a record with a nonce and content. Statefully stored onchain.
    function postRecord(string memory tag, bytes32 _nonce, uint256 _hatId, Metadata memory _content)
        external
        onlyValidId(_hatId)
        onlyWearer(_hatId)
    {
        require(records[_nonce].exists == false, "HatPoster: record exists");

        records[_nonce] = Record(_content.protocol, _content.pointer, true);
        emit PostRecord(tag, _nonce, _hatId, _content);
    }
}
