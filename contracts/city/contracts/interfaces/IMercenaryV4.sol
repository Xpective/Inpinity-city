// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IMercenaryV4 {
    struct ProtectionSlot {
        uint256 tokenId;
        uint64 startTime;
        uint64 expiry;
        uint64 cooldownUntil;
        uint64 emergencyReadyAt;
        uint8 protectionTier;
        bool active;
    }

    function getProtectionLevel(uint256 tokenId) external view returns (uint256);

    function getProtectionData(uint256 tokenId)
        external
        view
        returns (
            address protector,
            uint8 slotIndex,
            bool active,
            uint256 startTime,
            uint256 expiry,
            uint256 cooldownUntil,
            uint256 emergencyReadyAt,
            uint256 tier,
            uint256 protectionPercent
        );

    function getWalletSlots(address user)
        external
        view
        returns (uint8 slots, ProtectionSlot[3] memory data);

    function getRank(address user) external view returns (uint8 rank, string memory name);
    function getDefenderProfile(address user)
        external
        view
        returns (
            uint256 points,
            uint8 rank,
            uint256 discountBps,
            uint256 protectedDays,
            uint256 defenses,
            uint256 extensionsCount,
            uint256 cleanups,
            string memory title
        );

    function moveProtection(uint8 slotIndex, uint256 newTokenId) external;
    function emergencyMoveProtection(uint8 slotIndex, uint256 newTokenId) external;
}