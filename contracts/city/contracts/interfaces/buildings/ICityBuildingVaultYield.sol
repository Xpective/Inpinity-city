/* FILE: contracts/city/contracts/interfaces/buildings/ICityBuildingVaultYield.sol */
/* TYPE: separate warehouse yield / staking read interface — NOT base vault interface */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ICityBuildingVaultYield {
    function getResourceYieldConfig(
        uint8 resourceId
    )
        external
        view
        returns (
            uint32 sevenDayBaseBps,
            uint32 thirtyDayBaseBps,
            bool enabled
        );

    function getWarehouseYieldPosition(
        uint256 buildingId,
        uint8 resourceId
    )
        external
        view
        returns (
            uint256 amount,
            uint256 protectionShiftedAmount,
            uint64 startedAt,
            uint64 maturityAt,
            uint8 lockMode,
            uint32 effectiveYieldBps,
            bool active,
            bool matured,
            uint256 previewYieldAmount
        );

    function previewWarehouseYieldSettlement(
        uint256 buildingId,
        uint8 resourceId
    )
        external
        view
        returns (
            uint256 principalAmount,
            uint256 yieldAmount,
            bool matured,
            uint64 maturityAt
        );

    function isWarehouseYieldEligible(
        uint256 buildingId
    ) external view returns (bool);

    function getEffectiveWarehouseYieldBps(
        uint256 buildingId,
        uint8 resourceId,
        uint8 lockMode
    ) external view returns (uint32);
}