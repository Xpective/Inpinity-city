/* FILE: contracts/city/contracts/buildings/NexusRewardRouter.sol */
/* TYPE: nexus reward router / historical ledger / drop integration layer — NOT NFT, NOT NexusDungeon */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "../libraries/NexusTypes.sol";

/*//////////////////////////////////////////////////////////////
                    EXTERNAL DROP RECEIVER INTERFACE
//////////////////////////////////////////////////////////////*/

/// @notice Generic receiver interface for future drop / event / permit / payout contracts.
/// @dev Any target can implement these hooks; the router is fail-open and will not revert
///      if a target call fails. Instead it emits RouteDispatchFailed.
interface INexusRewardRouteReceiver {
    function onRoutedDungeonReward(
        bytes32 routeKey,
        uint256 runId,
        address player,
        uint256 dungeonId,
        uint32 seasonId,
        NexusTypes.DungeonRun calldata runData,
        NexusTypes.NexusRewardPack calldata rewardPack,
        uint256 rankingScoreDelta,
        uint256 eventCreditDelta
    ) external;

    function onRoutedBossMemory(
        bytes32 routeKey,
        NexusTypes.WorldBossKind bossKind,
        NexusTypes.BossMemoryState calldata bossMemory
    ) external;

    function onRoutedLeaderboardUpdate(
        bytes32 routeKey,
        address player,
        uint32 seasonId,
        uint256 globalRankingScore,
        uint256 seasonRankingScore,
        uint256 totalBossKills
    ) external;
}

/*//////////////////////////////////////////////////////////////
                        NEXUS REWARD ROUTER
//////////////////////////////////////////////////////////////*/

/// @title NexusRewardRouter
/// @notice Central routing, accounting and historical ledger for Nexus dungeon rewards,
///         ranking snapshots, boss memory updates and future drop integrations.
/// @dev This contract does not mint rewards by itself. It records history, accrues abstract
///      event credits / permit units, and forwards structured payloads to external drop
///      contracts via route keys.
///      It is intentionally fail-open for route dispatches so external drop contracts
///      cannot brick the dungeon settlement flow.
contract NexusRewardRouter is AccessControl, Pausable, ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                                 ROLES
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant ROUTER_ADMIN_ROLE = keccak256("ROUTER_ADMIN_ROLE");
    bytes32 public constant ROUTER_OPERATOR_ROLE = keccak256("ROUTER_OPERATOR_ROLE");
    bytes32 public constant DUNGEON_HOOK_ROLE = keccak256("DUNGEON_HOOK_ROLE");
    bytes32 public constant PORTAL_HOOK_ROLE = keccak256("PORTAL_HOOK_ROLE");
    bytes32 public constant DROP_MANAGER_ROLE = keccak256("DROP_MANAGER_ROLE");
    bytes32 public constant CLAIM_MANAGER_ROLE = keccak256("CLAIM_MANAGER_ROLE");

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint32 public constant MAX_BPS = 10_000;

    bytes32 public constant ROUTE_KEY_SETTLEMENT_GLOBAL =
        keccak256("NEXUS_ROUTE_SETTLEMENT_GLOBAL");

    bytes32 public constant ROUTE_KEY_SETTLEMENT_EVENT_ELIGIBLE =
        keccak256("NEXUS_ROUTE_SETTLEMENT_EVENT_ELIGIBLE");

    bytes32 public constant ROUTE_KEY_SETTLEMENT_WORLD_BOSS =
        keccak256("NEXUS_ROUTE_SETTLEMENT_WORLD_BOSS");

    bytes32 public constant ROUTE_KEY_BOSS_MEMORY_GLOBAL =
        keccak256("NEXUS_ROUTE_BOSS_MEMORY_GLOBAL");

    bytes32 public constant ROUTE_KEY_LEADERBOARD_GLOBAL =
        keccak256("NEXUS_ROUTE_LEADERBOARD_GLOBAL");

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error InvalidHookContract();
    error InvalidRouteTarget();
    error InvalidRouteKey();
    error InvalidBps();
    error InvalidRunId();
    error InvalidPlayer();

    error RunAlreadyRouted(uint256 runId);
    error AmountExceedsClaimableCredits();
    error AmountExceedsClaimablePermitUnits();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event DungeonContractSet(
        address indexed oldContract,
        address indexed newContract,
        address indexed executor
    );

    event PortalContractSet(
        address indexed oldContract,
        address indexed newContract,
        address indexed executor
    );

    event RouteTargetSet(
        bytes32 indexed routeKey,
        address indexed target,
        bool enabled,
        address indexed executor
    );

    event SeasonRewardConfigSet(
        uint32 indexed seasonId,
        bool enabled,
        uint32 eventPointMultiplierBps,
        uint32 rankingScoreBps,
        uint32 bossKillFlatBonus,
        uint32 extractionFlatBonus,
        uint32 worldBossFlatBonus,
        uint32 maxCreditsPerRun,
        address indexed executor
    );

    event DungeonRewardCaptured(
        uint256 indexed runId,
        address indexed player,
        uint256 indexed dungeonId,
        uint32 seasonId,
        NexusTypes.DungeonRewardClass rewardClass,
        uint256 rankingScoreDelta,
        uint256 eventCreditDelta,
        uint32 permitUnitsDelta,
        uint64 settledAt
    );

    event BossMemoryCaptured(
        NexusTypes.WorldBossKind indexed bossKind,
        uint32 memoryPages,
        uint8 knowledgeLevel,
        bool weaknessUnlocked,
        bool routeBonusUnlocked,
        bool archiveBonusUnlocked,
        uint64 updatedAt
    );

    event LeaderboardSnapshotCaptured(
        address indexed player,
        uint32 indexed seasonId,
        uint256 globalRankingScore,
        uint256 seasonRankingScore,
        uint256 totalBossKills,
        uint64 updatedAt
    );

    event ClaimableSeasonAllocationConsumed(
        uint32 indexed seasonId,
        address indexed player,
        uint256 creditsConsumed,
        uint32 permitUnitsConsumed,
        address indexed executor
    );

    event RouteDispatched(
        bytes32 indexed routeKey,
        address indexed target,
        bytes4 indexed selector
    );

    event RouteDispatchFailed(
        bytes32 indexed routeKey,
        address indexed target,
        bytes4 indexed selector,
        bytes reason
    );

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    address public dungeonContract;
    address public portalContract;

    struct RouteTargetConfig {
        address target;
        bool enabled;
        uint64 updatedAt;
    }

    struct SeasonRewardConfig {
        bool enabled;
        uint32 eventPointMultiplierBps;
        uint32 rankingScoreBps;
        uint32 bossKillFlatBonus;
        uint32 extractionFlatBonus;
        uint32 worldBossFlatBonus;
        uint32 maxCreditsPerRun;
    }

    struct RoutedRewardRecord {
        uint256 runId;
        address player;
        uint256 dungeonId;
        uint32 seasonId;
        uint32 score;
        uint32 depthReached;
        uint32 bossPhaseReached;
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
        uint32 permitUnitsDelta;
        uint256 rankingScoreDelta;
        uint256 eventCreditDelta;
        uint64 settledAt;
        NexusTypes.DungeonDifficulty difficulty;
        NexusTypes.DungeonRewardClass rewardClass;
        NexusTypes.DungeonRunState finalState;
        bool bossDefeated;
        bool extractionSuccess;
        bool eventDropEligible;
        bytes32 cosmeticDropId;
        bytes32 provenanceDropId;
    }

    struct RankingSnapshot {
        uint32 seasonId;
        uint256 globalRankingScore;
        uint256 seasonRankingScore;
        uint256 totalBossKills;
        uint64 updatedAt;
    }

    struct PlayerRewardSummary {
        uint32 lastSeasonId;
        uint64 totalRunsSettled;
        uint64 successfulRuns;
        uint64 failedRuns;
        uint64 cancelledRuns;
        uint64 extractedRuns;
        uint64 totalBossDefeats;

        uint64 totalBlueprintFragments;
        uint64 totalRelicShards;
        uint64 totalCodexKeys;
        uint64 totalDungeonSigils;
        uint64 totalRouteCoordinates;
        uint64 totalArchiveSeals;
        uint64 totalEventPermits;

        uint64 totalPrestigeScore;
        uint64 totalHistoryScore;

        uint64 totalPermitUnitsAccrued;
        uint64 totalPermitUnitsConsumed;

        uint256 totalRankingScoreAccrued;
        uint256 lastGlobalRankingScore;
        uint256 lastSeasonRankingScore;

        uint256 totalEventCreditsAccrued;
        uint256 totalEventCreditsConsumed;

        uint64 lastInteractionAt;
    }

    struct SeasonRewardSummary {
        uint32 seasonId;
        uint64 totalRunsSettled;
        uint64 successfulRuns;
        uint64 failedRuns;
        uint64 cancelledRuns;
        uint64 extractedRuns;
        uint64 totalBossDefeats;

        uint64 totalBlueprintFragments;
        uint64 totalRelicShards;
        uint64 totalCodexKeys;
        uint64 totalDungeonSigils;
        uint64 totalRouteCoordinates;
        uint64 totalArchiveSeals;
        uint64 totalEventPermits;

        uint64 totalPrestigeScore;
        uint64 totalHistoryScore;

        uint64 totalPermitUnitsAccrued;
        uint64 totalPermitUnitsConsumed;

        uint256 totalRankingScoreAccrued;
        uint256 currentSeasonRankingScore;

        uint256 totalEventCreditsAccrued;
        uint256 totalEventCreditsConsumed;

        uint64 lastUpdatedAt;
    }

    mapping(bytes32 => RouteTargetConfig) private _routeTargetByKey;
    mapping(uint32 => SeasonRewardConfig) private _seasonRewardConfigById;

    mapping(uint256 => bool) public isRunRouted;
    mapping(uint256 => RoutedRewardRecord) private _routedRewardRecordByRunId;

    mapping(address => uint256[]) private _routedRunIdsByPlayer;
    mapping(uint32 => uint256[]) private _routedRunIdsBySeason;

    mapping(address => PlayerRewardSummary) private _playerRewardSummaryByAddress;
    mapping(uint32 => mapping(address => SeasonRewardSummary)) private _seasonRewardSummaryByPlayer;

    mapping(uint32 => mapping(address => uint256)) public claimableSeasonCreditsOf;
    mapping(uint32 => mapping(address => uint32)) public claimableSeasonPermitUnitsOf;

    mapping(address => mapping(uint256 => RankingSnapshot)) private _rankingSnapshotByPlayer;
    mapping(address => uint256) public rankingSnapshotCountOf;

    mapping(NexusTypes.WorldBossKind => NexusTypes.BossMemoryState) private _bossMemoryStateByKind;
    mapping(NexusTypes.WorldBossKind => uint256) public bossMemoryUpdateCountOf;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address admin_) {
        if (admin_ == address(0)) revert ZeroAddress();

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ROUTER_ADMIN_ROLE, admin_);
        _grantRole(ROUTER_OPERATOR_ROLE, admin_);
        _grantRole(DROP_MANAGER_ROLE, admin_);
        _grantRole(CLAIM_MANAGER_ROLE, admin_);
    }

    /*//////////////////////////////////////////////////////////////
                                  ADMIN
    //////////////////////////////////////////////////////////////*/

    function pause() external onlyRole(ROUTER_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ROUTER_ADMIN_ROLE) {
        _unpause();
    }

    function setDungeonContract(address dungeonContract_) external onlyRole(ROUTER_ADMIN_ROLE) {
        if (dungeonContract_ == address(0)) revert ZeroAddress();
        if (dungeonContract_.code.length == 0) revert InvalidHookContract();

        address oldContract = dungeonContract;
        if (oldContract != address(0)) {
            _revokeRole(DUNGEON_HOOK_ROLE, oldContract);
        }

        dungeonContract = dungeonContract_;
        _grantRole(DUNGEON_HOOK_ROLE, dungeonContract_);

        emit DungeonContractSet(oldContract, dungeonContract_, msg.sender);
    }

    function setPortalContract(address portalContract_) external onlyRole(ROUTER_ADMIN_ROLE) {
        if (portalContract_ == address(0)) {
            address oldContract = portalContract;
            if (oldContract != address(0)) {
                _revokeRole(PORTAL_HOOK_ROLE, oldContract);
            }
            portalContract = address(0);
            emit PortalContractSet(oldContract, address(0), msg.sender);
            return;
        }

        if (portalContract_.code.length == 0) revert InvalidHookContract();

        address oldPortal = portalContract;
        if (oldPortal != address(0)) {
            _revokeRole(PORTAL_HOOK_ROLE, oldPortal);
        }

        portalContract = portalContract_;
        _grantRole(PORTAL_HOOK_ROLE, portalContract_);

        emit PortalContractSet(oldPortal, portalContract_, msg.sender);
    }

    function setRouteTarget(
        bytes32 routeKey,
        address target,
        bool enabled
    ) external onlyRole(DROP_MANAGER_ROLE) {
        if (routeKey == bytes32(0)) revert InvalidRouteKey();
        if (target != address(0) && target.code.length == 0) revert InvalidRouteTarget();

        if (target == address(0)) {
            enabled = false;
        }

        _routeTargetByKey[routeKey] = RouteTargetConfig({
            target: target,
            enabled: enabled,
            updatedAt: uint64(block.timestamp)
        });

        emit RouteTargetSet(routeKey, target, enabled, msg.sender);
    }

    function setSeasonRewardConfig(
        uint32 seasonId,
        SeasonRewardConfig calldata config
    ) external onlyRole(ROUTER_OPERATOR_ROLE) {
        if (
            config.eventPointMultiplierBps > MAX_BPS ||
            config.rankingScoreBps > MAX_BPS
        ) revert InvalidBps();

        _seasonRewardConfigById[seasonId] = config;

        emit SeasonRewardConfigSet(
            seasonId,
            config.enabled,
            config.eventPointMultiplierBps,
            config.rankingScoreBps,
            config.bossKillFlatBonus,
            config.extractionFlatBonus,
            config.worldBossFlatBonus,
            config.maxCreditsPerRun,
            msg.sender
        );
    }

    function consumeClaimableSeasonAllocation(
        uint32 seasonId,
        address player,
        uint256 creditAmount,
        uint32 permitUnits
    ) external onlyRole(CLAIM_MANAGER_ROLE) nonReentrant {
        if (player == address(0)) revert InvalidPlayer();

        if (creditAmount > claimableSeasonCreditsOf[seasonId][player]) {
            revert AmountExceedsClaimableCredits();
        }
        if (permitUnits > claimableSeasonPermitUnitsOf[seasonId][player]) {
            revert AmountExceedsClaimablePermitUnits();
        }

        claimableSeasonCreditsOf[seasonId][player] -= creditAmount;
        claimableSeasonPermitUnitsOf[seasonId][player] -= permitUnits;

        PlayerRewardSummary storage playerSummary = _playerRewardSummaryByAddress[player];
        SeasonRewardSummary storage seasonSummary = _seasonRewardSummaryByPlayer[seasonId][player];

        playerSummary.totalEventCreditsConsumed += creditAmount;
        playerSummary.totalPermitUnitsConsumed = _addToU64(
            playerSummary.totalPermitUnitsConsumed,
            permitUnits
        );
        playerSummary.lastInteractionAt = uint64(block.timestamp);

        seasonSummary.totalEventCreditsConsumed += creditAmount;
        seasonSummary.totalPermitUnitsConsumed = _addToU64(
            seasonSummary.totalPermitUnitsConsumed,
            permitUnits
        );
        seasonSummary.lastUpdatedAt = uint64(block.timestamp);

        emit ClaimableSeasonAllocationConsumed(
            seasonId,
            player,
            creditAmount,
            permitUnits,
            msg.sender
        );
    }

    /*//////////////////////////////////////////////////////////////
                          DUNGEON HOOK CALLBACKS
    //////////////////////////////////////////////////////////////*/

    /// @notice Called by NexusDungeon after a run is settled.
    /// @dev Signature intentionally matches the hook shape used in your NexusDungeon contract.
    function onDungeonRunSettled(
        uint256 runId,
        address initiator,
        uint256 dungeonId,
        uint32 seasonId,
        NexusTypes.DungeonRun calldata runData,
        NexusTypes.NexusRewardPack calldata rewardPack,
        uint256 rankingScoreDelta,
        bool eventDropEligible
    ) external onlyRole(DUNGEON_HOOK_ROLE) whenNotPaused nonReentrant {
        if (runId == 0) revert InvalidRunId();
        if (initiator == address(0)) revert InvalidPlayer();
        if (isRunRouted[runId]) revert RunAlreadyRouted(runId);

        NexusTypes.DungeonRun memory runSnapshot = runData;
        NexusTypes.NexusRewardPack memory rewardSnapshot = rewardPack;

        uint32 permitUnitsDelta = rewardSnapshot.eventPermits + rewardSnapshot.permitQuota;
        uint256 eventCreditDelta = _computeEventCreditDelta(
            seasonId,
            runSnapshot,
            rewardSnapshot,
            rankingScoreDelta,
            eventDropEligible
        );

        isRunRouted[runId] = true;

        _routedRewardRecordByRunId[runId] = RoutedRewardRecord({
            runId: runId,
            player: initiator,
            dungeonId: dungeonId,
            seasonId: seasonId,
            score: runSnapshot.score,
            depthReached: runSnapshot.depthReached,
            bossPhaseReached: runSnapshot.bossPhaseReached,
            blueprintFragments: rewardSnapshot.blueprintFragments,
            relicShards: rewardSnapshot.relicShards,
            codexKeys: rewardSnapshot.codexKeys,
            dungeonSigils: rewardSnapshot.dungeonSigils,
            routeCoordinates: rewardSnapshot.routeCoordinates,
            archiveSeals: rewardSnapshot.archiveSeals,
            eventPermits: rewardSnapshot.eventPermits,
            prestigeScore: rewardSnapshot.prestigeScore,
            historyScore: rewardSnapshot.historyScore,
            permitQuota: rewardSnapshot.permitQuota,
            permitUnitsDelta: permitUnitsDelta,
            rankingScoreDelta: rankingScoreDelta,
            eventCreditDelta: eventCreditDelta,
            settledAt: uint64(block.timestamp),
            difficulty: runSnapshot.difficulty,
            rewardClass: rewardSnapshot.rewardClass,
            finalState: runSnapshot.state,
            bossDefeated: runSnapshot.bossDefeated,
            extractionSuccess: runSnapshot.extractionSuccess,
            eventDropEligible: eventDropEligible,
            cosmeticDropId: rewardSnapshot.cosmeticDropId,
            provenanceDropId: rewardSnapshot.provenanceDropId
        });

        _routedRunIdsByPlayer[initiator].push(runId);
        _routedRunIdsBySeason[seasonId].push(runId);

        _applyRewardAccounting(
            initiator,
            seasonId,
            runSnapshot,
            rewardSnapshot,
            rankingScoreDelta,
            eventCreditDelta,
            permitUnitsDelta
        );

        emit DungeonRewardCaptured(
            runId,
            initiator,
            dungeonId,
            seasonId,
            rewardSnapshot.rewardClass,
            rankingScoreDelta,
            eventCreditDelta,
            permitUnitsDelta,
            uint64(block.timestamp)
        );

        _dispatchDungeonRewardRoute(
            ROUTE_KEY_SETTLEMENT_GLOBAL,
            runId,
            initiator,
            dungeonId,
            seasonId,
            runSnapshot,
            rewardSnapshot,
            rankingScoreDelta,
            eventCreditDelta
        );

        if (eventDropEligible) {
            _dispatchDungeonRewardRoute(
                ROUTE_KEY_SETTLEMENT_EVENT_ELIGIBLE,
                runId,
                initiator,
                dungeonId,
                seasonId,
                runSnapshot,
                rewardSnapshot,
                rankingScoreDelta,
                eventCreditDelta
            );
        }

        if (runSnapshot.bossDefeated || rewardSnapshot.provenanceDropId != bytes32(0)) {
            _dispatchDungeonRewardRoute(
                ROUTE_KEY_SETTLEMENT_WORLD_BOSS,
                runId,
                initiator,
                dungeonId,
                seasonId,
                runSnapshot,
                rewardSnapshot,
                rankingScoreDelta,
                eventCreditDelta
            );
        }

        if (rewardSnapshot.rewardClass != NexusTypes.DungeonRewardClass.None) {
            _dispatchDungeonRewardRoute(
                rewardClassRouteKey(rewardSnapshot.rewardClass),
                runId,
                initiator,
                dungeonId,
                seasonId,
                runSnapshot,
                rewardSnapshot,
                rankingScoreDelta,
                eventCreditDelta
            );
        }

        _dispatchDungeonRewardRoute(
            seasonSettlementRouteKey(seasonId),
            runId,
            initiator,
            dungeonId,
            seasonId,
            runSnapshot,
            rewardSnapshot,
            rankingScoreDelta,
            eventCreditDelta
        );
    }

    /// @notice Called by NexusDungeon when boss memory changes.
    function onBossMemoryUpdated(
        NexusTypes.WorldBossKind bossKind,
        NexusTypes.BossMemoryState calldata bossMemory
    ) external onlyRole(DUNGEON_HOOK_ROLE) whenNotPaused {
        NexusTypes.BossMemoryState memory memorySnapshot = bossMemory;

        _bossMemoryStateByKind[bossKind] = memorySnapshot;
        bossMemoryUpdateCountOf[bossKind] += 1;

        emit BossMemoryCaptured(
            bossKind,
            memorySnapshot.memoryPages,
            memorySnapshot.knowledgeLevel,
            memorySnapshot.weaknessUnlocked,
            memorySnapshot.routeBonusUnlocked,
            memorySnapshot.archiveBonusUnlocked,
            uint64(block.timestamp)
        );

        _dispatchBossMemoryRoute(
            ROUTE_KEY_BOSS_MEMORY_GLOBAL,
            bossKind,
            memorySnapshot
        );

        _dispatchBossMemoryRoute(
            bossMemoryRouteKey(bossKind),
            bossKind,
            memorySnapshot
        );
    }

    /// @notice Called by NexusDungeon when leaderboard data changes.
    function onLeaderboardScoreUpdated(
        address player,
        uint32 seasonId,
        uint256 globalRankingScore,
        uint256 seasonRankingScore,
        uint256 totalBossKills
    ) external onlyRole(DUNGEON_HOOK_ROLE) whenNotPaused {
        if (player == address(0)) revert InvalidPlayer();

        PlayerRewardSummary storage playerSummary = _playerRewardSummaryByAddress[player];
        SeasonRewardSummary storage seasonSummary = _seasonRewardSummaryByPlayer[seasonId][player];

        playerSummary.lastGlobalRankingScore = globalRankingScore;
        playerSummary.lastSeasonRankingScore = seasonRankingScore;
        playerSummary.lastSeasonId = seasonId;
        playerSummary.lastInteractionAt = uint64(block.timestamp);

        seasonSummary.seasonId = seasonId;
        seasonSummary.currentSeasonRankingScore = seasonRankingScore;
        seasonSummary.lastUpdatedAt = uint64(block.timestamp);

        uint256 snapshotIndex = rankingSnapshotCountOf[player];
        _rankingSnapshotByPlayer[player][snapshotIndex] = RankingSnapshot({
            seasonId: seasonId,
            globalRankingScore: globalRankingScore,
            seasonRankingScore: seasonRankingScore,
            totalBossKills: totalBossKills,
            updatedAt: uint64(block.timestamp)
        });
        rankingSnapshotCountOf[player] = snapshotIndex + 1;

        emit LeaderboardSnapshotCaptured(
            player,
            seasonId,
            globalRankingScore,
            seasonRankingScore,
            totalBossKills,
            uint64(block.timestamp)
        );

        _dispatchLeaderboardRoute(
            ROUTE_KEY_LEADERBOARD_GLOBAL,
            player,
            seasonId,
            globalRankingScore,
            seasonRankingScore,
            totalBossKills
        );

        _dispatchLeaderboardRoute(
            seasonLeaderboardRouteKey(seasonId),
            player,
            seasonId,
            globalRankingScore,
            seasonRankingScore,
            totalBossKills
        );
    }

    /*//////////////////////////////////////////////////////////////
                                  READS
    //////////////////////////////////////////////////////////////*/

    function getPlayerRewardSummary(
        address player
    ) external view returns (PlayerRewardSummary memory) {
        return _playerRewardSummaryByAddress[player];
    }

    function getSeasonRewardSummary(
        uint32 seasonId,
        address player
    )
        external
        view
        returns (
            SeasonRewardSummary memory summary,
            uint256 claimableCredits,
            uint32 claimablePermitUnits
        )
    {
        summary = _seasonRewardSummaryByPlayer[seasonId][player];
        claimableCredits = claimableSeasonCreditsOf[seasonId][player];
        claimablePermitUnits = claimableSeasonPermitUnitsOf[seasonId][player];
    }

    function getSeasonRewardConfig(
        uint32 seasonId
    ) external view returns (SeasonRewardConfig memory) {
        return _seasonRewardConfigById[seasonId];
    }

    function getRouteTarget(
        bytes32 routeKey
    ) external view returns (RouteTargetConfig memory) {
        return _routeTargetByKey[routeKey];
    }

    function getRoutedRewardRecord(
        uint256 runId
    ) external view returns (RoutedRewardRecord memory) {
        return _routedRewardRecordByRunId[runId];
    }

    function getPlayerRoutedRunCount(address player) external view returns (uint256) {
        return _routedRunIdsByPlayer[player].length;
    }

    function getPlayerRoutedRunIdAt(
        address player,
        uint256 index
    ) external view returns (uint256) {
        return _routedRunIdsByPlayer[player][index];
    }

    function getSeasonRoutedRunCount(uint32 seasonId) external view returns (uint256) {
        return _routedRunIdsBySeason[seasonId].length;
    }

    function getSeasonRoutedRunIdAt(
        uint32 seasonId,
        uint256 index
    ) external view returns (uint256) {
        return _routedRunIdsBySeason[seasonId][index];
    }

    function getRankingSnapshotAt(
        address player,
        uint256 index
    ) external view returns (RankingSnapshot memory) {
        return _rankingSnapshotByPlayer[player][index];
    }

    function getBossMemoryState(
        NexusTypes.WorldBossKind bossKind
    ) external view returns (NexusTypes.BossMemoryState memory) {
        return _bossMemoryStateByKind[bossKind];
    }

    function previewEventCreditDelta(
        uint32 seasonId,
        NexusTypes.DungeonRun calldata runData,
        NexusTypes.NexusRewardPack calldata rewardPack,
        uint256 rankingScoreDelta,
        bool eventDropEligible
    ) external view returns (uint256) {
        NexusTypes.DungeonRun memory runSnapshot = runData;
        NexusTypes.NexusRewardPack memory rewardSnapshot = rewardPack;

        return _computeEventCreditDelta(
            seasonId,
            runSnapshot,
            rewardSnapshot,
            rankingScoreDelta,
            eventDropEligible
        );
    }

    function rewardClassRouteKey(
        NexusTypes.DungeonRewardClass rewardClass
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encodePacked("NEXUS_ROUTE_REWARD_CLASS", uint8(rewardClass))
        );
    }

    function seasonSettlementRouteKey(
        uint32 seasonId
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encodePacked("NEXUS_ROUTE_SEASON_SETTLEMENT", seasonId)
        );
    }

    function seasonLeaderboardRouteKey(
        uint32 seasonId
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encodePacked("NEXUS_ROUTE_SEASON_LEADERBOARD", seasonId)
        );
    }

    function bossMemoryRouteKey(
        NexusTypes.WorldBossKind bossKind
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encodePacked("NEXUS_ROUTE_BOSS_MEMORY", uint8(bossKind))
        );
    }

    /*//////////////////////////////////////////////////////////////
                               INTERNALS
    //////////////////////////////////////////////////////////////*/

    function _applyRewardAccounting(
        address player,
        uint32 seasonId,
        NexusTypes.DungeonRun memory runData,
        NexusTypes.NexusRewardPack memory rewardPack,
        uint256 rankingScoreDelta,
        uint256 eventCreditDelta,
        uint32 permitUnitsDelta
    ) internal {
        PlayerRewardSummary storage playerSummary = _playerRewardSummaryByAddress[player];
        SeasonRewardSummary storage seasonSummary = _seasonRewardSummaryByPlayer[seasonId][player];

        playerSummary.lastSeasonId = seasonId;
        playerSummary.lastInteractionAt = uint64(block.timestamp);

        seasonSummary.seasonId = seasonId;
        seasonSummary.lastUpdatedAt = uint64(block.timestamp);

        playerSummary.totalRunsSettled = _addToU64(playerSummary.totalRunsSettled, 1);
        seasonSummary.totalRunsSettled = _addToU64(seasonSummary.totalRunsSettled, 1);

        if (
            runData.state == NexusTypes.DungeonRunState.Completed ||
            runData.state == NexusTypes.DungeonRunState.Extracted
        ) {
            playerSummary.successfulRuns = _addToU64(playerSummary.successfulRuns, 1);
            seasonSummary.successfulRuns = _addToU64(seasonSummary.successfulRuns, 1);
        } else if (
            runData.state == NexusTypes.DungeonRunState.Failed ||
            runData.state == NexusTypes.DungeonRunState.TimedOut
        ) {
            playerSummary.failedRuns = _addToU64(playerSummary.failedRuns, 1);
            seasonSummary.failedRuns = _addToU64(seasonSummary.failedRuns, 1);
        } else if (runData.state == NexusTypes.DungeonRunState.Cancelled) {
            playerSummary.cancelledRuns = _addToU64(playerSummary.cancelledRuns, 1);
            seasonSummary.cancelledRuns = _addToU64(seasonSummary.cancelledRuns, 1);
        }

        if (runData.extractionSuccess) {
            playerSummary.extractedRuns = _addToU64(playerSummary.extractedRuns, 1);
            seasonSummary.extractedRuns = _addToU64(seasonSummary.extractedRuns, 1);
        }

        if (runData.bossDefeated) {
            playerSummary.totalBossDefeats = _addToU64(playerSummary.totalBossDefeats, 1);
            seasonSummary.totalBossDefeats = _addToU64(seasonSummary.totalBossDefeats, 1);
        }

        playerSummary.totalBlueprintFragments = _addToU64(
            playerSummary.totalBlueprintFragments,
            rewardPack.blueprintFragments
        );
        seasonSummary.totalBlueprintFragments = _addToU64(
            seasonSummary.totalBlueprintFragments,
            rewardPack.blueprintFragments
        );

        playerSummary.totalRelicShards = _addToU64(
            playerSummary.totalRelicShards,
            rewardPack.relicShards
        );
        seasonSummary.totalRelicShards = _addToU64(
            seasonSummary.totalRelicShards,
            rewardPack.relicShards
        );

        playerSummary.totalCodexKeys = _addToU64(
            playerSummary.totalCodexKeys,
            rewardPack.codexKeys
        );
        seasonSummary.totalCodexKeys = _addToU64(
            seasonSummary.totalCodexKeys,
            rewardPack.codexKeys
        );

        playerSummary.totalDungeonSigils = _addToU64(
            playerSummary.totalDungeonSigils,
            rewardPack.dungeonSigils
        );
        seasonSummary.totalDungeonSigils = _addToU64(
            seasonSummary.totalDungeonSigils,
            rewardPack.dungeonSigils
        );

        playerSummary.totalRouteCoordinates = _addToU64(
            playerSummary.totalRouteCoordinates,
            rewardPack.routeCoordinates
        );
        seasonSummary.totalRouteCoordinates = _addToU64(
            seasonSummary.totalRouteCoordinates,
            rewardPack.routeCoordinates
        );

        playerSummary.totalArchiveSeals = _addToU64(
            playerSummary.totalArchiveSeals,
            rewardPack.archiveSeals
        );
        seasonSummary.totalArchiveSeals = _addToU64(
            seasonSummary.totalArchiveSeals,
            rewardPack.archiveSeals
        );

        playerSummary.totalEventPermits = _addToU64(
            playerSummary.totalEventPermits,
            rewardPack.eventPermits
        );
        seasonSummary.totalEventPermits = _addToU64(
            seasonSummary.totalEventPermits,
            rewardPack.eventPermits
        );

        playerSummary.totalPrestigeScore = _addToU64(
            playerSummary.totalPrestigeScore,
            rewardPack.prestigeScore
        );
        seasonSummary.totalPrestigeScore = _addToU64(
            seasonSummary.totalPrestigeScore,
            rewardPack.prestigeScore
        );

        playerSummary.totalHistoryScore = _addToU64(
            playerSummary.totalHistoryScore,
            rewardPack.historyScore
        );
        seasonSummary.totalHistoryScore = _addToU64(
            seasonSummary.totalHistoryScore,
            rewardPack.historyScore
        );

        playerSummary.totalPermitUnitsAccrued = _addToU64(
            playerSummary.totalPermitUnitsAccrued,
            permitUnitsDelta
        );
        seasonSummary.totalPermitUnitsAccrued = _addToU64(
            seasonSummary.totalPermitUnitsAccrued,
            permitUnitsDelta
        );

        playerSummary.totalRankingScoreAccrued += rankingScoreDelta;
        seasonSummary.totalRankingScoreAccrued += rankingScoreDelta;

        playerSummary.totalEventCreditsAccrued += eventCreditDelta;
        seasonSummary.totalEventCreditsAccrued += eventCreditDelta;

        if (eventCreditDelta != 0) {
            claimableSeasonCreditsOf[seasonId][player] += eventCreditDelta;
        }
        if (permitUnitsDelta != 0) {
            claimableSeasonPermitUnitsOf[seasonId][player] += permitUnitsDelta;
        }
    }

    function _computeEventCreditDelta(
        uint32 seasonId,
        NexusTypes.DungeonRun memory runData,
        NexusTypes.NexusRewardPack memory rewardPack,
        uint256 rankingScoreDelta,
        bool eventDropEligible
    ) internal view returns (uint256 credits) {
        SeasonRewardConfig memory config = _seasonRewardConfigById[seasonId];

        if (!config.enabled && !eventDropEligible) {
            return 0;
        }

        credits = _baseEventCredits(runData, rewardPack);

        if (config.enabled) {
            if (config.rankingScoreBps != 0 && rankingScoreDelta != 0) {
                credits += (rankingScoreDelta * config.rankingScoreBps) / MAX_BPS;
            }

            if (runData.bossDefeated) {
                credits += config.bossKillFlatBonus;
            }

            if (runData.extractionSuccess) {
                credits += config.extractionFlatBonus;
            }

            if (rewardPack.provenanceDropId != bytes32(0)) {
                credits += config.worldBossFlatBonus;
            }

            uint32 multiplier = config.eventPointMultiplierBps == 0
                ? MAX_BPS
                : config.eventPointMultiplierBps;

            credits = (credits * multiplier) / MAX_BPS;

            if (config.maxCreditsPerRun != 0 && credits > config.maxCreditsPerRun) {
                credits = config.maxCreditsPerRun;
            }
        }
    }

    function _baseEventCredits(
        NexusTypes.DungeonRun memory runData,
        NexusTypes.NexusRewardPack memory rewardPack
    ) internal pure returns (uint256 credits) {
        credits += uint256(rewardPack.blueprintFragments) * 5;
        credits += uint256(rewardPack.relicShards) * 12;
        credits += uint256(rewardPack.codexKeys) * 20;
        credits += uint256(rewardPack.dungeonSigils) * 8;
        credits += uint256(rewardPack.routeCoordinates) * 15;
        credits += uint256(rewardPack.archiveSeals) * 18;
        credits += uint256(rewardPack.eventPermits) * 40;
        credits += uint256(rewardPack.permitQuota) * 10;

        credits += uint256(rewardPack.prestigeScore) / 2;
        credits += uint256(rewardPack.historyScore) / 3;

        if (runData.bossDefeated) {
            credits += 60;
        }
        if (runData.extractionSuccess) {
            credits += 25;
        }

        if (runData.difficulty == NexusTypes.DungeonDifficulty.Veteran) {
            credits += 20;
        } else if (runData.difficulty == NexusTypes.DungeonDifficulty.Elite) {
            credits += 40;
        } else if (runData.difficulty == NexusTypes.DungeonDifficulty.Mythic) {
            credits += 75;
        } else if (runData.difficulty == NexusTypes.DungeonDifficulty.Endless) {
            credits += 125;
        }

        if (runData.depthReached != 0) {
            credits += uint256(runData.depthReached) * 2;
        }
    }

    function _dispatchDungeonRewardRoute(
        bytes32 routeKey,
        uint256 runId,
        address player,
        uint256 dungeonId,
        uint32 seasonId,
        NexusTypes.DungeonRun memory runData,
        NexusTypes.NexusRewardPack memory rewardPack,
        uint256 rankingScoreDelta,
        uint256 eventCreditDelta
    ) internal {
        RouteTargetConfig memory config = _routeTargetByKey[routeKey];
        if (!config.enabled || config.target == address(0)) return;

        try INexusRewardRouteReceiver(config.target).onRoutedDungeonReward(
            routeKey,
            runId,
            player,
            dungeonId,
            seasonId,
            runData,
            rewardPack,
            rankingScoreDelta,
            eventCreditDelta
        ) {
            emit RouteDispatched(
                routeKey,
                config.target,
                INexusRewardRouteReceiver.onRoutedDungeonReward.selector
            );
        } catch (bytes memory reason) {
            emit RouteDispatchFailed(
                routeKey,
                config.target,
                INexusRewardRouteReceiver.onRoutedDungeonReward.selector,
                reason
            );
        }
    }

    function _dispatchBossMemoryRoute(
        bytes32 routeKey,
        NexusTypes.WorldBossKind bossKind,
        NexusTypes.BossMemoryState memory bossMemory
    ) internal {
        RouteTargetConfig memory config = _routeTargetByKey[routeKey];
        if (!config.enabled || config.target == address(0)) return;

        try INexusRewardRouteReceiver(config.target).onRoutedBossMemory(
            routeKey,
            bossKind,
            bossMemory
        ) {
            emit RouteDispatched(
                routeKey,
                config.target,
                INexusRewardRouteReceiver.onRoutedBossMemory.selector
            );
        } catch (bytes memory reason) {
            emit RouteDispatchFailed(
                routeKey,
                config.target,
                INexusRewardRouteReceiver.onRoutedBossMemory.selector,
                reason
            );
        }
    }

    function _dispatchLeaderboardRoute(
        bytes32 routeKey,
        address player,
        uint32 seasonId,
        uint256 globalRankingScore,
        uint256 seasonRankingScore,
        uint256 totalBossKills
    ) internal {
        RouteTargetConfig memory config = _routeTargetByKey[routeKey];
        if (!config.enabled || config.target == address(0)) return;

        try INexusRewardRouteReceiver(config.target).onRoutedLeaderboardUpdate(
            routeKey,
            player,
            seasonId,
            globalRankingScore,
            seasonRankingScore,
            totalBossKills
        ) {
            emit RouteDispatched(
                routeKey,
                config.target,
                INexusRewardRouteReceiver.onRoutedLeaderboardUpdate.selector
            );
        } catch (bytes memory reason) {
            emit RouteDispatchFailed(
                routeKey,
                config.target,
                INexusRewardRouteReceiver.onRoutedLeaderboardUpdate.selector,
                reason
            );
        }
    }

    function _addToU64(uint64 current, uint256 delta) internal pure returns (uint64) {
        uint256 next = uint256(current) + delta;
        if (next > type(uint64).max) {
            return type(uint64).max;
        }
        return uint64(next);
    }
}