// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library CityMath {
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    function clamp(uint256 value, uint256 minValue, uint256 maxValue) internal pure returns (uint256) {
        if (value < minValue) return minValue;
        if (value > maxValue) return maxValue;
        return value;
    }

    function bpsOf(uint256 amount, uint256 bps) internal pure returns (uint256) {
        return (amount * bps) / 10_000;
    }
}