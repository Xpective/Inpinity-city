// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library SlotLogic {
    function isValidNextSlot(
        uint8 requestedSlot,
        uint8 currentCount,
        uint256 maxSlots
    ) internal pure returns (bool) {
        if (requestedSlot >= maxSlots) return false;
        return requestedSlot == currentCount;
    }

    function hasReachedMax(
        uint8 currentCount,
        uint256 maxSlots
    ) internal pure returns (bool) {
        return currentCount >= maxSlots;
    }

    function nextSlot(uint8 currentCount) internal pure returns (uint8) {
        return currentCount;
    }
}