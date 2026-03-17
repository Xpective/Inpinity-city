// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library PlotMath {
    function totalArea(uint32 width, uint32 height) internal pure returns (uint256) {
        return uint256(width) * uint256(height);
    }

    function isSameSize(
        uint32 widthA,
        uint32 heightA,
        uint32 widthB,
        uint32 heightB
    ) internal pure returns (bool) {
        return widthA == widthB && heightA == heightB;
    }

    function isPersonalPlotSize(uint32 width, uint32 height) internal pure returns (bool) {
        return width == 5 && height == 5;
    }

    function isCommunityPlotSize(uint32 width, uint32 height) internal pure returns (bool) {
        return width == 25 && height == 25;
    }

    function isWithinBounds(
        uint32 x,
        uint32 y,
        uint32 width,
        uint32 height
    ) internal pure returns (bool) {
        return x < width && y < height;
    }

    function completionBps(
        uint256 completed,
        uint32 width,
        uint32 height
    ) internal pure returns (uint256) {
        uint256 total = totalArea(width, height);
        if (total == 0) return 0;
        return (completed * 10_000) / total;
    }
}