/* FILE: contracts/city/contracts/buildings/NexusPortal.sol */
/* TYPE: nexus portal / seasonal routes / hidden routes / world boss gateways — NOT NFT, NOT PersonalBuildings */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

import "../libraries/CollectiveBuildingTypes.sol";
import "../libraries/NexusTypes.sol";

/*//////////////////////////////////////////////////////////////
                        EXTERNAL INTERFACES
//////////////////////////////////////////////////////////////*/

interface INexusBuildingsPortalRead {
    function getTokenIdForKind(
        CollectiveBuildingTypes.NexusBuildingKind kind
    ) external view returns (uint256);

    function kindIsActive(
        CollectiveBuildingTypes.NexusBuildingKind kind
    ) external view returns (bool);

    function getNexusGlobalState()
        external
        view
        returns (NexusTypes.NexusGlobalState memory);

    function syncNexusMetrics(
        uint32 activeRouteCount,
        uint32 hiddenRouteCount,
        uint32 activeDungeonCount,
        uint32 cityStabilityBps,
        uint32 cityInstabilityBps
    ) external;
}

interface ICollectiveBuildingNFTV1PortalRead {
    function getCollectiveIdentity(
        uint256 tokenId
    ) external view returns (CollectiveBuildingTypes.CollectiveIdentity memory);

    function getCollectiveState(
        uint256 tokenId
    ) external view returns (CollectiveBuildingTypes.CollectiveBuildingState);
}

interface ICityRegistryPortalRead {
    function hasCityKeyOf(address user) external view returns (bool);
}

/*//////////////////////////////////////////////////////////////
                           NEXUS PORTAL
//////////////////////////////////////////////////////////////*/

contract NexusPortal is AccessControl, Pausable {
    /*//////////////////////////////////////////////////////////////
                                 ROLES
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant PORTAL_ADMIN_ROLE = keccak256("PORTAL_ADMIN_ROLE");
    bytes32 public constant PORTAL_OPERATOR_ROLE = keccak256("PORTAL_OPERATOR_ROLE");
    bytes32 public constant ROUTE_SETTER_ROLE = keccak256("ROUTE_SETTER_ROLE");
    bytes32 public constant WORLD_BOSS_ROLE = keccak256("WORLD_BOSS_ROLE");
    bytes32 public constant EXPEDITION_ADMIN_ROLE = keccak256("EXPEDITION_ADMIN_ROLE");
    bytes32 public constant PORTAL_SYSTEM_ROLE = keccak256("PORTAL_SYSTEM_ROLE");

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error InvalidNexusBuildings();
    error InvalidCollectiveNFT();
    error InvalidCityRegistry();

    error InvalidZoneKind();
    error InvalidWorldBoss();
    error InvalidExpeditionClass();
    error InvalidRouteState();
    error InvalidUnlockClass();
    error InvalidWindow();
    error InvalidBps();
    error InvalidRouteArrayLength();
    error InvalidTier();

    error RouteNotFound();
    error ExpeditionConfigNotFound();
    error BossWindowNotFound();
    error SeasonRotationNotFound();

    error RouteRequirementsNotMet(bytes32 reasonCode);
    error HiddenRouteLocked();
    error HiddenRouteAlreadyUnlocked();
    error NoStateChange();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event NexusBuildingsSet(address indexed nexusBuildings, address indexed executor);
    event CollectiveNFTSet(address indexed collectiveNFT, address indexed executor);
    event CityRegistrySet(address indexed cityRegistry, address indexed executor);

    event PortalRouteCreated(
        uint256 indexed routeId,
        NexusTypes.PortalZoneKind indexed zoneKind,
        NexusTypes.RouteUnlockClass indexed unlockClass,
        address executor
    );

    event PortalRouteUpdated(
        uint256 indexed routeId,
        NexusTypes.PortalZoneKind indexed zoneKind,
        NexusTypes.PortalRouteState state,
        address executor
    );

    event PortalRouteStateSet(
        uint256 indexed routeId,
        NexusTypes.PortalRouteState oldState,
        NexusTypes.PortalRouteState newState,
        address indexed executor
    );

    event HiddenRouteUnlocked(
        uint256 indexed routeId,
        bytes32 indexed discoveryHash,
        address indexed discoveredBy,
        uint64 discoveredAt
    );

    event SeasonalRouteRotationSet(
        uint32 indexed seasonId,
        uint8 activeRouteCount,
        uint64 startsAt,
        uint64 endsAt,
        address indexed executor
    );

    event SeasonalRotationApplied(
        uint32 indexed seasonId,
        address indexed executor,
        uint64 appliedAt
    );

    event WorldBossWindowCreated(
        uint256 indexed windowId,
        uint256 indexed routeId,
        NexusTypes.WorldBossKind indexed bossKind,
        uint64 opensAt,
        uint64 closesAt
    );

    event WorldBossWindowStateSet(
        uint256 indexed windowId,
        bool active,
        address indexed executor
    );

    event WorldBossWindowDefeatedSet(
        uint256 indexed windowId,
        bool defeated,
        address indexed executor
    );

    event ExpeditionConfigCreated(
        uint256 indexed configId,
        NexusTypes.ExpeditionClass indexed expeditionClass,
        NexusTypes.PortalZoneKind indexed zoneKind,
        address executor
    );

    event ExpeditionConfigEnabledSet(
        uint256 indexed configId,
        bool enabled,
        address indexed executor
    );

    event PortalMetricsSynced(
        uint32 activeRouteCount,
        uint32 hiddenRouteCount,
        uint32 cityStabilityBps,
        uint32 cityInstabilityBps,
        address indexed executor,
        uint64 syncedAt
    );

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    INexusBuildingsPortalRead public nexusBuildings;
    ICollectiveBuildingNFTV1PortalRead public collectiveNFT;
    ICityRegistryPortalRead public cityRegistry;

    uint256 private _nextRouteId = 1;
    uint256 private _nextBossWindowId = 1;
    uint256 private _nextExpeditionConfigId = 1;

    uint256[] private _allRouteIds;
    uint256[] private _allBossWindowIds;
    uint256[] private _allExpeditionConfigIds;

    mapping(uint256 => NexusTypes.PortalRoute) private _routeById;
    mapping(uint256 => bool) private _routeExists;

    mapping(uint256 => NexusTypes.HiddenRouteRecord) private _hiddenRouteRecordByRouteId;

    mapping(uint32 => NexusTypes.SeasonalRouteRotation) private _seasonalRotationBySeasonId;
    mapping(uint32 => bool) private _seasonalRotationExists;

    mapping(uint256 => NexusTypes.WorldBossWindow) private _bossWindowById;
    mapping(uint256 => bool) private _bossWindowExists;
    mapping(uint256 => uint256) public activeBossWindowIdByRouteId;

    mapping(uint256 => NexusTypes.ExpeditionConfig) private _expeditionConfigById;
    mapping(uint256 => bool) private _expeditionConfigExists;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address nexusBuildings_,
        address collectiveNFT_,
        address cityRegistry_,
        address admin_
    ) {
        if (admin_ == address(0)) revert ZeroAddress();
        if (nexusBuildings_ == address(0)) revert ZeroAddress();
        if (collectiveNFT_ == address(0)) revert ZeroAddress();
        if (cityRegistry_ == address(0)) revert ZeroAddress();

        if (nexusBuildings_.code.length == 0) revert InvalidNexusBuildings();
        if (collectiveNFT_.code.length == 0) revert InvalidCollectiveNFT();
        if (cityRegistry_.code.length == 0) revert InvalidCityRegistry();

        nexusBuildings = INexusBuildingsPortalRead(nexusBuildings_);
        collectiveNFT = ICollectiveBuildingNFTV1PortalRead(collectiveNFT_);
        cityRegistry = ICityRegistryPortalRead(cityRegistry_);

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(PORTAL_ADMIN_ROLE, admin_);
        _grantRole(PORTAL_OPERATOR_ROLE, admin_);
        _grantRole(ROUTE_SETTER_ROLE, admin_);
        _grantRole(WORLD_BOSS_ROLE, admin_);
        _grantRole(EXPEDITION_ADMIN_ROLE, admin_);
        _grantRole(PORTAL_SYSTEM_ROLE, admin_);
    }

    /*//////////////////////////////////////////////////////////////
                                  ADMIN
    //////////////////////////////////////////////////////////////*/

    function pause() external onlyRole(PORTAL_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PORTAL_ADMIN_ROLE) {
        _unpause();
    }

    function setNexusBuildings(address nexusBuildings_) external onlyRole(PORTAL_ADMIN_ROLE) {
        if (nexusBuildings_ == address(0)) revert ZeroAddress();
        if (nexusBuildings_.code.length == 0) revert InvalidNexusBuildings();

        nexusBuildings = INexusBuildingsPortalRead(nexusBuildings_);
        emit NexusBuildingsSet(nexusBuildings_, msg.sender);
    }

    function setCollectiveNFT(address collectiveNFT_) external onlyRole(PORTAL_ADMIN_ROLE) {
        if (collectiveNFT_ == address(0)) revert ZeroAddress();
        if (collectiveNFT_.code.length == 0) revert InvalidCollectiveNFT();

        collectiveNFT = ICollectiveBuildingNFTV1PortalRead(collectiveNFT_);
        emit CollectiveNFTSet(collectiveNFT_, msg.sender);
    }

    function setCityRegistry(address cityRegistry_) external onlyRole(PORTAL_ADMIN_ROLE) {
        if (cityRegistry_ == address(0)) revert ZeroAddress();
        if (cityRegistry_.code.length == 0) revert InvalidCityRegistry();

        cityRegistry = ICityRegistryPortalRead(cityRegistry_);
        emit CityRegistrySet(cityRegistry_, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                              ROUTE WRITES
    //////////////////////////////////////////////////////////////*/

    function createPortalRoute(
        NexusTypes.PortalZoneKind zoneKind,
        NexusTypes.RouteUnlockClass unlockClass,
        NexusTypes.WorldBossKind worldBossKind,
        uint8 requiredCoreLevel,
        uint8 requiredSignalLevel,
        uint8 requiredArchiveLevel,
        uint8 requiredExchangeLevel,
        uint32 stabilityBps,
        uint32 instabilityBps,
        uint256 aetherActivationCost,
        uint256 aetherMaintenanceCost,
        uint64 openAt,
        uint64 closeAt,
        bool hiddenRoute,
        bool worldBossEligible,
        bool seasonal
    ) external onlyRole(ROUTE_SETTER_ROLE) whenNotPaused returns (uint256 routeId) {
        _validateRouteInputs(
            zoneKind,
            unlockClass,
            worldBossKind,
            requiredCoreLevel,
            requiredSignalLevel,
            requiredArchiveLevel,
            requiredExchangeLevel,
            stabilityBps,
            instabilityBps,
            openAt,
            closeAt
        );

        routeId = _nextRouteId++;
        _allRouteIds.push(routeId);
        _routeExists[routeId] = true;

        _routeById[routeId] = NexusTypes.PortalRoute({
            routeId: routeId,
            zoneKind: zoneKind,
            state: NexusTypes.PortalRouteState.Draft,
            unlockClass: unlockClass,
            worldBossKind: worldBossKind,
            requiredCoreLevel: requiredCoreLevel,
            requiredSignalLevel: requiredSignalLevel,
            requiredArchiveLevel: requiredArchiveLevel,
            requiredExchangeLevel: requiredExchangeLevel,
            stabilityBps: stabilityBps,
            instabilityBps: instabilityBps,
            aetherActivationCost: aetherActivationCost,
            aetherMaintenanceCost: aetherMaintenanceCost,
            openAt: openAt,
            closeAt: closeAt,
            lastStateChangeAt: uint64(block.timestamp),
            discoveryHash: bytes32(0),
            hiddenRoute: hiddenRoute,
            worldBossEligible: worldBossEligible,
            seasonal: seasonal
        });

        emit PortalRouteCreated(routeId, zoneKind, unlockClass, msg.sender);
        emit PortalRouteUpdated(routeId, zoneKind, NexusTypes.PortalRouteState.Draft, msg.sender);

        _syncPortalMetrics(msg.sender);
    }

    function updatePortalRoute(
        uint256 routeId,
        NexusTypes.PortalZoneKind zoneKind,
        NexusTypes.RouteUnlockClass unlockClass,
        NexusTypes.WorldBossKind worldBossKind,
        uint8 requiredCoreLevel,
        uint8 requiredSignalLevel,
        uint8 requiredArchiveLevel,
        uint8 requiredExchangeLevel,
        uint32 stabilityBps,
        uint32 instabilityBps,
        uint256 aetherActivationCost,
        uint256 aetherMaintenanceCost,
        uint64 openAt,
        uint64 closeAt,
        bool hiddenRoute,
        bool worldBossEligible,
        bool seasonal
    ) external onlyRole(ROUTE_SETTER_ROLE) whenNotPaused {
        NexusTypes.PortalRoute storage route = _requireRoute(routeId);

        _validateRouteInputs(
            zoneKind,
            unlockClass,
            worldBossKind,
            requiredCoreLevel,
            requiredSignalLevel,
            requiredArchiveLevel,
            requiredExchangeLevel,
            stabilityBps,
            instabilityBps,
            openAt,
            closeAt
        );

        route.zoneKind = zoneKind;
        route.unlockClass = unlockClass;
        route.worldBossKind = worldBossKind;
        route.requiredCoreLevel = requiredCoreLevel;
        route.requiredSignalLevel = requiredSignalLevel;
        route.requiredArchiveLevel = requiredArchiveLevel;
        route.requiredExchangeLevel = requiredExchangeLevel;
        route.stabilityBps = stabilityBps;
        route.instabilityBps = instabilityBps;
        route.aetherActivationCost = aetherActivationCost;
        route.aetherMaintenanceCost = aetherMaintenanceCost;
        route.openAt = openAt;
        route.closeAt = closeAt;
        route.hiddenRoute = hiddenRoute;
        route.worldBossEligible = worldBossEligible;
        route.seasonal = seasonal;

        emit PortalRouteUpdated(routeId, zoneKind, route.state, msg.sender);

        _syncPortalMetrics(msg.sender);
    }

    function setRouteState(
        uint256 routeId,
        NexusTypes.PortalRouteState newState
    ) external onlyRole(ROUTE_SETTER_ROLE) whenNotPaused {
        NexusTypes.PortalRoute storage route = _requireRoute(routeId);
        _requireValidRouteState(newState);

        NexusTypes.PortalRouteState oldState = route.state;
        if (oldState == newState) revert NoStateChange();

        route.state = newState;
        route.lastStateChangeAt = uint64(block.timestamp);

        emit PortalRouteStateSet(routeId, oldState, newState, msg.sender);

        _syncPortalMetrics(msg.sender);
    }

    function openRoute(
        uint256 routeId
    ) external onlyRole(ROUTE_SETTER_ROLE) whenNotPaused {
        NexusTypes.PortalRoute storage route = _requireRoute(routeId);

        if (route.hiddenRoute && !_hiddenRouteRecordByRouteId[routeId].unlocked) {
            revert HiddenRouteLocked();
        }

        (bool allowed, bytes32 reasonCode) = _routeRequirementsMet(route);
        if (!allowed) revert RouteRequirementsNotMet(reasonCode);

        NexusTypes.PortalRouteState oldState = route.state;
        NexusTypes.PortalRouteState newState = route.instabilityBps > route.stabilityBps
            ? NexusTypes.PortalRouteState.Unstable
            : NexusTypes.PortalRouteState.Active;

        if (oldState == newState) revert NoStateChange();

        route.state = newState;
        route.lastStateChangeAt = uint64(block.timestamp);

        emit PortalRouteStateSet(routeId, oldState, newState, msg.sender);

        _syncPortalMetrics(msg.sender);
    }

    function closeRoute(
        uint256 routeId
    ) external onlyRole(ROUTE_SETTER_ROLE) whenNotPaused {
        NexusTypes.PortalRoute storage route = _requireRoute(routeId);

        NexusTypes.PortalRouteState oldState = route.state;
        if (
            oldState == NexusTypes.PortalRouteState.Inactive ||
            oldState == NexusTypes.PortalRouteState.Archived
        ) revert NoStateChange();

        route.state = NexusTypes.PortalRouteState.Inactive;
        route.lastStateChangeAt = uint64(block.timestamp);

        emit PortalRouteStateSet(
            routeId,
            oldState,
            NexusTypes.PortalRouteState.Inactive,
            msg.sender
        );

        _syncPortalMetrics(msg.sender);
    }

    function unlockHiddenRoute(
        uint256 routeId,
        bytes32 discoveryHash,
        address discoveredBy
    ) external whenNotPaused {
        if (
            !hasRole(PORTAL_SYSTEM_ROLE, msg.sender) &&
            !hasRole(ROUTE_SETTER_ROLE, msg.sender)
        ) revert AccessControlUnauthorizedAccount(msg.sender, PORTAL_SYSTEM_ROLE);

        NexusTypes.PortalRoute storage route = _requireRoute(routeId);
        if (!route.hiddenRoute) revert NoStateChange();

        NexusTypes.HiddenRouteRecord storage record = _hiddenRouteRecordByRouteId[routeId];
        if (record.unlocked) revert HiddenRouteAlreadyUnlocked();

        record.routeId = routeId;
        record.discoveryHash = discoveryHash;
        record.discoveredBy = discoveredBy == address(0) ? msg.sender : discoveredBy;
        record.discoveredAt = uint64(block.timestamp);
        record.unlocked = true;

        route.discoveryHash = discoveryHash;
        if (route.state == NexusTypes.PortalRouteState.Draft) {
            route.state = NexusTypes.PortalRouteState.Inactive;
            route.lastStateChangeAt = uint64(block.timestamp);
        }

        emit HiddenRouteUnlocked(
            routeId,
            discoveryHash,
            record.discoveredBy,
            record.discoveredAt
        );

        _syncPortalMetrics(msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                          SEASONAL ROTATION
    //////////////////////////////////////////////////////////////*/

    function setSeasonalRouteRotation(
        uint32 seasonId,
        uint256[] calldata routeIds,
        uint64 startsAt,
        uint64 endsAt,
        uint32 modifierMask,
        bool bossWindowOpen
    ) external onlyRole(ROUTE_SETTER_ROLE) whenNotPaused {
        if (routeIds.length == 0 || routeIds.length > 4) {
            revert InvalidRouteArrayLength();
        }
        if (endsAt != 0 && startsAt != 0 && endsAt <= startsAt) {
            revert InvalidWindow();
        }

        NexusTypes.SeasonalRouteRotation storage rotation = _seasonalRotationBySeasonId[seasonId];
        _seasonalRotationExists[seasonId] = true;

        for (uint256 i = 0; i < 4; i++) {
            rotation.routeIds[i] = 0;
        }

        for (uint256 i = 0; i < routeIds.length; i++) {
            _requireRoute(routeIds[i]);
            rotation.routeIds[i] = routeIds[i];
        }

        rotation.seasonId = seasonId;
        rotation.activeRouteCount = uint8(routeIds.length);
        rotation.startsAt = startsAt;
        rotation.endsAt = endsAt;
        rotation.modifierMask = modifierMask;
        rotation.bossWindowOpen = bossWindowOpen;

        emit SeasonalRouteRotationSet(
            seasonId,
            uint8(routeIds.length),
            startsAt,
            endsAt,
            msg.sender
        );
    }

    function applySeasonalRotation(
        uint32 seasonId
    ) external onlyRole(ROUTE_SETTER_ROLE) whenNotPaused {
        if (!_seasonalRotationExists[seasonId]) revert SeasonRotationNotFound();

        NexusTypes.SeasonalRouteRotation memory rotation = _seasonalRotationBySeasonId[seasonId];
        uint64 ts = uint64(block.timestamp);

        bool withinWindow =
            (rotation.startsAt == 0 || ts >= rotation.startsAt) &&
            (rotation.endsAt == 0 || ts <= rotation.endsAt);

        for (uint256 i = 0; i < rotation.activeRouteCount; i++) {
            uint256 routeId = rotation.routeIds[i];
            if (routeId == 0) continue;

            NexusTypes.PortalRoute storage route = _routeById[routeId];

            if (!withinWindow) {
                if (
                    route.state != NexusTypes.PortalRouteState.Archived &&
                    route.state != NexusTypes.PortalRouteState.Sealed
                ) {
                    NexusTypes.PortalRouteState oldState = route.state;
                    route.state = NexusTypes.PortalRouteState.Inactive;
                    route.lastStateChangeAt = ts;

                    emit PortalRouteStateSet(
                        routeId,
                        oldState,
                        NexusTypes.PortalRouteState.Inactive,
                        msg.sender
                    );
                }
                continue;
            }

            if (route.hiddenRoute && !_hiddenRouteRecordByRouteId[routeId].unlocked) {
                NexusTypes.PortalRouteState oldStateHidden = route.state;
                route.state = NexusTypes.PortalRouteState.Locked;
                route.lastStateChangeAt = ts;

                emit PortalRouteStateSet(
                    routeId,
                    oldStateHidden,
                    NexusTypes.PortalRouteState.Locked,
                    msg.sender
                );
                continue;
            }

            (bool allowed, ) = _routeRequirementsMet(route);
            NexusTypes.PortalRouteState oldState = route.state;

            if (!allowed) {
                route.state = NexusTypes.PortalRouteState.Locked;
            } else {
                route.state = route.instabilityBps > route.stabilityBps
                    ? NexusTypes.PortalRouteState.Unstable
                    : NexusTypes.PortalRouteState.Active;
            }

            route.lastStateChangeAt = ts;

            emit PortalRouteStateSet(routeId, oldState, route.state, msg.sender);
        }

        emit SeasonalRotationApplied(seasonId, msg.sender, ts);

        _syncPortalMetrics(msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                           WORLD BOSS WINDOWS
    //////////////////////////////////////////////////////////////*/

    function createWorldBossWindow(
        uint256 routeId,
        NexusTypes.WorldBossKind bossKind,
        uint64 opensAt,
        uint64 closesAt,
        uint32 modifierMask
    ) external onlyRole(WORLD_BOSS_ROLE) whenNotPaused returns (uint256 windowId) {
        NexusTypes.PortalRoute storage route = _requireRoute(routeId);
        if (!route.worldBossEligible) revert RouteRequirementsNotMet(_rc("ROUTE_NOT_BOSS_ELIGIBLE"));
        if (!NexusTypes.isValidWorldBoss(bossKind)) revert InvalidWorldBoss();
        if (closesAt != 0 && opensAt != 0 && closesAt <= opensAt) revert InvalidWindow();

        windowId = _nextBossWindowId++;
        _allBossWindowIds.push(windowId);
        _bossWindowExists[windowId] = true;

        _bossWindowById[windowId] = NexusTypes.WorldBossWindow({
            windowId: windowId,
            bossKind: bossKind,
            zoneKind: route.zoneKind,
            opensAt: opensAt,
            closesAt: closesAt,
            modifierMask: modifierMask,
            active: false,
            defeated: false
        });

        emit WorldBossWindowCreated(
            windowId,
            routeId,
            bossKind,
            opensAt,
            closesAt
        );
    }

    function setWorldBossWindowState(
        uint256 windowId,
        uint256 routeId,
        bool active
    ) external onlyRole(WORLD_BOSS_ROLE) whenNotPaused {
        NexusTypes.WorldBossWindow storage window = _requireBossWindow(windowId);
        _requireRoute(routeId);

        if (window.active == active) revert NoStateChange();

        window.active = active;
        if (active) {
            activeBossWindowIdByRouteId[routeId] = windowId;
        } else if (activeBossWindowIdByRouteId[routeId] == windowId) {
            activeBossWindowIdByRouteId[routeId] = 0;
        }

        emit WorldBossWindowStateSet(windowId, active, msg.sender);

        _syncPortalMetrics(msg.sender);
    }

    function setWorldBossWindowDefeated(
        uint256 windowId,
        bool defeated
    ) external onlyRole(WORLD_BOSS_ROLE) whenNotPaused {
        NexusTypes.WorldBossWindow storage window = _requireBossWindow(windowId);

        if (window.defeated == defeated) revert NoStateChange();
        window.defeated = defeated;

        emit WorldBossWindowDefeatedSet(windowId, defeated, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                          EXPEDITION CONFIGS
    //////////////////////////////////////////////////////////////*/

    function createExpeditionConfig(
        NexusTypes.ExpeditionClass expeditionClass,
        NexusTypes.PortalZoneKind zoneKind,
        uint8 minCoreLevel,
        uint8 minSignalLevel,
        uint8 minArchiveLevel,
        uint8 minExchangeLevel,
        uint256[10] calldata supplyAmounts,
        uint32 riskBps,
        uint32 successBonusBps,
        uint32 salvageBps,
        uint64 cooldownSeconds,
        bool publicQueue,
        bool worldBossEligible,
        bool enabled
    ) external onlyRole(EXPEDITION_ADMIN_ROLE) whenNotPaused returns (uint256 configId) {
        if (!NexusTypes.isValidExpeditionClass(expeditionClass)) revert InvalidExpeditionClass();
        if (!NexusTypes.isValidPortalZone(zoneKind)) revert InvalidZoneKind();
        if (
            riskBps > 10_000 ||
            successBonusBps > 10_000 ||
            salvageBps > 10_000
        ) revert InvalidBps();

        _requireValidRequiredLevels(
            minCoreLevel,
            minSignalLevel,
            minArchiveLevel,
            minExchangeLevel
        );

        configId = _nextExpeditionConfigId++;
        _allExpeditionConfigIds.push(configId);
        _expeditionConfigExists[configId] = true;

        _expeditionConfigById[configId] = NexusTypes.ExpeditionConfig({
            configId: configId,
            expeditionClass: expeditionClass,
            zoneKind: zoneKind,
            minCoreLevel: minCoreLevel,
            minSignalLevel: minSignalLevel,
            minArchiveLevel: minArchiveLevel,
            minExchangeLevel: minExchangeLevel,
            maxParticipants: NexusTypes.maxParticipantsForExpeditionClass(expeditionClass),
            supplyAmounts: supplyAmounts,
            riskBps: riskBps,
            successBonusBps: successBonusBps,
            salvageBps: salvageBps,
            cooldownSeconds: cooldownSeconds,
            publicQueue: publicQueue,
            worldBossEligible: worldBossEligible,
            enabled: enabled
        });

        emit ExpeditionConfigCreated(
            configId,
            expeditionClass,
            zoneKind,
            msg.sender
        );
    }

    function setExpeditionConfigEnabled(
        uint256 configId,
        bool enabled
    ) external onlyRole(EXPEDITION_ADMIN_ROLE) whenNotPaused {
        NexusTypes.ExpeditionConfig storage config = _requireExpeditionConfig(configId);
        if (config.enabled == enabled) revert NoStateChange();

        config.enabled = enabled;

        emit ExpeditionConfigEnabledSet(configId, enabled, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                                  READS
    //////////////////////////////////////////////////////////////*/

    function getRoute(
        uint256 routeId
    ) external view returns (NexusTypes.PortalRoute memory) {
        return _routeById[_requireRoute(routeId).routeId];
    }

    function getHiddenRouteRecord(
        uint256 routeId
    ) external view returns (NexusTypes.HiddenRouteRecord memory) {
        _requireRoute(routeId);
        return _hiddenRouteRecordByRouteId[routeId];
    }

    function getSeasonalRouteRotation(
        uint32 seasonId
    ) external view returns (NexusTypes.SeasonalRouteRotation memory) {
        if (!_seasonalRotationExists[seasonId]) revert SeasonRotationNotFound();
        return _seasonalRotationBySeasonId[seasonId];
    }

    function getWorldBossWindow(
        uint256 windowId
    ) external view returns (NexusTypes.WorldBossWindow memory) {
        return _bossWindowById[_requireBossWindow(windowId).windowId];
    }

    function getExpeditionConfig(
        uint256 configId
    ) external view returns (NexusTypes.ExpeditionConfig memory) {
        return _expeditionConfigById[_requireExpeditionConfig(configId).configId];
    }

    function isRouteActive(
        uint256 routeId
    ) external view returns (bool) {
        NexusTypes.PortalRoute memory route = _routeById[_requireRoute(routeId).routeId];
        return NexusTypes.isActiveRouteState(route.state);
    }

    function getUnlockedZoneMask() external view returns (uint256 mask) {
        uint256 len = _allRouteIds.length;

        for (uint256 i = 0; i < len; i++) {
            uint256 routeId = _allRouteIds[i];
            NexusTypes.PortalRoute memory route = _routeById[routeId];

            bool hiddenUnlocked = !route.hiddenRoute || _hiddenRouteRecordByRouteId[routeId].unlocked;
            if (hiddenUnlocked && NexusTypes.isRouteEnterableState(route.state)) {
                mask |= (uint256(1) << uint8(route.zoneKind));
            }
        }
    }

    function getPortalSummary()
        external
        view
        returns (
            uint32 seasonId,
            uint32 activeRouteCount,
            uint32 hiddenUnlockedCount,
            uint32 activeBossWindowCount,
            uint32 cityStabilityBps,
            uint32 cityInstabilityBps,
            bool emergencySealActive,
            bool worldBossWindowOpen
        )
    {
        NexusTypes.NexusGlobalState memory globalState = nexusBuildings.getNexusGlobalState();

        (
            activeRouteCount,
            hiddenUnlockedCount,
            activeBossWindowCount,
            cityStabilityBps,
            cityInstabilityBps
        ) = _portalMetrics();

        seasonId = globalState.seasonId;
        emergencySealActive = globalState.emergencySealActive;
        worldBossWindowOpen = globalState.worldBossWindowOpen;
    }

    function previewExpeditionEligibility(
        address account,
        uint256 configId
    )
        external
        view
        returns (
            bool eligible,
            bool hasCityKey,
            bool routeAvailable,
            uint256 routeId,
            bool coreReady,
            bool signalReady,
            bool archiveReady,
            bool exchangeReady,
            bool emergencySealActive,
            bool bossWindowOpen,
            bytes32 reasonCode
        )
    {
        NexusTypes.ExpeditionConfig memory config =
            _expeditionConfigById[_requireExpeditionConfig(configId).configId];

        if (!config.enabled) {
            return (false, false, false, 0, false, false, false, false, false, false, _rc("CONFIG_DISABLED"));
        }

        hasCityKey = cityRegistry.hasCityKeyOf(account);
        if (!hasCityKey) {
            return (false, false, false, 0, false, false, false, false, false, false, _rc("NO_CITY_KEY"));
        }

        NexusTypes.NexusGlobalState memory globalState = nexusBuildings.getNexusGlobalState();
        emergencySealActive = globalState.emergencySealActive;
        bossWindowOpen = globalState.worldBossWindowOpen;

        if (emergencySealActive) {
            return (false, true, false, 0, false, false, false, false, true, bossWindowOpen, _rc("EMERGENCY_SEAL_ACTIVE"));
        }

        routeId = _findEligibleRouteForZone(config.zoneKind);
        routeAvailable = routeId != 0;
        if (!routeAvailable) {
            return (false, true, false, 0, false, false, false, false, false, bossWindowOpen, _rc("NO_ELIGIBLE_ROUTE"));
        }

        (uint8 coreLevel, uint8 signalLevel, uint8 archiveLevel, uint8 exchangeLevel) = _currentNexusLevels();

        coreReady = coreLevel >= config.minCoreLevel;
        signalReady = signalLevel >= config.minSignalLevel;
        archiveReady = archiveLevel >= config.minArchiveLevel;
        exchangeReady = exchangeLevel >= config.minExchangeLevel;

        if (!coreReady) {
            return (false, true, true, routeId, false, signalReady, archiveReady, exchangeReady, false, bossWindowOpen, _rc("CORE_LEVEL_TOO_LOW"));
        }
        if (!signalReady) {
            return (false, true, true, routeId, true, false, archiveReady, exchangeReady, false, bossWindowOpen, _rc("SIGNAL_LEVEL_TOO_LOW"));
        }
        if (!archiveReady) {
            return (false, true, true, routeId, true, true, false, exchangeReady, false, bossWindowOpen, _rc("ARCHIVE_LEVEL_TOO_LOW"));
        }
        if (!exchangeReady) {
            return (false, true, true, routeId, true, true, true, false, false, bossWindowOpen, _rc("EXCHANGE_LEVEL_TOO_LOW"));
        }
        if (config.worldBossEligible && !bossWindowOpen) {
            return (false, true, true, routeId, true, true, true, true, false, false, _rc("WORLD_BOSS_WINDOW_CLOSED"));
        }

        return (true, true, true, routeId, true, true, true, true, false, bossWindowOpen, bytes32(0));
    }

    function routeCount() external view returns (uint256) {
        return _allRouteIds.length;
    }

    function bossWindowCount() external view returns (uint256) {
        return _allBossWindowIds.length;
    }

    function expeditionConfigCount() external view returns (uint256) {
        return _allExpeditionConfigIds.length;
    }

    /*//////////////////////////////////////////////////////////////
                             METRICS SYNC
    //////////////////////////////////////////////////////////////*/

    function syncPortalMetricsToNexus() external whenNotPaused {
        if (
            !hasRole(PORTAL_SYSTEM_ROLE, msg.sender) &&
            !hasRole(PORTAL_OPERATOR_ROLE, msg.sender) &&
            !hasRole(PORTAL_ADMIN_ROLE, msg.sender)
        ) revert AccessControlUnauthorizedAccount(msg.sender, PORTAL_SYSTEM_ROLE);

        _syncPortalMetrics(msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                               INTERNALS
    //////////////////////////////////////////////////////////////*/

    function _requireRoute(
        uint256 routeId
    ) internal view returns (NexusTypes.PortalRoute storage route) {
        if (!_routeExists[routeId]) revert RouteNotFound();
        route = _routeById[routeId];
    }

    function _requireBossWindow(
        uint256 windowId
    ) internal view returns (NexusTypes.WorldBossWindow storage window) {
        if (!_bossWindowExists[windowId]) revert BossWindowNotFound();
        window = _bossWindowById[windowId];
    }

    function _requireExpeditionConfig(
        uint256 configId
    ) internal view returns (NexusTypes.ExpeditionConfig storage config) {
        if (!_expeditionConfigExists[configId]) revert ExpeditionConfigNotFound();
        config = _expeditionConfigById[configId];
    }

    function _requireValidRouteState(
        NexusTypes.PortalRouteState state_
    ) internal pure {
        if (
            state_ == NexusTypes.PortalRouteState.None
        ) revert InvalidRouteState();
    }

    function _validateRouteInputs(
        NexusTypes.PortalZoneKind zoneKind,
        NexusTypes.RouteUnlockClass unlockClass,
        NexusTypes.WorldBossKind worldBossKind,
        uint8 requiredCoreLevel,
        uint8 requiredSignalLevel,
        uint8 requiredArchiveLevel,
        uint8 requiredExchangeLevel,
        uint32 stabilityBps,
        uint32 instabilityBps,
        uint64 openAt,
        uint64 closeAt
    ) internal pure {
        if (!NexusTypes.isValidPortalZone(zoneKind)) revert InvalidZoneKind();

        if (
            unlockClass == NexusTypes.RouteUnlockClass.None
        ) revert InvalidUnlockClass();

        if (worldBossKind != NexusTypes.WorldBossKind.None && !NexusTypes.isValidWorldBoss(worldBossKind)) {
            revert InvalidWorldBoss();
        }

        _requireValidRequiredLevels(
            requiredCoreLevel,
            requiredSignalLevel,
            requiredArchiveLevel,
            requiredExchangeLevel
        );

        if (stabilityBps > 10_000 || instabilityBps > 10_000) revert InvalidBps();
        if (closeAt != 0 && openAt != 0 && closeAt <= openAt) revert InvalidWindow();
    }

    function _requireValidRequiredLevels(
        uint8 requiredCoreLevel,
        uint8 requiredSignalLevel,
        uint8 requiredArchiveLevel,
        uint8 requiredExchangeLevel
    ) internal pure {
        if (requiredCoreLevel > CollectiveBuildingTypes.MAX_COLLECTIVE_LEVEL) revert InvalidTier();
        if (requiredSignalLevel > CollectiveBuildingTypes.MAX_COLLECTIVE_LEVEL) revert InvalidTier();
        if (requiredArchiveLevel > CollectiveBuildingTypes.MAX_COLLECTIVE_LEVEL) revert InvalidTier();
        if (requiredExchangeLevel > CollectiveBuildingTypes.MAX_COLLECTIVE_LEVEL) revert InvalidTier();
    }

    function _routeRequirementsMet(
        NexusTypes.PortalRoute storage route
    ) internal view returns (bool allowed, bytes32 reasonCode) {
        NexusTypes.NexusGlobalState memory globalState = nexusBuildings.getNexusGlobalState();

        if (globalState.emergencySealActive) {
            return (false, _rc("EMERGENCY_SEAL_ACTIVE"));
        }

        if (route.openAt != 0 && block.timestamp < route.openAt) {
            return (false, _rc("ROUTE_WINDOW_NOT_OPEN"));
        }

        if (route.closeAt != 0 && block.timestamp > route.closeAt) {
            return (false, _rc("ROUTE_WINDOW_CLOSED"));
        }

        if (route.hiddenRoute && !_hiddenRouteRecordByRouteId[route.routeId].unlocked) {
            return (false, _rc("HIDDEN_ROUTE_LOCKED"));
        }

        (uint8 coreLevel, uint8 signalLevel, uint8 archiveLevel, uint8 exchangeLevel) = _currentNexusLevels();

        if (coreLevel < route.requiredCoreLevel) {
            return (false, _rc("CORE_LEVEL_TOO_LOW"));
        }
        if (signalLevel < route.requiredSignalLevel) {
            return (false, _rc("SIGNAL_LEVEL_TOO_LOW"));
        }
        if (archiveLevel < route.requiredArchiveLevel) {
            return (false, _rc("ARCHIVE_LEVEL_TOO_LOW"));
        }
        if (exchangeLevel < route.requiredExchangeLevel) {
            return (false, _rc("EXCHANGE_LEVEL_TOO_LOW"));
        }

        return (true, bytes32(0));
    }

    function _currentNexusLevels()
        internal
        view
        returns (
            uint8 coreLevel,
            uint8 signalLevel,
            uint8 archiveLevel,
            uint8 exchangeLevel
        )
    {
        coreLevel = _activeLevelOf(CollectiveBuildingTypes.NexusBuildingKind.NexusCore);
        signalLevel = _activeLevelOf(CollectiveBuildingTypes.NexusBuildingKind.NexusSignalSpire);
        archiveLevel = _activeLevelOf(CollectiveBuildingTypes.NexusBuildingKind.NexusArchive);
        exchangeLevel = _activeLevelOf(CollectiveBuildingTypes.NexusBuildingKind.NexusExchangeHub);
    }

    function _activeLevelOf(
        CollectiveBuildingTypes.NexusBuildingKind kind
    ) internal view returns (uint8) {
        if (!nexusBuildings.kindIsActive(kind)) return 0;

        uint256 tokenId = nexusBuildings.getTokenIdForKind(kind);
        if (tokenId == 0) return 0;

        CollectiveBuildingTypes.CollectiveIdentity memory id_ = collectiveNFT.getCollectiveIdentity(tokenId);
        return id_.level;
    }

    function _findEligibleRouteForZone(
        NexusTypes.PortalZoneKind zoneKind
    ) internal view returns (uint256 routeId) {
        uint256 len = _allRouteIds.length;

        for (uint256 i = 0; i < len; i++) {
            uint256 candidateId = _allRouteIds[i];
            NexusTypes.PortalRoute storage route = _routeById[candidateId];
            if (route.zoneKind != zoneKind) continue;
            if (!NexusTypes.isRouteEnterableState(route.state)) continue;

            bool hiddenUnlocked = !route.hiddenRoute || _hiddenRouteRecordByRouteId[candidateId].unlocked;
            if (!hiddenUnlocked) continue;

            (bool allowed, ) = _routeRequirementsMet(route);
            if (allowed) {
                return candidateId;
            }
        }

        return 0;
    }

    function _portalMetrics()
        internal
        view
        returns (
            uint32 activeRouteCount,
            uint32 hiddenUnlockedCount,
            uint32 activeBossWindowCount,
            uint32 cityStabilityBps,
            uint32 cityInstabilityBps
        )
    {
        uint256 len = _allRouteIds.length;
        uint256 stabilityAccumulator;
        uint256 instabilityAccumulator;

        for (uint256 i = 0; i < len; i++) {
            uint256 routeId = _allRouteIds[i];
            NexusTypes.PortalRoute storage route = _routeById[routeId];

            if (_hiddenRouteRecordByRouteId[routeId].unlocked) {
                hiddenUnlockedCount += 1;
            }

            if (NexusTypes.isActiveRouteState(route.state)) {
                activeRouteCount += 1;
                stabilityAccumulator += route.stabilityBps;
                instabilityAccumulator += route.instabilityBps;
            }
        }

        uint256 bossLen = _allBossWindowIds.length;
        for (uint256 i = 0; i < bossLen; i++) {
            if (_bossWindowById[_allBossWindowIds[i]].active) {
                activeBossWindowCount += 1;
            }
        }

        if (activeRouteCount != 0) {
            cityStabilityBps = uint32(stabilityAccumulator / activeRouteCount);
            cityInstabilityBps = uint32(instabilityAccumulator / activeRouteCount);
        }
    }

    function _syncPortalMetrics(address executor) internal {
        (
            uint32 activeRouteCount,
            uint32 hiddenUnlockedCount,
            ,
            uint32 cityStabilityBps,
            uint32 cityInstabilityBps
        ) = _portalMetrics();

        NexusTypes.NexusGlobalState memory globalState = nexusBuildings.getNexusGlobalState();

        try nexusBuildings.syncNexusMetrics(
            activeRouteCount,
            hiddenUnlockedCount,
            globalState.activeDungeonCount,
            cityStabilityBps,
            cityInstabilityBps
        ) {
            // synced
        } catch {
            // best-effort only
        }

        emit PortalMetricsSynced(
            activeRouteCount,
            hiddenUnlockedCount,
            cityStabilityBps,
            cityInstabilityBps,
            executor,
            uint64(block.timestamp)
        );
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
        return super.supportsInterface(interfaceId);
    }
}