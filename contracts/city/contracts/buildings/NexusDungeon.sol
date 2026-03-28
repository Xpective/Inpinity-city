/* FILE: contracts/city/contracts/buildings/NexusDungeon.sol */
/* TYPE: nexus dungeon orchestrator / ranking / boss memory / reward-router hook */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "../libraries/NexusTypes.sol";
import "../libraries/CollectiveBuildingTypes.sol";
import "../interfaces/INexusDungeon.sol";

/*//////////////////////////////////////////////////////////////
                        EXTERNAL INTERFACES
//////////////////////////////////////////////////////////////*/

interface INexusBuildingsDungeonRead {
    function getNexusGlobalState()
        external
        view
        returns (NexusTypes.NexusGlobalState memory);

    function getTokenIdForKind(
        CollectiveBuildingTypes.NexusBuildingKind kind
    ) external view returns (uint256);

    function isCityMemberEligible(address account) external view returns (bool);
}

interface ICollectiveBuildingNFTV1NexusRead {
    function getCollectiveIdentity(
        uint256 tokenId
    ) external view returns (CollectiveBuildingTypes.CollectiveIdentity memory);
}

interface INexusRewardRouterHook {
    function onDungeonRunSettled(
        uint256 runId,
        address initiator,
        uint256 dungeonId,
        uint32 seasonId,
        NexusTypes.DungeonRun calldata runData,
        NexusTypes.NexusRewardPack calldata rewardPack,
        uint256 rankingScoreDelta,
        bool eventDropEligible
    ) external;

    function onBossMemoryUpdated(
        NexusTypes.WorldBossKind bossKind,
        NexusTypes.BossMemoryState calldata bossMemory
    ) external;

    function onLeaderboardScoreUpdated(
        address player,
        uint32 seasonId,
        uint256 globalRankingScore,
        uint256 seasonRankingScore,
        uint256 totalBossKills
    ) external;
}

/*//////////////////////////////////////////////////////////////
                          NEXUS DUNGEON
//////////////////////////////////////////////////////////////*/

contract NexusDungeon is
    AccessControl,
    Pausable,
    ReentrancyGuard,
    INexusDungeon
{
    /*//////////////////////////////////////////////////////////////
                                 ROLES
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant DUNGEON_ADMIN_ROLE = keccak256("DUNGEON_ADMIN_ROLE");
    bytes32 public constant DUNGEON_OPERATOR_ROLE = keccak256("DUNGEON_OPERATOR_ROLE");
    bytes32 public constant DUNGEON_SETTLER_ROLE = keccak256("DUNGEON_SETTLER_ROLE");
    bytes32 public constant ROUTER_SETTER_ROLE = keccak256("ROUTER_SETTER_ROLE");

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint8 public constant GLOBAL_LEADERBOARD_SIZE = 25;
    uint8 public constant SEASON_LEADERBOARD_SIZE = 25;
    uint8 public constant DUNGEON_LEADERBOARD_SIZE = 15;
    uint8 public constant MAX_SPLIT_PATHS = 4;

    uint16 public constant MAX_ENDLESS_DEPTH_CAP = 1000;
    uint32 public constant MAX_BPS = 10_000;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error InvalidNexusBuildings();
    error InvalidCollectiveNFT();
    error InvalidRewardRouter();

    error InvalidDungeonId();
    error InvalidDungeonKind();
    error InvalidDifficulty();
    error InvalidObjectiveType();
    error InvalidBossKind();
    error InvalidPartySize();
    error InvalidTier();
    error InvalidSplitPathCount();
    error InvalidEndlessDepthCap();
    error InvalidScoreBps();
    error InvalidConfig();
    error InvalidFinalState();

    error DungeonNotFound();
    error DungeonDisabled();
    error NoCityKey();
    error ActiveRunExists(uint256 runId);
    error RunNotAllowed(bytes32 reasonCode);
    error RunNotFound();
    error RunNotActive();
    error NotRunInitiatorOrOperator();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event NexusBuildingsSet(address indexed nexusBuildings, address indexed executor);
    event CollectiveNFTSet(address indexed collectiveNFT, address indexed executor);
    event RewardRouterSet(address indexed rewardRouter, address indexed executor);

    event DungeonConfigSet(
        uint256 indexed dungeonId,
        NexusTypes.DungeonKind indexed dungeonKind,
        NexusTypes.DungeonDifficulty difficulty,
        bool enabled,
        address indexed executor
    );

    event DungeonDesignProfileSet(
        uint256 indexed dungeonId,
        uint8 requiredDungeonTier,
        uint8 splitPathCount,
        uint16 endlessDepthCap,
        bool rankingEnabled,
        bool eventDropEligible,
        address indexed executor
    );

    event DungeonEnabledSet(
        uint256 indexed dungeonId,
        bool enabled,
        address indexed executor
    );

    event DungeonTierOpened(
        uint8 indexed dungeonTier,
        address indexed executor,
        uint64 openedAt
    );

    event DungeonTierClosed(
        uint8 indexed dungeonTier,
        address indexed executor,
        uint64 closedAt
    );

    event BossCycleSet(
        uint32 indexed cycleId,
        NexusTypes.WorldBossKind indexed bossKind,
        uint32 modifierMask,
        uint64 startsAt,
        uint64 endsAt,
        bool active,
        address indexed executor
    );

    event DungeonRunStarted(
        uint256 indexed runId,
        uint256 indexed dungeonId,
        address indexed initiator,
        NexusTypes.DungeonKind dungeonKind,
        NexusTypes.DungeonDifficulty difficulty,
        uint8 partySize,
        uint32 seasonId,
        uint32 modifierMask,
        uint64 startedAt
    );

    event DungeonRunSettled(
        uint256 indexed runId,
        uint256 indexed dungeonId,
        address indexed initiator,
        NexusTypes.DungeonRunState finalState,
        uint32 score,
        uint32 depthReached,
        bool bossDefeated,
        bool extractionSuccess,
        NexusTypes.DungeonRewardClass rewardClass,
        uint256 rankingScoreDelta,
        uint32 seasonId,
        uint64 endedAt
    );

    event DungeonRunCancelled(
        uint256 indexed runId,
        uint256 indexed dungeonId,
        address indexed initiator,
        address executor,
        uint64 cancelledAt
    );

    event BossMemoryRecorded(
        NexusTypes.WorldBossKind indexed bossKind,
        uint32 memoryPages,
        uint8 knowledgeLevel,
        bool weaknessUnlocked,
        bool routeBonusUnlocked,
        bool archiveBonusUnlocked,
        address indexed executor,
        uint64 updatedAt
    );

    event PlayerRankingUpdated(
        address indexed player,
        uint32 indexed seasonId,
        uint256 globalRankingScore,
        uint256 seasonRankingScore,
        uint32 totalBossesDefeated,
        uint64 updatedAt
    );

    event RewardRouterNotifyFailed(
        uint256 indexed runId,
        bytes4 indexed selector,
        bytes reason
    );

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    INexusBuildingsDungeonRead public nexusBuildings;
    ICollectiveBuildingNFTV1NexusRead public collectiveNFT;
    INexusRewardRouterHook public rewardRouter;

    uint256 private _nextRunId = 1;
    uint8 private _globalDungeonTier = 1;

    mapping(uint8 => bool) private _dungeonTierOpen;
    mapping(uint256 => NexusTypes.DungeonConfig) private _dungeonConfigById;
    mapping(uint256 => bool) private _dungeonExists;
    mapping(uint256 => uint256[]) private _runIdsByDungeonId;

    struct DungeonDesignProfile {
        uint8 requiredDungeonTier;
        uint8 splitPathCount;
        uint16 endlessDepthCap;
        uint32 affixMask;
        uint32 bonusRewardMask;
        uint32 seasonalScoreBps;
        uint32 bossScoreBps;
        uint32 extractionScoreBps;
        uint32 depthScoreBps;
        bool hiddenPathEnabled;
        bool bossMemoryHooksEnabled;
        bool rankingEnabled;
        bool eventDropEligible;
    }

    mapping(uint256 => DungeonDesignProfile) private _designProfileByDungeonId;

    mapping(uint32 => NexusTypes.DungeonBossCycle) private _bossCycleById;
    mapping(NexusTypes.WorldBossKind => uint32) private _activeBossCycleIdByBossKind;
    mapping(NexusTypes.WorldBossKind => NexusTypes.BossMemoryState) private _bossMemoryByKind;

    mapping(uint256 => NexusTypes.DungeonRun) private _runById;
    mapping(uint256 => NexusTypes.NexusRewardPack) private _rewardPackByRunId;
    mapping(address => uint256) public activeRunIdOf;
    mapping(address => uint256[]) private _runIdsByPlayer;

    struct DungeonPlayerProfile {
        uint32 runsStarted;
        uint32 runsCompleted;
        uint32 runsFailed;
        uint32 runsCancelled;
        uint32 extractions;
        uint32 bossesDefeated;
        uint32 totalScore;
        uint32 bestScore;
        uint32 totalDepth;
        uint32 bestDepth;
        uint32 totalEventPoints;
        uint64 lastRunStartedAt;
        uint64 lastRunSettledAt;
        uint32 lastSeasonId;
    }

    struct PlayerSeasonProfile {
        uint32 runsStarted;
        uint32 runsCompleted;
        uint32 runsFailed;
        uint32 runsCancelled;
        uint32 bossesDefeated;
        uint32 bestScore;
        uint32 bestDepth;
        uint32 totalEventPoints;
        uint64 lastUpdatedAt;
    }

    struct LeaderboardRow {
        address account;
        uint256 rankingScore;
        uint32 bestScore;
        uint32 bestDepth;
        uint32 bossesDefeated;
        uint32 seasonId;
    }

    mapping(address => DungeonPlayerProfile) private _playerProfileByAccount;
    mapping(uint32 => mapping(address => PlayerSeasonProfile)) private _seasonProfileByAccount;

    mapping(address => uint256) public globalRankingScoreOf;
    mapping(uint32 => mapping(address => uint256)) public seasonRankingScoreOf;
    mapping(uint256 => mapping(address => uint256)) public dungeonRankingScoreOf;

    address[] private _globalLeaderboard;
    mapping(uint32 => address[]) private _seasonLeaderboard;
    mapping(uint256 => address[]) private _dungeonLeaderboard;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address nexusBuildings_,
        address collectiveNFT_,
        address admin_
    ) {
        if (nexusBuildings_ == address(0) || collectiveNFT_ == address(0) || admin_ == address(0)) {
            revert ZeroAddress();
        }
        if (nexusBuildings_.code.length == 0) revert InvalidNexusBuildings();
        if (collectiveNFT_.code.length == 0) revert InvalidCollectiveNFT();

        nexusBuildings = INexusBuildingsDungeonRead(nexusBuildings_);
        collectiveNFT = ICollectiveBuildingNFTV1NexusRead(collectiveNFT_);

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(DUNGEON_ADMIN_ROLE, admin_);
        _grantRole(DUNGEON_OPERATOR_ROLE, admin_);
        _grantRole(DUNGEON_SETTLER_ROLE, admin_);
        _grantRole(ROUTER_SETTER_ROLE, admin_);

        _dungeonTierOpen[1] = true;
    }

    /*//////////////////////////////////////////////////////////////
                                  ADMIN
    //////////////////////////////////////////////////////////////*/

    function pause() external onlyRole(DUNGEON_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DUNGEON_ADMIN_ROLE) {
        _unpause();
    }

    function setNexusBuildings(address nexusBuildings_) external onlyRole(DUNGEON_ADMIN_ROLE) {
        if (nexusBuildings_ == address(0)) revert ZeroAddress();
        if (nexusBuildings_.code.length == 0) revert InvalidNexusBuildings();

        nexusBuildings = INexusBuildingsDungeonRead(nexusBuildings_);
        emit NexusBuildingsSet(nexusBuildings_, msg.sender);
    }

    function setCollectiveNFT(address collectiveNFT_) external onlyRole(DUNGEON_ADMIN_ROLE) {
        if (collectiveNFT_ == address(0)) revert ZeroAddress();
        if (collectiveNFT_.code.length == 0) revert InvalidCollectiveNFT();

        collectiveNFT = ICollectiveBuildingNFTV1NexusRead(collectiveNFT_);
        emit CollectiveNFTSet(collectiveNFT_, msg.sender);
    }

    function setRewardRouter(address rewardRouter_) external onlyRole(ROUTER_SETTER_ROLE) {
        if (rewardRouter_ == address(0)) {
            rewardRouter = INexusRewardRouterHook(address(0));
        } else {
            if (rewardRouter_.code.length == 0) revert InvalidRewardRouter();
            rewardRouter = INexusRewardRouterHook(rewardRouter_);
        }

        emit RewardRouterSet(rewardRouter_, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                           DUNGEON CONFIG
    //////////////////////////////////////////////////////////////*/

    function setDungeonConfig(
        NexusTypes.DungeonConfig calldata config
    ) external onlyRole(DUNGEON_OPERATOR_ROLE) {
        if (config.dungeonId == 0) revert InvalidDungeonId();
        if (!NexusTypes.isValidDungeonKind(config.dungeonKind)) revert InvalidDungeonKind();
        if (!NexusTypes.isValidDungeonDifficulty(config.difficulty)) revert InvalidDifficulty();
        if (!NexusTypes.isValidDungeonObjectiveType(config.objectiveType)) revert InvalidObjectiveType();
        if (
            config.worldBossKind != NexusTypes.WorldBossKind.None &&
            !NexusTypes.isValidWorldBoss(config.worldBossKind)
        ) revert InvalidBossKind();

        if (!config.soloAllowed && !config.squadAllowed && !config.raidAllowed) {
            revert InvalidConfig();
        }

        if (
            config.minCoreLevel > CollectiveBuildingTypes.MAX_COLLECTIVE_LEVEL ||
            config.minSignalLevel > CollectiveBuildingTypes.MAX_COLLECTIVE_LEVEL ||
            config.minArchiveLevel > CollectiveBuildingTypes.MAX_COLLECTIVE_LEVEL ||
            config.minExchangeLevel > CollectiveBuildingTypes.MAX_COLLECTIVE_LEVEL
        ) revert InvalidConfig();

        _dungeonConfigById[config.dungeonId] = config;
        _dungeonExists[config.dungeonId] = true;

        emit DungeonConfigSet(
            config.dungeonId,
            config.dungeonKind,
            config.difficulty,
            config.enabled,
            msg.sender
        );
    }

    function setDungeonDesignProfile(
        uint256 dungeonId,
        DungeonDesignProfile calldata profile
    ) external onlyRole(DUNGEON_OPERATOR_ROLE) {
        if (!_dungeonExists[dungeonId]) revert DungeonNotFound();
        if (profile.requiredDungeonTier > CollectiveBuildingTypes.MAX_COLLECTIVE_LEVEL) {
            revert InvalidTier();
        }
        if (profile.splitPathCount > MAX_SPLIT_PATHS) revert InvalidSplitPathCount();
        if (profile.endlessDepthCap > MAX_ENDLESS_DEPTH_CAP) revert InvalidEndlessDepthCap();
        if (
            profile.seasonalScoreBps > MAX_BPS ||
            profile.bossScoreBps > MAX_BPS ||
            profile.extractionScoreBps > MAX_BPS ||
            profile.depthScoreBps > MAX_BPS
        ) revert InvalidScoreBps();

        _designProfileByDungeonId[dungeonId] = profile;

        emit DungeonDesignProfileSet(
            dungeonId,
            profile.requiredDungeonTier,
            profile.splitPathCount,
            profile.endlessDepthCap,
            profile.rankingEnabled,
            profile.eventDropEligible,
            msg.sender
        );
    }

    function setDungeonEnabled(
        uint256 dungeonId,
        bool enabled
    ) external override onlyRole(DUNGEON_OPERATOR_ROLE) {
        if (!_dungeonExists[dungeonId]) revert DungeonNotFound();

        _dungeonConfigById[dungeonId].enabled = enabled;

        emit DungeonEnabledSet(dungeonId, enabled, msg.sender);
    }

    function openDungeonTier(
        uint8 newDungeonTier
    ) external override onlyRole(DUNGEON_OPERATOR_ROLE) {
        if (newDungeonTier == 0 || newDungeonTier > CollectiveBuildingTypes.MAX_COLLECTIVE_LEVEL) {
            revert InvalidTier();
        }

        for (uint8 tier = 1; tier <= newDungeonTier; tier++) {
            if (!_dungeonTierOpen[tier]) {
                _dungeonTierOpen[tier] = true;
                emit DungeonTierOpened(tier, msg.sender, uint64(block.timestamp));
            }
        }

        if (newDungeonTier > _globalDungeonTier) {
            _globalDungeonTier = newDungeonTier;
        }
    }

    function closeDungeonTier(
        uint8 dungeonTier
    ) external override onlyRole(DUNGEON_OPERATOR_ROLE) {
        if (dungeonTier == 0 || dungeonTier > CollectiveBuildingTypes.MAX_COLLECTIVE_LEVEL) {
            revert InvalidTier();
        }

        if (_dungeonTierOpen[dungeonTier]) {
            _dungeonTierOpen[dungeonTier] = false;
            emit DungeonTierClosed(dungeonTier, msg.sender, uint64(block.timestamp));
        }

        _globalDungeonTier = _recomputeHighestOpenTier();
    }

    function setBossCycle(
        uint32 cycleId,
        NexusTypes.WorldBossKind bossKind,
        uint32 modifierMask,
        uint64 startsAt,
        uint64 endsAt,
        bool active
    ) external override onlyRole(DUNGEON_OPERATOR_ROLE) {
        if (bossKind != NexusTypes.WorldBossKind.None && !NexusTypes.isValidWorldBoss(bossKind)) {
            revert InvalidBossKind();
        }
        if (startsAt >= endsAt) revert InvalidConfig();

        _bossCycleById[cycleId] = NexusTypes.DungeonBossCycle({
            cycleId: cycleId,
            bossKind: bossKind,
            modifierMask: modifierMask,
            startsAt: startsAt,
            endsAt: endsAt,
            active: active
        });

        if (active && bossKind != NexusTypes.WorldBossKind.None) {
            _activeBossCycleIdByBossKind[bossKind] = cycleId;
        } else if (!active && bossKind != NexusTypes.WorldBossKind.None) {
            if (_activeBossCycleIdByBossKind[bossKind] == cycleId) {
                _activeBossCycleIdByBossKind[bossKind] = 0;
            }
        }

        emit BossCycleSet(
            cycleId,
            bossKind,
            modifierMask,
            startsAt,
            endsAt,
            active,
            msg.sender
        );
    }

    /*//////////////////////////////////////////////////////////////
                                WRITES
    //////////////////////////////////////////////////////////////*/

    function startRun(
        uint256 dungeonId,
        NexusTypes.DungeonDifficulty difficulty,
        uint8 partySize,
        bytes32 participantHash,
        bytes32 seedHash
    ) external override whenNotPaused nonReentrant returns (uint256 runId) {
        if (activeRunIdOf[msg.sender] != 0) {
            revert ActiveRunExists(activeRunIdOf[msg.sender]);
        }

        DungeonRunEligibilityPreview memory preview =
            _previewRunEligibilityInternal(dungeonId, difficulty, msg.sender, partySize);

        if (!preview.allowed) revert RunNotAllowed(preview.reasonCode);

        NexusTypes.DungeonConfig memory config = _dungeonConfigById[dungeonId];
        DungeonDesignProfile memory design = _designProfileByDungeonId[dungeonId];
        NexusTypes.NexusGlobalState memory globalState = nexusBuildings.getNexusGlobalState();

        runId = _nextRunId++;
        uint32 modifierMask = _resolveRunModifierMask(config, design);

        _runById[runId] = NexusTypes.DungeonRun({
            runId: runId,
            dungeonId: dungeonId,
            dungeonKind: config.dungeonKind,
            difficulty: difficulty,
            state: NexusTypes.DungeonRunState.Active,
            initiator: msg.sender,
            partySize: partySize,
            modifierMask: modifierMask,
            score: 0,
            depthReached: 0,
            bossPhaseReached: 0,
            primaryRewardClass: _primaryRewardAssetClassForRewardClass(
                _defaultRewardClassForConfig(config)
            ),
            participantHash: participantHash,
            seedHash: seedHash,
            startedAt: uint64(block.timestamp),
            endedAt: 0,
            bossDefeated: false,
            extractionSuccess: false
        });

        activeRunIdOf[msg.sender] = runId;
        _runIdsByPlayer[msg.sender].push(runId);
        _runIdsByDungeonId[dungeonId].push(runId);

        DungeonPlayerProfile storage profile = _playerProfileByAccount[msg.sender];
        profile.runsStarted += 1;
        profile.lastRunStartedAt = uint64(block.timestamp);
        profile.lastSeasonId = globalState.seasonId;

        PlayerSeasonProfile storage seasonProfile = _seasonProfileByAccount[globalState.seasonId][msg.sender];
        seasonProfile.runsStarted += 1;
        seasonProfile.lastUpdatedAt = uint64(block.timestamp);

        emit DungeonRunStarted(
            runId,
            dungeonId,
            msg.sender,
            config.dungeonKind,
            difficulty,
            partySize,
            globalState.seasonId,
            modifierMask,
            uint64(block.timestamp)
        );
    }

    function settleRun(
        uint256 runId,
        NexusTypes.DungeonRunState finalState,
        uint32 score,
        uint32 depthReached,
        uint32 bossPhaseReached,
        bool bossDefeated,
        bool extractionSuccess,
        NexusTypes.DungeonRewardClass rewardClass
    ) external override onlyRole(DUNGEON_SETTLER_ROLE) whenNotPaused nonReentrant returns (NexusTypes.NexusRewardPack memory rewardPack) {
        NexusTypes.DungeonRun storage run = _runById[runId];
        if (run.runId == 0) revert RunNotFound();
        if (run.state != NexusTypes.DungeonRunState.Active) revert RunNotActive();
        if (!_isValidSettlementState(finalState)) revert InvalidFinalState();

        NexusTypes.DungeonConfig memory config = _dungeonConfigById[run.dungeonId];
        if (!_dungeonExists[run.dungeonId]) revert DungeonNotFound();

        DungeonDesignProfile memory design = _designProfileByDungeonId[run.dungeonId];
        NexusTypes.NexusGlobalState memory globalState = nexusBuildings.getNexusGlobalState();

        if (
            run.difficulty == NexusTypes.DungeonDifficulty.Endless &&
            design.endlessDepthCap != 0 &&
            depthReached > design.endlessDepthCap
        ) {
            depthReached = design.endlessDepthCap;
        }

        run.state = finalState;
        run.score = score;
        run.depthReached = depthReached;
        run.bossPhaseReached = bossPhaseReached;
        run.bossDefeated = bossDefeated;
        run.extractionSuccess = extractionSuccess || finalState == NexusTypes.DungeonRunState.Extracted;
        run.primaryRewardClass = _primaryRewardAssetClassForRewardClass(rewardClass);
        run.endedAt = uint64(block.timestamp);

        activeRunIdOf[run.initiator] = 0;

        NexusTypes.DungeonRun memory runSnapshot = run;

        rewardPack = _buildRewardPack(config, design, runSnapshot, rewardClass);
        _rewardPackByRunId[runId] = rewardPack;

        uint256 rankingScoreDelta;
        if (design.rankingEnabled) {
            rankingScoreDelta = _computeRankingScore(config, design, runSnapshot);
            _applyRankingAndPlayerState(
                runSnapshot.initiator,
                globalState.seasonId,
                runSnapshot,
                rewardPack,
                rankingScoreDelta
            );
            _updateGlobalLeaderboard(runSnapshot.initiator);
            _updateSeasonLeaderboard(globalState.seasonId, runSnapshot.initiator);
            _updateDungeonLeaderboard(runSnapshot.dungeonId, runSnapshot.initiator);
        } else {
            _applyBasicPlayerState(
                runSnapshot.initiator,
                globalState.seasonId,
                runSnapshot,
                rewardPack
            );
        }

        if (
            runSnapshot.bossDefeated &&
            config.worldBossKind != NexusTypes.WorldBossKind.None &&
            design.bossMemoryHooksEnabled
        ) {
            _recordBossMemoryInternal(
                config.worldBossKind,
                _bossMemoryPagesAwarded(runSnapshot),
                _knowledgeLevelAwarded(runSnapshot),
                runSnapshot.difficulty >= NexusTypes.DungeonDifficulty.Elite,
                design.hiddenPathEnabled,
                config.minArchiveLevel >= 5 || runSnapshot.difficulty >= NexusTypes.DungeonDifficulty.Mythic
            );
        }

        _notifyRewardRouter(
            runId,
            runSnapshot.initiator,
            runSnapshot.dungeonId,
            globalState.seasonId,
            runSnapshot,
            rewardPack,
            rankingScoreDelta,
            design.eventDropEligible
        );

        emit DungeonRunSettled(
            runId,
            runSnapshot.dungeonId,
            runSnapshot.initiator,
            finalState,
            score,
            depthReached,
            bossDefeated,
            runSnapshot.extractionSuccess,
            rewardClass,
            rankingScoreDelta,
            globalState.seasonId,
            uint64(block.timestamp)
        );
    }

    function cancelRun(
        uint256 runId
    ) external override whenNotPaused nonReentrant {
        NexusTypes.DungeonRun storage run = _runById[runId];
        if (run.runId == 0) revert RunNotFound();
        if (run.state != NexusTypes.DungeonRunState.Active) revert RunNotActive();

        bool authorized =
            msg.sender == run.initiator ||
            hasRole(DUNGEON_OPERATOR_ROLE, msg.sender) ||
            hasRole(DUNGEON_ADMIN_ROLE, msg.sender) ||
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender);

        if (!authorized) revert NotRunInitiatorOrOperator();

        run.state = NexusTypes.DungeonRunState.Cancelled;
        run.endedAt = uint64(block.timestamp);

        activeRunIdOf[run.initiator] = 0;

        DungeonPlayerProfile storage profile = _playerProfileByAccount[run.initiator];
        profile.runsCancelled += 1;
        profile.lastRunSettledAt = uint64(block.timestamp);

        uint32 seasonId = nexusBuildings.getNexusGlobalState().seasonId;
        PlayerSeasonProfile storage seasonProfile = _seasonProfileByAccount[seasonId][run.initiator];
        seasonProfile.runsCancelled += 1;
        seasonProfile.lastUpdatedAt = uint64(block.timestamp);

        emit DungeonRunCancelled(
            runId,
            run.dungeonId,
            run.initiator,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    function recordBossMemory(
        NexusTypes.WorldBossKind bossKind,
        uint32 memoryPages,
        uint8 knowledgeLevel,
        bool weaknessUnlocked,
        bool routeBonusUnlocked,
        bool archiveBonusUnlocked
    ) external override onlyRole(DUNGEON_OPERATOR_ROLE) {
        if (!NexusTypes.isValidWorldBoss(bossKind)) revert InvalidBossKind();

        _recordBossMemoryInternal(
            bossKind,
            memoryPages,
            knowledgeLevel,
            weaknessUnlocked,
            routeBonusUnlocked,
            archiveBonusUnlocked
        );
    }

    /*//////////////////////////////////////////////////////////////
                                  READS
    //////////////////////////////////////////////////////////////*/

    function getDungeonConfig(
        uint256 dungeonId
    ) external view override returns (NexusTypes.DungeonConfig memory) {
        return _dungeonConfigById[dungeonId];
    }

    function getDungeonSummary(
        uint256 dungeonId
    ) external view override returns (DungeonSummaryView memory v) {
        if (!_dungeonExists[dungeonId]) revert DungeonNotFound();

        NexusTypes.DungeonConfig memory cfg = _dungeonConfigById[dungeonId];

        v = DungeonSummaryView({
            dungeonId: cfg.dungeonId,
            dungeonKind: cfg.dungeonKind,
            difficulty: cfg.difficulty,
            objectiveType: cfg.objectiveType,
            worldBossKind: cfg.worldBossKind,
            bossCycleId: cfg.bossCycleId,
            modifierMask: _resolveReadModifierMask(cfg, _designProfileByDungeonId[dungeonId]),
            rewardMask: cfg.rewardMask | _designProfileByDungeonId[dungeonId].bonusRewardMask,
            baseScore: cfg.baseScore,
            minCoreLevel: cfg.minCoreLevel,
            minSignalLevel: cfg.minSignalLevel,
            minArchiveLevel: cfg.minArchiveLevel,
            minExchangeLevel: cfg.minExchangeLevel,
            sigilCost: cfg.sigilCost,
            entryWindowSeconds: cfg.entryWindowSeconds,
            soloAllowed: cfg.soloAllowed,
            squadAllowed: cfg.squadAllowed,
            raidAllowed: cfg.raidAllowed,
            endlessSupported: cfg.endlessSupported,
            enabled: cfg.enabled
        });
    }

    function getDungeonDesignProfile(
        uint256 dungeonId
    ) external view returns (DungeonDesignProfile memory) {
        return _designProfileByDungeonId[dungeonId];
    }

    function getRun(
        uint256 runId
    ) external view override returns (NexusTypes.DungeonRun memory) {
        return _runById[runId];
    }

    function getRunRewardPack(
        uint256 runId
    ) external view returns (NexusTypes.NexusRewardPack memory) {
        return _rewardPackByRunId[runId];
    }

    function getBossCycle(
        uint32 cycleId
    ) external view override returns (NexusTypes.DungeonBossCycle memory) {
        return _bossCycleById[cycleId];
    }

    function getActiveBossCycleId(
        NexusTypes.WorldBossKind bossKind
    ) external view returns (uint32) {
        return _activeBossCycleIdByBossKind[bossKind];
    }

    function getBossMemoryState(
        NexusTypes.WorldBossKind bossKind
    ) external view override returns (NexusTypes.BossMemoryState memory) {
        return _bossMemoryByKind[bossKind];
    }

    function previewRunEligibility(
        uint256 dungeonId,
        NexusTypes.DungeonDifficulty difficulty,
        address initiator,
        uint8 partySize
    ) external view override returns (DungeonRunEligibilityPreview memory) {
        return _previewRunEligibilityInternal(dungeonId, difficulty, initiator, partySize);
    }

    function isDungeonTierOpen(
        uint8 dungeonTier
    ) external view override returns (bool) {
        return _dungeonTierOpen[dungeonTier];
    }

    function getGlobalDungeonTier() external view override returns (uint8) {
        return _globalDungeonTier;
    }

    function getNextRunId() external view override returns (uint256) {
        return _nextRunId;
    }

    function getPlayerProfile(
        address player
    ) external view returns (DungeonPlayerProfile memory) {
        return _playerProfileByAccount[player];
    }

    function getPlayerSeasonProfile(
        uint32 seasonId,
        address player
    ) external view returns (PlayerSeasonProfile memory) {
        return _seasonProfileByAccount[seasonId][player];
    }

    function getPlayerRunCount(address player) external view returns (uint256) {
        return _runIdsByPlayer[player].length;
    }

    function getPlayerRunIdAt(address player, uint256 index) external view returns (uint256) {
        return _runIdsByPlayer[player][index];
    }

    function getDungeonRunCount(uint256 dungeonId) external view returns (uint256) {
        return _runIdsByDungeonId[dungeonId].length;
    }

    function getDungeonRunIdAt(uint256 dungeonId, uint256 index) external view returns (uint256) {
        return _runIdsByDungeonId[dungeonId][index];
    }

    function getGlobalLeaderboard() external view returns (LeaderboardRow[] memory rows) {
        rows = _buildLeaderboardRows(_globalLeaderboard, 0, 0);
    }

    function getSeasonLeaderboard(
        uint32 seasonId
    ) external view returns (LeaderboardRow[] memory rows) {
        rows = _buildLeaderboardRows(_seasonLeaderboard[seasonId], seasonId, 1);
    }

    function getDungeonLeaderboard(
        uint256 dungeonId
    ) external view returns (LeaderboardRow[] memory rows) {
        rows = _buildLeaderboardRows(_dungeonLeaderboard[dungeonId], dungeonId, 2);
    }

    function previewRewardPack(
        uint256 dungeonId,
        NexusTypes.DungeonDifficulty difficulty,
        uint32 score,
        uint32 depthReached,
        bool bossDefeated,
        bool extractionSuccess,
        NexusTypes.DungeonRewardClass rewardClass
    ) external view returns (NexusTypes.NexusRewardPack memory pack) {
        if (!_dungeonExists[dungeonId]) revert DungeonNotFound();

        NexusTypes.DungeonConfig memory cfg = _dungeonConfigById[dungeonId];
        DungeonDesignProfile memory design = _designProfileByDungeonId[dungeonId];

        NexusTypes.DungeonRun memory syntheticRun = NexusTypes.DungeonRun({
            runId: 0,
            dungeonId: dungeonId,
            dungeonKind: cfg.dungeonKind,
            difficulty: difficulty,
            state: extractionSuccess
                ? NexusTypes.DungeonRunState.Extracted
                : NexusTypes.DungeonRunState.Completed,
            initiator: address(0),
            partySize: 1,
            modifierMask: _resolveReadModifierMask(cfg, design),
            score: score,
            depthReached: depthReached,
            bossPhaseReached: 0,
            primaryRewardClass: _primaryRewardAssetClassForRewardClass(rewardClass),
            participantHash: bytes32(0),
            seedHash: bytes32(0),
            startedAt: 0,
            endedAt: 0,
            bossDefeated: bossDefeated,
            extractionSuccess: extractionSuccess
        });

        pack = _buildRewardPack(cfg, design, syntheticRun, rewardClass);
    }

    /*//////////////////////////////////////////////////////////////
                               INTERNALS
    //////////////////////////////////////////////////////////////*/

    function _previewRunEligibilityInternal(
        uint256 dungeonId,
        NexusTypes.DungeonDifficulty difficulty,
        address initiator,
        uint8 partySize
    ) internal view returns (DungeonRunEligibilityPreview memory p) {
        if (!_dungeonExists[dungeonId]) {
            p.reasonCode = _rc("DUNGEON_NOT_FOUND");
            return p;
        }

        NexusTypes.DungeonConfig memory cfg = _dungeonConfigById[dungeonId];
        DungeonDesignProfile memory design = _designProfileByDungeonId[dungeonId];
        NexusTypes.NexusGlobalState memory globalState = nexusBuildings.getNexusGlobalState();

        p.dungeonExists = true;
        p.dungeonEnabled = cfg.enabled;
        p.hasCityKey = nexusBuildings.isCityMemberEligible(initiator);
        p.partySizeAllowed = _partySizeAllowed(cfg, partySize);
        p.difficultyAllowed = _difficultyAllowed(cfg, difficulty);
        p.sigilCost = cfg.sigilCost;

        p.coreRequirementMet = _currentNexusLevel(CollectiveBuildingTypes.NexusBuildingKind.NexusCore) >= cfg.minCoreLevel;
        p.signalRequirementMet = _currentNexusLevel(CollectiveBuildingTypes.NexusBuildingKind.NexusSignalSpire) >= cfg.minSignalLevel;
        p.archiveRequirementMet = _currentNexusLevel(CollectiveBuildingTypes.NexusBuildingKind.NexusArchive) >= cfg.minArchiveLevel;
        p.exchangeRequirementMet = _currentNexusLevel(CollectiveBuildingTypes.NexusBuildingKind.NexusExchangeHub) >= cfg.minExchangeLevel;

        p.emergencySealBlocked = globalState.emergencySealActive;
        p.worldBossWindowSatisfied = _worldBossWindowSatisfied(cfg, globalState);

        if (!p.dungeonEnabled) {
            p.reasonCode = _rc("DUNGEON_DISABLED");
            return p;
        }
        if (!p.hasCityKey) {
            p.reasonCode = _rc("NO_CITY_KEY");
            return p;
        }
        if (activeRunIdOf[initiator] != 0) {
            p.reasonCode = _rc("ACTIVE_RUN_EXISTS");
            return p;
        }
        if (!p.partySizeAllowed) {
            p.reasonCode = _rc("PARTY_SIZE_NOT_ALLOWED");
            return p;
        }
        if (!p.difficultyAllowed) {
            p.reasonCode = _rc("DIFFICULTY_NOT_ALLOWED");
            return p;
        }

        uint8 requiredTier = _requiredDungeonTier(cfg, design);
        if (!_dungeonTierOpen[requiredTier] || _globalDungeonTier < requiredTier) {
            p.reasonCode = _rc("DUNGEON_TIER_LOCKED");
            return p;
        }

        if (!p.coreRequirementMet) {
            p.reasonCode = _rc("CORE_LEVEL_REQUIRED");
            return p;
        }
        if (!p.signalRequirementMet) {
            p.reasonCode = _rc("SIGNAL_LEVEL_REQUIRED");
            return p;
        }
        if (!p.archiveRequirementMet) {
            p.reasonCode = _rc("ARCHIVE_LEVEL_REQUIRED");
            return p;
        }
        if (!p.exchangeRequirementMet) {
            p.reasonCode = _rc("EXCHANGE_LEVEL_REQUIRED");
            return p;
        }
        if (p.emergencySealBlocked) {
            p.reasonCode = _rc("EMERGENCY_SEAL_ACTIVE");
            return p;
        }
        if (!p.worldBossWindowSatisfied) {
            p.reasonCode = _rc("WORLD_BOSS_WINDOW_CLOSED");
            return p;
        }
        if (
            difficulty == NexusTypes.DungeonDifficulty.Endless &&
            !cfg.endlessSupported
        ) {
            p.reasonCode = _rc("ENDLESS_NOT_SUPPORTED");
            return p;
        }

        p.allowed = true;
        p.reasonCode = bytes32(0);
    }

    function _partySizeAllowed(
        NexusTypes.DungeonConfig memory cfg,
        uint8 partySize
    ) internal pure returns (bool) {
        if (partySize == 0 || partySize > NexusTypes.MAX_PARTY_SIZE) {
            return false;
        }
        if (partySize == 1) return cfg.soloAllowed;
        if (partySize <= 4) return cfg.squadAllowed;
        return cfg.raidAllowed;
    }

    function _difficultyAllowed(
        NexusTypes.DungeonConfig memory cfg,
        NexusTypes.DungeonDifficulty difficulty
    ) internal pure returns (bool) {
        if (!NexusTypes.isValidDungeonDifficulty(difficulty)) return false;
        return cfg.difficulty == difficulty;
    }

    function _requiredDungeonTier(
        NexusTypes.DungeonConfig memory cfg,
        DungeonDesignProfile memory design
    ) internal pure returns (uint8) {
        if (design.requiredDungeonTier != 0) {
            return design.requiredDungeonTier;
        }

        if (cfg.difficulty == NexusTypes.DungeonDifficulty.Story) return 1;
        if (cfg.difficulty == NexusTypes.DungeonDifficulty.Normal) return 1;
        if (cfg.difficulty == NexusTypes.DungeonDifficulty.Veteran) return 2;
        if (cfg.difficulty == NexusTypes.DungeonDifficulty.Elite) return 3;
        if (cfg.difficulty == NexusTypes.DungeonDifficulty.Mythic) return 4;
        if (cfg.difficulty == NexusTypes.DungeonDifficulty.Endless) return 5;
        return 1;
    }

    function _worldBossWindowSatisfied(
        NexusTypes.DungeonConfig memory cfg,
        NexusTypes.NexusGlobalState memory globalState
    ) internal view returns (bool) {
        if (cfg.worldBossKind == NexusTypes.WorldBossKind.None) return true;
        if (!globalState.worldBossWindowOpen) return false;

        uint32 cycleId = cfg.bossCycleId != 0
            ? cfg.bossCycleId
            : _activeBossCycleIdByBossKind[cfg.worldBossKind];

        if (cycleId == 0) return false;

        NexusTypes.DungeonBossCycle memory cycle = _bossCycleById[cycleId];
        if (!cycle.active) return false;
        if (cycle.bossKind != cfg.worldBossKind) return false;

        return block.timestamp >= cycle.startsAt && block.timestamp <= cycle.endsAt;
    }

    function _currentNexusLevel(
        CollectiveBuildingTypes.NexusBuildingKind kind
    ) internal view returns (uint8) {
        uint256 tokenId = nexusBuildings.getTokenIdForKind(kind);
        if (tokenId == 0) return 0;

        CollectiveBuildingTypes.CollectiveIdentity memory id_ =
            collectiveNFT.getCollectiveIdentity(tokenId);

        return id_.level;
    }

    function _resolveRunModifierMask(
        NexusTypes.DungeonConfig memory cfg,
        DungeonDesignProfile memory design
    ) internal view returns (uint32) {
        uint32 mask = cfg.modifierMask | design.affixMask;

        if (cfg.worldBossKind != NexusTypes.WorldBossKind.None) {
            uint32 cycleId = cfg.bossCycleId != 0
                ? cfg.bossCycleId
                : _activeBossCycleIdByBossKind[cfg.worldBossKind];

            if (cycleId != 0) {
                NexusTypes.DungeonBossCycle memory cycle = _bossCycleById[cycleId];
                if (cycle.active && block.timestamp >= cycle.startsAt && block.timestamp <= cycle.endsAt) {
                    mask |= cycle.modifierMask;
                }
            }
        }

        return mask;
    }

    function _resolveReadModifierMask(
        NexusTypes.DungeonConfig memory cfg,
        DungeonDesignProfile memory design
    ) internal view returns (uint32) {
        uint32 mask = cfg.modifierMask | design.affixMask;

        if (cfg.worldBossKind != NexusTypes.WorldBossKind.None) {
            uint32 cycleId = cfg.bossCycleId != 0
                ? cfg.bossCycleId
                : _activeBossCycleIdByBossKind[cfg.worldBossKind];

            if (cycleId != 0 && _bossCycleById[cycleId].active) {
                mask |= _bossCycleById[cycleId].modifierMask;
            }
        }

        return mask;
    }

    function _isValidSettlementState(
        NexusTypes.DungeonRunState finalState
    ) internal pure returns (bool) {
        return
            finalState == NexusTypes.DungeonRunState.Completed ||
            finalState == NexusTypes.DungeonRunState.Failed ||
            finalState == NexusTypes.DungeonRunState.Extracted ||
            finalState == NexusTypes.DungeonRunState.TimedOut;
    }

    function _defaultRewardClassForConfig(
        NexusTypes.DungeonConfig memory cfg
    ) internal pure returns (NexusTypes.DungeonRewardClass) {
        if (cfg.objectiveType == NexusTypes.DungeonObjectiveType.BossHunt) {
            return NexusTypes.DungeonRewardClass.RelicShards;
        }
        if (cfg.objectiveType == NexusTypes.DungeonObjectiveType.Extraction) {
            return NexusTypes.DungeonRewardClass.RouteCoordinates;
        }
        if (cfg.objectiveType == NexusTypes.DungeonObjectiveType.Rescue) {
            return NexusTypes.DungeonRewardClass.PrestigeHistory;
        }
        if (cfg.objectiveType == NexusTypes.DungeonObjectiveType.Escort) {
            return NexusTypes.DungeonRewardClass.EventPermits;
        }
        return NexusTypes.DungeonRewardClass.Mixed;
    }

    function _primaryRewardAssetClassForRewardClass(
        NexusTypes.DungeonRewardClass rewardClass
    ) internal pure returns (NexusTypes.RewardAssetClass) {
        if (rewardClass == NexusTypes.DungeonRewardClass.BlueprintFragments) {
            return NexusTypes.RewardAssetClass.Blueprint;
        }
        if (rewardClass == NexusTypes.DungeonRewardClass.RelicShards) {
            return NexusTypes.RewardAssetClass.Relic;
        }
        if (
            rewardClass == NexusTypes.DungeonRewardClass.CodexKeys ||
            rewardClass == NexusTypes.DungeonRewardClass.DungeonSigils
        ) {
            return NexusTypes.RewardAssetClass.Key;
        }
        if (rewardClass == NexusTypes.DungeonRewardClass.RouteCoordinates) {
            return NexusTypes.RewardAssetClass.Chronicle;
        }
        if (rewardClass == NexusTypes.DungeonRewardClass.ArchiveSeals) {
            return NexusTypes.RewardAssetClass.Chronicle;
        }
        if (rewardClass == NexusTypes.DungeonRewardClass.EventPermits) {
            return NexusTypes.RewardAssetClass.Permit;
        }
        if (rewardClass == NexusTypes.DungeonRewardClass.CosmeticUnlock) {
            return NexusTypes.RewardAssetClass.Cosmetic;
        }
        if (rewardClass == NexusTypes.DungeonRewardClass.PrestigeHistory) {
            return NexusTypes.RewardAssetClass.Chronicle;
        }
        return NexusTypes.RewardAssetClass.ResourceBundle;
    }

    function _buildRewardPack(
        NexusTypes.DungeonConfig memory cfg,
        DungeonDesignProfile memory design,
        NexusTypes.DungeonRun memory runData,
        NexusTypes.DungeonRewardClass rewardClass
    ) internal pure returns (NexusTypes.NexusRewardPack memory pack) {
        pack.rewardClass = rewardClass;

        bool successState =
            runData.state == NexusTypes.DungeonRunState.Completed ||
            runData.state == NexusTypes.DungeonRunState.Extracted;

        if (!successState) {
            pack.historyScore = _u32(2 + runData.depthReached);
            if (runData.bossDefeated) {
                pack.historyScore += 10;
            }
            return pack;
        }

        uint256 commonUnits = _commonResourceUnits(runData.score, runData.depthReached, runData.difficulty);
        uint256 rareUnits = _rareResourceUnits(runData.score, runData.bossDefeated, runData.extractionSuccess, runData.difficulty);

        // conservative common bundle
        pack.resourceAmounts[0] = commonUnits;
        pack.resourceAmounts[1] = commonUnits / 2;
        pack.resourceAmounts[2] = commonUnits / 3;

        // conservative late-game rare bundle
        if (runData.difficulty >= NexusTypes.DungeonDifficulty.Elite) {
            pack.resourceAmounts[6] = rareUnits;
        }
        if (runData.difficulty >= NexusTypes.DungeonDifficulty.Mythic && runData.bossDefeated) {
            pack.resourceAmounts[7] = rareUnits == 0 ? 1 : rareUnits;
        }
        if (runData.difficulty == NexusTypes.DungeonDifficulty.Endless && runData.extractionSuccess) {
            pack.resourceAmounts[8] = 1;
            if (runData.depthReached >= 25) {
                pack.resourceAmounts[9] = 1;
            }
        }

        if (rewardClass == NexusTypes.DungeonRewardClass.BlueprintFragments) {
            pack.blueprintFragments = _u32(2 + commonUnits + _difficultyFlatBonus(runData.difficulty));
        } else if (rewardClass == NexusTypes.DungeonRewardClass.RelicShards) {
            pack.relicShards = _u32(1 + rareUnits + (runData.bossDefeated ? 2 : 0));
        } else if (rewardClass == NexusTypes.DungeonRewardClass.CodexKeys) {
            pack.codexKeys = _u32(1 + _difficultyFlatBonus(runData.difficulty) / 2);
        } else if (rewardClass == NexusTypes.DungeonRewardClass.DungeonSigils) {
            pack.dungeonSigils = _u32(1 + commonUnits / 2 + (runData.extractionSuccess ? 1 : 0));
        } else if (rewardClass == NexusTypes.DungeonRewardClass.RouteCoordinates) {
            pack.routeCoordinates = _u32(1 + (design.hiddenPathEnabled ? 1 : 0) + (runData.extractionSuccess ? 1 : 0));
        } else if (rewardClass == NexusTypes.DungeonRewardClass.ArchiveSeals) {
            pack.archiveSeals = _u32(1 + _difficultyFlatBonus(runData.difficulty));
        } else if (rewardClass == NexusTypes.DungeonRewardClass.EventPermits) {
            pack.eventPermits = _u32(1 + (runData.bossDefeated ? 1 : 0));
            pack.permitQuota = _u32(1 + (runData.difficulty >= NexusTypes.DungeonDifficulty.Mythic ? 1 : 0));
        } else if (rewardClass == NexusTypes.DungeonRewardClass.CosmeticUnlock) {
            pack.cosmeticDropId = keccak256(
                abi.encodePacked(
                    "NEXUS_DUNGEON_COSMETIC",
                    cfg.dungeonId,
                    uint8(runData.difficulty),
                    runData.score,
                    runData.depthReached,
                    runData.bossDefeated,
                    runData.extractionSuccess
                )
            );
        } else if (rewardClass == NexusTypes.DungeonRewardClass.PrestigeHistory) {
            pack.prestigeScore = _u32(10 + runData.score / 40);
            pack.historyScore = _u32(15 + runData.depthReached * 3 + (runData.bossDefeated ? 20 : 0));
        } else {
            // Mixed
            pack.blueprintFragments = _u32(1 + commonUnits / 2);
            pack.relicShards = _u32(runData.bossDefeated ? 2 : 1);
            pack.dungeonSigils = _u32(runData.extractionSuccess ? 2 : 1);
            pack.historyScore = _u32(8 + runData.depthReached * 2);
            pack.prestigeScore = _u32(5 + runData.score / 80);
        }

        if (cfg.worldBossKind != NexusTypes.WorldBossKind.None && runData.bossDefeated) {
            pack.eventPermits += 1;
            pack.relicShards += 1;
            pack.historyScore += 20;
            pack.provenanceDropId = keccak256(
                abi.encodePacked(
                    "NEXUS_WORLD_BOSS_PROVENANCE",
                    uint8(cfg.worldBossKind),
                    cfg.dungeonId,
                    uint8(runData.difficulty),
                    runData.score,
                    runData.depthReached
                )
            );
        }

        if (design.hiddenPathEnabled && runData.extractionSuccess && runData.depthReached >= 3) {
            pack.routeCoordinates += 1;
        }

        if (runData.difficulty == NexusTypes.DungeonDifficulty.Endless && runData.depthReached >= 10) {
            pack.blueprintFragments += _u32(runData.depthReached / 5);
        }

        if (design.bonusRewardMask != 0 && runData.bossDefeated) {
            pack.archiveSeals += 1;
        }
    }

    function _computeRankingScore(
        NexusTypes.DungeonConfig memory cfg,
        DungeonDesignProfile memory design,
        NexusTypes.DungeonRun memory runData
    ) internal pure returns (uint256 ranking) {
        ranking = runData.score;
        ranking += uint256(runData.depthReached) * 20;
        ranking += uint256(runData.bossPhaseReached) * 35;

        if (runData.bossDefeated) {
            ranking += 300;
            ranking += (uint256(runData.score) * (1500 + design.bossScoreBps)) / MAX_BPS;
        }

        if (runData.extractionSuccess) {
            ranking += 150;
            ranking += (uint256(runData.score) * (1000 + design.extractionScoreBps)) / MAX_BPS;
        }

        if (design.splitPathCount != 0) {
            ranking += uint256(design.splitPathCount) * 10;
        }

        ranking += (uint256(runData.depthReached) * design.depthScoreBps) / 100;

        uint256 difficultyMultiplier = 10_000;
        if (runData.difficulty == NexusTypes.DungeonDifficulty.Veteran) {
            difficultyMultiplier = 12_500;
        } else if (runData.difficulty == NexusTypes.DungeonDifficulty.Elite) {
            difficultyMultiplier = 15_000;
        } else if (runData.difficulty == NexusTypes.DungeonDifficulty.Mythic) {
            difficultyMultiplier = 20_000;
        } else if (runData.difficulty == NexusTypes.DungeonDifficulty.Endless) {
            difficultyMultiplier = 25_000;
        }

        ranking = (ranking * difficultyMultiplier) / 10_000;

        if (cfg.worldBossKind != NexusTypes.WorldBossKind.None && runData.bossDefeated) {
            ranking += 500;
        }

        if (design.seasonalScoreBps != 0) {
            ranking += (ranking * design.seasonalScoreBps) / MAX_BPS;
        }
    }

    function _applyBasicPlayerState(
        address player,
        uint32 seasonId,
        NexusTypes.DungeonRun memory runData,
        NexusTypes.NexusRewardPack memory rewardPack
    ) internal {
        DungeonPlayerProfile storage profile = _playerProfileByAccount[player];
        PlayerSeasonProfile storage seasonProfile = _seasonProfileByAccount[seasonId][player];

        _applyCompletionState(profile, seasonProfile, runData);
        _applyScoreState(profile, seasonProfile, runData, rewardPack);

        profile.lastRunSettledAt = uint64(block.timestamp);
        profile.lastSeasonId = seasonId;
        seasonProfile.lastUpdatedAt = uint64(block.timestamp);

        emit PlayerRankingUpdated(
            player,
            seasonId,
            globalRankingScoreOf[player],
            seasonRankingScoreOf[seasonId][player],
            profile.bossesDefeated,
            uint64(block.timestamp)
        );
    }

    function _applyRankingAndPlayerState(
        address player,
        uint32 seasonId,
        NexusTypes.DungeonRun memory runData,
        NexusTypes.NexusRewardPack memory rewardPack,
        uint256 rankingScoreDelta
    ) internal {
        DungeonPlayerProfile storage profile = _playerProfileByAccount[player];
        PlayerSeasonProfile storage seasonProfile = _seasonProfileByAccount[seasonId][player];

        _applyCompletionState(profile, seasonProfile, runData);
        _applyScoreState(profile, seasonProfile, runData, rewardPack);

        globalRankingScoreOf[player] += rankingScoreDelta;
        seasonRankingScoreOf[seasonId][player] += rankingScoreDelta;
        dungeonRankingScoreOf[runData.dungeonId][player] += rankingScoreDelta;

        profile.lastRunSettledAt = uint64(block.timestamp);
        profile.lastSeasonId = seasonId;
        seasonProfile.lastUpdatedAt = uint64(block.timestamp);

        emit PlayerRankingUpdated(
            player,
            seasonId,
            globalRankingScoreOf[player],
            seasonRankingScoreOf[seasonId][player],
            profile.bossesDefeated,
            uint64(block.timestamp)
        );
    }

    function _applyCompletionState(
        DungeonPlayerProfile storage profile,
        PlayerSeasonProfile storage seasonProfile,
        NexusTypes.DungeonRun memory runData
    ) internal {
        if (
            runData.state == NexusTypes.DungeonRunState.Completed ||
            runData.state == NexusTypes.DungeonRunState.Extracted
        ) {
            profile.runsCompleted += 1;
            seasonProfile.runsCompleted += 1;
        } else if (
            runData.state == NexusTypes.DungeonRunState.Failed ||
            runData.state == NexusTypes.DungeonRunState.TimedOut
        ) {
            profile.runsFailed += 1;
            seasonProfile.runsFailed += 1;
        } else if (runData.state == NexusTypes.DungeonRunState.Cancelled) {
            profile.runsCancelled += 1;
            seasonProfile.runsCancelled += 1;
        }

        if (runData.extractionSuccess) {
            profile.extractions += 1;
        }

        if (runData.bossDefeated) {
            profile.bossesDefeated += 1;
            seasonProfile.bossesDefeated += 1;
        }
    }

    function _applyScoreState(
        DungeonPlayerProfile storage profile,
        PlayerSeasonProfile storage seasonProfile,
        NexusTypes.DungeonRun memory runData,
        NexusTypes.NexusRewardPack memory rewardPack
    ) internal {
        profile.totalScore += _u32(runData.score);
        profile.totalDepth += _u32(runData.depthReached);
        if (runData.score > profile.bestScore) profile.bestScore = _u32(runData.score);
        if (runData.depthReached > profile.bestDepth) profile.bestDepth = _u32(runData.depthReached);

        if (runData.score > seasonProfile.bestScore) seasonProfile.bestScore = _u32(runData.score);
        if (runData.depthReached > seasonProfile.bestDepth) seasonProfile.bestDepth = _u32(runData.depthReached);

        uint32 eventPointsDelta = _eventPointsFromRewardPack(rewardPack, runData);
        profile.totalEventPoints += eventPointsDelta;
        seasonProfile.totalEventPoints += eventPointsDelta;
    }

    function _recordBossMemoryInternal(
        NexusTypes.WorldBossKind bossKind,
        uint32 memoryPages,
        uint8 knowledgeLevel,
        bool weaknessUnlocked,
        bool routeBonusUnlocked,
        bool archiveBonusUnlocked
    ) internal {
        NexusTypes.BossMemoryState storage memoryState = _bossMemoryByKind[bossKind];

        memoryState.bossKind = bossKind;
        memoryState.memoryPages += memoryPages;
        if (knowledgeLevel > memoryState.knowledgeLevel) {
            memoryState.knowledgeLevel = knowledgeLevel;
        }
        if (weaknessUnlocked) memoryState.weaknessUnlocked = true;
        if (routeBonusUnlocked) memoryState.routeBonusUnlocked = true;
        if (archiveBonusUnlocked) memoryState.archiveBonusUnlocked = true;
        memoryState.lastUpdatedAt = uint64(block.timestamp);

        NexusTypes.BossMemoryState memory snapshot = memoryState;

        emit BossMemoryRecorded(
            bossKind,
            snapshot.memoryPages,
            snapshot.knowledgeLevel,
            snapshot.weaknessUnlocked,
            snapshot.routeBonusUnlocked,
            snapshot.archiveBonusUnlocked,
            msg.sender,
            uint64(block.timestamp)
        );

        INexusRewardRouterHook router = rewardRouter;
        if (address(router) != address(0)) {
            try router.onBossMemoryUpdated(bossKind, snapshot) {
            } catch (bytes memory reason) {
                emit RewardRouterNotifyFailed(
                    0,
                    INexusRewardRouterHook.onBossMemoryUpdated.selector,
                    reason
                );
            }
        }
    }

    function _notifyRewardRouter(
        uint256 runId,
        address initiator,
        uint256 dungeonId,
        uint32 seasonId,
        NexusTypes.DungeonRun memory runData,
        NexusTypes.NexusRewardPack memory rewardPack,
        uint256 rankingScoreDelta,
        bool eventDropEligible
    ) internal {
        INexusRewardRouterHook router = rewardRouter;
        if (address(router) == address(0)) return;

        try router.onDungeonRunSettled(
            runId,
            initiator,
            dungeonId,
            seasonId,
            runData,
            rewardPack,
            rankingScoreDelta,
            eventDropEligible
        ) {
        } catch (bytes memory reason) {
            emit RewardRouterNotifyFailed(
                runId,
                INexusRewardRouterHook.onDungeonRunSettled.selector,
                reason
            );
        }

        try router.onLeaderboardScoreUpdated(
            initiator,
            seasonId,
            globalRankingScoreOf[initiator],
            seasonRankingScoreOf[seasonId][initiator],
            _playerProfileByAccount[initiator].bossesDefeated
        ) {
        } catch (bytes memory reason) {
            emit RewardRouterNotifyFailed(
                runId,
                INexusRewardRouterHook.onLeaderboardScoreUpdated.selector,
                reason
            );
        }
    }

    function _updateGlobalLeaderboard(address account) internal {
        _updateLeaderboardArray(_globalLeaderboard, account, globalRankingScoreOf[account], 0, 0, GLOBAL_LEADERBOARD_SIZE);
    }

    function _updateSeasonLeaderboard(uint32 seasonId, address account) internal {
        _updateLeaderboardArray(_seasonLeaderboard[seasonId], account, seasonRankingScoreOf[seasonId][account], seasonId, 1, SEASON_LEADERBOARD_SIZE);
    }

    function _updateDungeonLeaderboard(uint256 dungeonId, address account) internal {
        _updateLeaderboardArray(_dungeonLeaderboard[dungeonId], account, dungeonRankingScoreOf[dungeonId][account], dungeonId, 2, DUNGEON_LEADERBOARD_SIZE);
    }

    function _updateLeaderboardArray(
        address[] storage board,
        address account,
        uint256 score,
        uint256 key,
        uint8 scope,
        uint256 maxSize
    ) internal {
        if (score == 0) return;

        address[] memory scratch = new address[](board.length + 1);
        uint256 scratchCount;

        for (uint256 i = 0; i < board.length; i++) {
            if (board[i] != account) {
                scratch[scratchCount] = board[i];
                scratchCount += 1;
            }
        }

        address[] memory rebuilt = new address[](maxSize);
        uint256 rebuiltCount;
        bool inserted;

        for (uint256 i = 0; i < scratchCount; i++) {
            if (
                !inserted &&
                score > _leaderboardComparableScore(scope, key, scratch[i])
            ) {
                rebuilt[rebuiltCount] = account;
                rebuiltCount += 1;
                inserted = true;

                if (rebuiltCount == maxSize) break;
            }

            if (rebuiltCount < maxSize) {
                rebuilt[rebuiltCount] = scratch[i];
                rebuiltCount += 1;
            }
        }

        if (!inserted && rebuiltCount < maxSize) {
            rebuilt[rebuiltCount] = account;
            rebuiltCount += 1;
        }

        delete board;
        for (uint256 i = 0; i < rebuiltCount; i++) {
            board.push(rebuilt[i]);
        }
    }

    function _leaderboardComparableScore(
        uint8 scope,
        uint256 key,
        address account
    ) internal view returns (uint256) {
        if (scope == 0) {
            return globalRankingScoreOf[account];
        }
        if (scope == 1) {
            return seasonRankingScoreOf[uint32(key)][account];
        }
        return dungeonRankingScoreOf[key][account];
    }

    function _buildLeaderboardRows(
        address[] storage board,
        uint256 key,
        uint8 scope
    ) internal view returns (LeaderboardRow[] memory rows) {
        rows = new LeaderboardRow[](board.length);

        for (uint256 i = 0; i < board.length; i++) {
            address account = board[i];
            DungeonPlayerProfile memory profile = _playerProfileByAccount[account];

            uint256 rankingScore;
            uint32 seasonId;

            if (scope == 0) {
                rankingScore = globalRankingScoreOf[account];
                seasonId = profile.lastSeasonId;
            } else if (scope == 1) {
                rankingScore = seasonRankingScoreOf[uint32(key)][account];
                seasonId = uint32(key);
            } else {
                rankingScore = dungeonRankingScoreOf[key][account];
                seasonId = profile.lastSeasonId;
            }

            rows[i] = LeaderboardRow({
                account: account,
                rankingScore: rankingScore,
                bestScore: profile.bestScore,
                bestDepth: profile.bestDepth,
                bossesDefeated: profile.bossesDefeated,
                seasonId: seasonId
            });
        }
    }

    function _recomputeHighestOpenTier() internal view returns (uint8 highest) {
        for (uint8 tier = CollectiveBuildingTypes.MAX_COLLECTIVE_LEVEL; tier >= 1; tier--) {
            if (_dungeonTierOpen[tier]) {
                return tier;
            }
            if (tier == 1) break;
        }
        return 0;
    }

    function _commonResourceUnits(
        uint32 score,
        uint32 depthReached,
        NexusTypes.DungeonDifficulty difficulty
    ) internal pure returns (uint256) {
        uint256 units = 1 + score / 250 + depthReached / 3;

        if (difficulty == NexusTypes.DungeonDifficulty.Veteran) units += 1;
        else if (difficulty == NexusTypes.DungeonDifficulty.Elite) units += 2;
        else if (difficulty == NexusTypes.DungeonDifficulty.Mythic) units += 3;
        else if (difficulty == NexusTypes.DungeonDifficulty.Endless) units += 4;

        return units;
    }

    function _rareResourceUnits(
        uint32 score,
        bool bossDefeated,
        bool extractionSuccess,
        NexusTypes.DungeonDifficulty difficulty
    ) internal pure returns (uint256) {
        uint256 units;

        if (difficulty >= NexusTypes.DungeonDifficulty.Elite) {
            units = 1 + score / 1000;
        }

        if (bossDefeated) units += 1;
        if (extractionSuccess) units += 1;

        return units;
    }

    function _difficultyFlatBonus(
        NexusTypes.DungeonDifficulty difficulty
    ) internal pure returns (uint32) {
        if (difficulty == NexusTypes.DungeonDifficulty.Veteran) return 1;
        if (difficulty == NexusTypes.DungeonDifficulty.Elite) return 2;
        if (difficulty == NexusTypes.DungeonDifficulty.Mythic) return 3;
        if (difficulty == NexusTypes.DungeonDifficulty.Endless) return 4;
        return 0;
    }

    function _bossMemoryPagesAwarded(
        NexusTypes.DungeonRun memory runData
    ) internal pure returns (uint32) {
        uint32 pages = 1;
        if (runData.difficulty >= NexusTypes.DungeonDifficulty.Elite) pages += 1;
        if (runData.difficulty >= NexusTypes.DungeonDifficulty.Mythic) pages += 1;
        if (runData.depthReached >= 10) pages += 1;
        return pages;
    }

    function _knowledgeLevelAwarded(
        NexusTypes.DungeonRun memory runData
    ) internal pure returns (uint8) {
        if (runData.difficulty == NexusTypes.DungeonDifficulty.Endless) return 5;
        if (runData.difficulty == NexusTypes.DungeonDifficulty.Mythic) return 4;
        if (runData.difficulty == NexusTypes.DungeonDifficulty.Elite) return 3;
        if (runData.difficulty == NexusTypes.DungeonDifficulty.Veteran) return 2;
        return 1;
    }

    function _eventPointsFromRewardPack(
        NexusTypes.NexusRewardPack memory rewardPack,
        NexusTypes.DungeonRun memory runData
    ) internal pure returns (uint32) {
        uint256 points =
            rewardPack.eventPermits * 100 +
            rewardPack.blueprintFragments * 5 +
            rewardPack.relicShards * 10 +
            rewardPack.archiveSeals * 15 +
            rewardPack.routeCoordinates * 20 +
            rewardPack.codexKeys * 25;

        if (runData.bossDefeated) points += 50;
        if (runData.extractionSuccess) points += 25;

        return _u32(points);
    }

    function _u32(uint256 value) internal pure returns (uint32) {
        if (value > type(uint32).max) {
            return type(uint32).max;
        }
        return uint32(value);
    }

    function _rc(string memory code) internal pure returns (bytes32) {
        return keccak256(bytes(code));
    }

    /*//////////////////////////////////////////////////////////////
                           INTERFACE SUPPORT
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(AccessControl) returns (bool) {
        return
            interfaceId == type(INexusDungeon).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}