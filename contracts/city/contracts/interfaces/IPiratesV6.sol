// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPiratesV6 {
    struct AttackData {
        address attacker;
        uint256 attackerTokenId;
        uint256 targetTokenId;
        uint256 startTime;
        uint256 endTime;
        uint8 resource;
        bool executed;
        bool cancelled;
    }

    function startAttack(uint256 attackerTokenId, uint256 targetTokenId, uint8 resourceId) external;
    function executeAttack(uint256 targetTokenId, uint256 attackIndex) external;
    function cancelOwnPendingAttack(uint256 targetTokenId, uint256 attackIndex) external;

    function buyPirateBoost(uint256 tokenId, uint256 daysAmount) external;

    function canAttackTarget(address attacker, uint256 targetTokenId) external view returns (bool);
    function getRemainingAttacksToday(address attacker) external view returns (uint256);
    function getAttackTime(uint256 attackerTokenId, uint256 targetTokenId) external view returns (uint256);

    function getAttackCount(uint256 targetTokenId) external view returns (uint256);
    function getAttack(uint256 targetTokenId, uint256 index) external view returns (AttackData memory);

    function hasPirateBoost(uint256 tokenId) external view returns (bool);
    function getPirateBoostExpiry(uint256 tokenId) external view returns (uint256);

    function farming() external view returns (address);
    function RESOURCE_COUNT() external view returns (uint8);
}