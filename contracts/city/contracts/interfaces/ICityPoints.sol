// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ICityPoints {
    function addPoints(address user, uint256 amount, uint8 category) external;
    function awardPoints(
        address user,
        uint256 amount,
        uint8 category,
        bool spendable,
        bytes32 reason
    ) external;
}
