// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Metadata} from "./Metadata.sol";

/// @notice Struct to hold the metadata and bytes data of a choice
struct BasicChoice {
    Metadata metadata;
    bytes data;
    bool exists;
    address registrar;
}
