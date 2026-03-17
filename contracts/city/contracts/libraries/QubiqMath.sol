// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library QubiqMath {
    function totalQubiqs(uint32 width, uint32 height) internal pure returns (uint256) {
        return uint256(width) * uint256(height);
    }

    function completionBps(
        uint256 completed,
        uint32 width,
        uint32 height
    ) internal pure returns (uint256) {
        uint256 total = totalQubiqs(width, height);
        if (total == 0) return 0;
        return (completed * 10_000) / total;
    }

    function isFullyCompleted(
        uint256 completed,
        uint32 width,
        uint32 height
    ) internal pure returns (bool) {
        return completed >= totalQubiqs(width, height);
    }

    function withinBounds(
        uint32 x,
        uint32 y,
        uint32 width,
        uint32 height
    ) internal pure returns (bool) {
        return x < width && y < height;
    }
}