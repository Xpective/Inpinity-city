/* FILE: contracts/city/contracts/libraries/NexusTypes.sol */
/* TYPE: nexus enums / structs / helper rules — NOT Personal, NOT NFT */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./CollectiveBuildingTypes.sol";

/// @title NexusTypes
/// @notice Shared enums, structs and helper rules for Nexus building, portal and dungeon systems.
/// @dev Prepared for seasonal routes, hidden routes, world-boss windows, dungeon affixes,
///      expedition classes, permit-gated rewards and V2 migration-safe expansion.
library NexusTypes {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint8 internal constant BASE_RESOURCE_SLOT_COUNT = 10;
    uint8 internal constant MAX_PARTY_SIZE = 8;
    uint8 internal constant MAX_ROTATING_ROUTES = 4;

    /*//////////////////////////////////////////////////////////////
                                 ENUMS
    //////////////////////////////////////////////////////////////*/

    enum PortalZoneKind {
        None,
        GlassWastes,
        IronGraveyards,
        CrystalBloomBasin,
        ObsidianScar,
        MysteriumSpiralShore,
        AetherStormfields,
        SunkenRelayRuins,
        ForgottenForgeBelt,
        DrownedBazaarFringe,
        FracturedSkyCauseway,
        HollowOrchardOfLemons,
        TombOfTheFirstSignal
    }

    enum PortalRouteState {
        None,
        Draft,
        Inactive,
        Active,
        Unstable,
        Overloaded,
        Locked,
        Sealed,
        Archived
    }

    enum RouteUnlockClass {
        None,
        Seasonal,
        Hidden,
        BossWindow,
        Emergency,
        ArchiveDecoded
    }

    enum ExpeditionClass {
        None,
        Scout,
        Caravan,
        StrikeTeam,
        RaidExpedition
    }

    enum ExpeditionOutcome {
        None,
        Success,
        PartialSuccess,
        Failure,
        Catastrophic
    }

    enum WorldBossKind {
        None,
        RelayWarden,
        IronSaint,
        ObsidianMawmother,
        ArchivistOfDust,
        FracturedMerchant,
        HollowBeacon,
        CathedralEngine,
        CrystalChoir,
        RedSurveyor,
        AetherJudge
    }

    enum DungeonKind {
        None,
        RelayCatacombs,
        IronMausoleum,
        ObsidianMaw,
        CrystalLabyrinth,
        MysteriumCoil,
        AetherCathedral,
        VaultOfEchoes,
        SunkenFoundry,
        BazaarCatacombs,
        RiftTreasury,
        FracturedCommandNexus,
        TombOfTheOuterGate
    }

    enum DungeonDifficulty {
        None,
        Story,
        Normal,
        Veteran,
        Elite,
        Mythic,
        Endless
    }

    enum DungeonObjectiveType {
        None,
        Clear,
        Rescue,
        Escort,
        Extraction,
        BossHunt
    }

    enum DungeonRunState {
        None,
        Queued,
        Active,
        Completed,
        Failed,
        Extracted,
        TimedOut,
        Cancelled
    }

    enum DungeonRewardClass {
        None,
        BlueprintFragments,
        RelicShards,
        CodexKeys,
        DungeonSigils,
        RouteCoordinates,
        ArchiveSeals,
        EventPermits,
        CosmeticUnlock,
        PrestigeHistory,
        Mixed
    }

    enum NexusModifierType {
        None,
        StaticSurge,
        CorrosionFog,
        HungerPulse,
        GravitySplit,
        EchoDoubles,
        AntiMateriaField,
        BlindSignal,
        ShadowDebt,
        ObsidianPressure,
        AetherBleed
    }

    enum NexusEventType {
        None,
        StabilitySurge,
        PortalOverload,
        WorldBossWindow,
        ExpeditionRush,
        DungeonSeasonShift,
        EmergencySeal,
        ArchiveBreakthrough,
        ExchangeFestival,
        AetherStorm,
        CitywideDefense,
        HiddenRouteUnlocked
    }

    enum PermitScope {
        None,
        CraftedOutputTrade,
        AuctionAccess,
        ExpeditionSupply,
        DungeonEntry,
        PortalAccess,
        CitywideService,
        EventEntry
    }

    enum RewardAssetClass {
        None,
        ResourceBundle,
        Blueprint,
        Relic,
        Key,
        Permit,
        Cosmetic,
        Chronicle,
        TreasuryNote
    }

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct PortalRoute {
        uint256 routeId;
        PortalZoneKind zoneKind;
        PortalRouteState state;
        RouteUnlockClass unlockClass;
        WorldBossKind worldBossKind;
        uint8 requiredCoreLevel;
        uint8 requiredSignalLevel;
        uint8 requiredArchiveLevel;
        uint8 requiredExchangeLevel;
        uint32 stabilityBps;
        uint32 instabilityBps;
        uint256 aetherActivationCost;
        uint256 aetherMaintenanceCost;
        uint64 openAt;
        uint64 closeAt;
        uint64 lastStateChangeAt;
        bytes32 discoveryHash;
        bool hiddenRoute;
        bool worldBossEligible;
        bool seasonal;
    }

    struct RouteContributionWindow {
        uint256 windowId;
        uint256 routeId;
        uint256[BASE_RESOURCE_SLOT_COUNT] targetResources;
        uint256[BASE_RESOURCE_SLOT_COUNT] raisedResources;
        uint256 targetAether;
        uint256 raisedAether;
        uint64 opensAt;
        uint64 closesAt;
        bool funded;
        bool closed;
    }

    struct ExpeditionConfig {
        uint256 configId;
        ExpeditionClass expeditionClass;
        PortalZoneKind zoneKind;
        uint8 minCoreLevel;
        uint8 minSignalLevel;
        uint8 minArchiveLevel;
        uint8 minExchangeLevel;
        uint8 maxParticipants;
        uint256[BASE_RESOURCE_SLOT_COUNT] supplyAmounts;
        uint32 riskBps;
        uint32 successBonusBps;
        uint32 salvageBps;
        uint64 cooldownSeconds;
        bool publicQueue;
        bool worldBossEligible;
        bool enabled;
    }

    struct ExpeditionResult {
        uint256 expeditionId;
        ExpeditionOutcome outcome;
        RewardAssetClass primaryAssetClass;
        uint32 score;
        uint32 instabilityImpactBps;
        bool hiddenRouteDiscovered;
        bool bossTriggered;
        uint64 resolvedAt;
    }

    struct DungeonConfig {
        uint256 dungeonId;
        DungeonKind dungeonKind;
        DungeonDifficulty difficulty;
        DungeonObjectiveType objectiveType;
        WorldBossKind worldBossKind;
        uint8 minCoreLevel;
        uint8 minSignalLevel;
        uint8 minArchiveLevel;
        uint8 minExchangeLevel;
        uint32 modifierMask;
        uint32 rewardMask;
        uint32 bossCycleId;
        uint32 baseScore;
        uint256 sigilCost;
        uint64 entryWindowSeconds;
        bool soloAllowed;
        bool squadAllowed;
        bool raidAllowed;
        bool endlessSupported;
        bool enabled;
    }

    struct DungeonBossCycle {
        uint32 cycleId;
        WorldBossKind bossKind;
        uint32 modifierMask;
        uint64 startsAt;
        uint64 endsAt;
        bool active;
    }

    struct DungeonRun {
        uint256 runId;
        uint256 dungeonId;
        DungeonKind dungeonKind;
        DungeonDifficulty difficulty;
        DungeonRunState state;
        address initiator;
        uint8 partySize;
        uint32 modifierMask;
        uint32 score;
        uint32 depthReached;
        uint32 bossPhaseReached;
        RewardAssetClass primaryRewardClass;
        bytes32 participantHash;
        bytes32 seedHash;
        uint64 startedAt;
        uint64 endedAt;
        bool bossDefeated;
        bool extractionSuccess;
    }

    struct NexusRewardPack {
        DungeonRewardClass rewardClass;
        uint256[BASE_RESOURCE_SLOT_COUNT] resourceAmounts;
        uint32 blueprintFragments;
        uint32 relicShards;
        uint32 codexKeys;
        uint32 dungeonSigils;
        uint32 routeCoordinates;
        uint32 archiveSeals;
        uint32 eventPermits;
        uint32 prestigeScore;
        uint32 historyScore;
        uint32 permitQuota;
        bytes32 cosmeticDropId;
        bytes32 provenanceDropId;
    }

    struct BossMemoryState {
        WorldBossKind bossKind;
        uint32 memoryPages;
        uint8 knowledgeLevel;
        uint64 lastUpdatedAt;
        bool weaknessUnlocked;
        bool routeBonusUnlocked;
        bool archiveBonusUnlocked;
    }

    struct HiddenRouteRecord {
        uint256 routeId;
        bytes32 discoveryHash;
        address discoveredBy;
        uint64 discoveredAt;
        bool unlocked;
    }

    struct WorldBossWindow {
        uint256 windowId;
        WorldBossKind bossKind;
        PortalZoneKind zoneKind;
        uint64 opensAt;
        uint64 closesAt;
        uint32 modifierMask;
        bool active;
        bool defeated;
    }

    struct SeasonalRouteRotation {
        uint32 seasonId;
        uint256[MAX_ROTATING_ROUTES] routeIds;
        uint8 activeRouteCount;
        uint64 startsAt;
        uint64 endsAt;
        uint32 modifierMask;
        bool bossWindowOpen;
    }

    struct PermitGrant {
        uint256 permitId;
        PermitScope scope;
        uint64 validFrom;
        uint64 validUntil;
        uint32 quota;
        uint32 used;
        bool transferable;
        bool revoked;
    }

    struct NexusGlobalState {
        uint32 versionTag;
        uint32 seasonId;
        uint8 outerworldTier;
        uint8 dungeonTier;
        uint32 cityStabilityBps;
        uint32 cityInstabilityBps;
        uint32 activeRouteCount;
        uint32 hiddenRouteCount;
        uint32 activeDungeonCount;
        bool emergencySealActive;
        bool worldBossWindowOpen;
        uint64 lastSeasonShiftAt;
        uint64 lastEmergencyActionAt;
    }

    struct NexusMigrationEnvelope {
        uint32 versionTag;
        bool migrationPrepared;
        bool archivedToV2;
        uint64 migrationPreparedAt;
        uint64 archivedAt;
        bytes32 migrationNote;
    }

    /*//////////////////////////////////////////////////////////////
                              VALIDATION
    //////////////////////////////////////////////////////////////*/

    function isValidPortalZone(PortalZoneKind zoneKind) internal pure returns (bool) {
        return zoneKind >= PortalZoneKind.GlassWastes && zoneKind <= PortalZoneKind.TombOfTheFirstSignal;
    }

    function isValidWorldBoss(WorldBossKind bossKind) internal pure returns (bool) {
        return bossKind >= WorldBossKind.RelayWarden && bossKind <= WorldBossKind.AetherJudge;
    }

    function isValidExpeditionClass(ExpeditionClass expeditionClass) internal pure returns (bool) {
        return expeditionClass >= ExpeditionClass.Scout && expeditionClass <= ExpeditionClass.RaidExpedition;
    }

    function isValidDungeonKind(DungeonKind dungeonKind) internal pure returns (bool) {
        return dungeonKind >= DungeonKind.RelayCatacombs && dungeonKind <= DungeonKind.TombOfTheOuterGate;
    }

    function isValidDungeonDifficulty(DungeonDifficulty difficulty) internal pure returns (bool) {
        return difficulty >= DungeonDifficulty.Story && difficulty <= DungeonDifficulty.Endless;
    }

    function isValidDungeonObjectiveType(DungeonObjectiveType objectiveType) internal pure returns (bool) {
        return objectiveType >= DungeonObjectiveType.Clear && objectiveType <= DungeonObjectiveType.BossHunt;
    }

    function isValidModifierType(NexusModifierType modifierType) internal pure returns (bool) {
        return modifierType >= NexusModifierType.StaticSurge && modifierType <= NexusModifierType.AetherBleed;
    }

    function isActiveRouteState(PortalRouteState state_) internal pure returns (bool) {
        return
            state_ == PortalRouteState.Active ||
            state_ == PortalRouteState.Unstable ||
            state_ == PortalRouteState.Overloaded;
    }

    function isRouteEnterableState(PortalRouteState state_) internal pure returns (bool) {
        return state_ == PortalRouteState.Active || state_ == PortalRouteState.Unstable;
    }

    function isTerminalRunState(DungeonRunState state_) internal pure returns (bool) {
        return
            state_ == DungeonRunState.Completed ||
            state_ == DungeonRunState.Failed ||
            state_ == DungeonRunState.Extracted ||
            state_ == DungeonRunState.TimedOut ||
            state_ == DungeonRunState.Cancelled;
    }

    /*//////////////////////////////////////////////////////////////
                           GAMEPLAY HELPERS
    //////////////////////////////////////////////////////////////*/

    function maxParticipantsForExpeditionClass(
        ExpeditionClass expeditionClass
    ) internal pure returns (uint8) {
        if (expeditionClass == ExpeditionClass.Scout) return 1;
        if (expeditionClass == ExpeditionClass.Caravan) return 4;
        if (expeditionClass == ExpeditionClass.StrikeTeam) return 4;
        if (expeditionClass == ExpeditionClass.RaidExpedition) return 8;
        return 0;
    }

    function minLevelForNexusSystem(
        CollectiveBuildingTypes.NexusBuildingKind kind
    ) internal pure returns (uint8) {
        if (
            kind == CollectiveBuildingTypes.NexusBuildingKind.NexusCore ||
            kind == CollectiveBuildingTypes.NexusBuildingKind.NexusSignalSpire
        ) {
            return 3;
        }

        if (
            kind == CollectiveBuildingTypes.NexusBuildingKind.NexusArchive ||
            kind == CollectiveBuildingTypes.NexusBuildingKind.NexusExchangeHub
        ) {
            return 5;
        }

        return 1;
    }
}