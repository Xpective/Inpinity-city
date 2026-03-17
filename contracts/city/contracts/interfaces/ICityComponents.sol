// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ICityComponents {
    function mintComponent(
        address to,
        uint256 componentId,
        uint256 amount
    ) external;
}