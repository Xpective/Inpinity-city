/* FILE: contracts/city/contracts/interfaces/INexusDungeon.sol */
/* TYPE: nexus dungeon interface / dungeon lifecycle / reward bridge */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../libraries/NexusTypes.sol";

/*//////////////////////////////////////////////////////////////
                        NEXUS DUNGEON INTERFACE
//////////////////////////////////////////////////////////////*/

interface INexusDungeon {
    /*//////////////////////////////////////////////////////////////
                               READ STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct DungeonRunEligibilityPreview {
        bool allowed;
        bool dungeonExists;
        bool dungeonEnabled;
        bool hasCityKey;
        bool partySizeAllowed;
        bool difficultyAllowed;
        bool coreRequirementMet;
        bool signalRequirementMet;
        bool archiveRequirementMet;
        bool exchangeRequirementMet;
        bool emergencySealBlocked;
        bool worldBossWindowSatisfied;
        uint256 sigilCost;
        bytes32 reasonCode;
    }

    struct DungeonSummaryView {
        uint256 dungeonId;
        NexusTypes.DungeonKind dungeonKind;
        NexusTypes.DungeonDifficulty difficulty;
        NexusTypes.DungeonObjectiveType objectiveType;
        NexusTypes.WorldBossKind worldBossKind;
        uint32 bossCycleId;
        uint32 modifierMask;
        uint32 rewardMask;
        uint32 baseScore;
        uint8 minCoreLevel;
        uint8 minSignalLevel;
        uint8 minArchiveLevel;
        uint8 minExchangeLevel;
        uint256 sigilCost;
        uint64 entryWindowSeconds;
        bool soloAllowed;
        bool squadAllowed;
        bool raidAllowed;
        bool endlessSupported;
        bool enabled;
    }

    /*//////////////////////////////////////////////////////////////
                                WRITES
    //////////////////////////////////////////////////////////////*/

    function openDungeonTier(uint8 newDungeonTier) external;

    function closeDungeonTier(uint8 dungeonTier) external;

    function setDungeonEnabled(
        uint256 dungeonId,
        bool enabled
    ) external;

    function setBossCycle(
        uint32 cycleId,
        NexusTypes.WorldBossKind bossKind,
        uint32 modifierMask,
        uint64 startsAt,
        uint64 endsAt,
        bool active
    ) external;

    function startRun(
        uint256 dungeonId,
        NexusTypes.DungeonDifficulty difficulty,
        uint8 partySize,
        bytes32 participantHash,
        bytes32 seedHash
    ) external returns (uint256 runId);

    function settleRun(
        uint256 runId,
        NexusTypes.DungeonRunState finalState,
        uint32 score,
        uint32 depthReached,
        uint32 bossPhaseReached,
        bool bossDefeated,
        bool extractionSuccess,
        NexusTypes.DungeonRewardClass rewardClass
    ) external returns (NexusTypes.NexusRewardPack memory rewardPack);

    function cancelRun(
        uint256 runId
    ) external;

    function recordBossMemory(
        NexusTypes.WorldBossKind bossKind,
        uint32 memoryPages,
        uint8 knowledgeLevel,
        bool weaknessUnlocked,
        bool routeBonusUnlocked,
        bool archiveBonusUnlocked
    ) external;

    /*//////////////////////////////////////////////////////////////
                                 READS
    //////////////////////////////////////////////////////////////*/

    function getDungeonConfig(
        uint256 dungeonId
    ) external view returns (NexusTypes.DungeonConfig memory);

    function getDungeonSummary(
        uint256 dungeonId
    ) external view returns (DungeonSummaryView memory);

    function getRun(
        uint256 runId
    ) external view returns (NexusTypes.DungeonRun memory);

    function getBossCycle(
        uint32 cycleId
    ) external view returns (NexusTypes.DungeonBossCycle memory);

    function getBossMemoryState(
        NexusTypes.WorldBossKind bossKind
    ) external view returns (NexusTypes.BossMemoryState memory);

    function previewRunEligibility(
        uint256 dungeonId,
        NexusTypes.DungeonDifficulty difficulty,
        address initiator,
        uint8 partySize
    ) external view returns (DungeonRunEligibilityPreview memory);

    function isDungeonTierOpen(
        uint8 dungeonTier
    ) external view returns (bool);

    function getGlobalDungeonTier() external view returns (uint8);

    function getNextRunId() external view returns (uint256);
}