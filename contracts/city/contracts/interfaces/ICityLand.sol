// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ICityLand {
    struct QubiqProgressView {
        uint256 oilDeposited;
        uint256 lemonsDeposited;
        uint256 ironDeposited;
        bool completed;
        bool usedAether;
        address lastContributor;
        uint64 completedAt;
    }

    function completedQubiqCountOf(uint256 plotId) external view returns (uint256);
    function aetherUsesOf(uint256 plotId) external view returns (uint256);

    function getQubiq(
        uint256 plotId,
        uint32 x,
        uint32 y
    ) external view returns (QubiqProgressView memory);

    function isPlotFullyCompleted(uint256 plotId) external view returns (bool);
    function getPlotCompletionBps(uint256 plotId) external view returns (uint256);

    function contributeQubiq(
        uint256 plotId,
        uint32 x,
        uint32 y,
        uint256 oilAmount,
        uint256 lemonsAmount,
        uint256 ironAmount
    ) external;

    function useAetherOnQubiq(
        uint256 plotId,
        uint32 x,
        uint32 y
    ) external;
}