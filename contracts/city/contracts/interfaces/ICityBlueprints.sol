// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ICityBlueprints {
    function mintBlueprint(
        address to,
        uint256 blueprintId,
        uint256 amount
    ) external;
}