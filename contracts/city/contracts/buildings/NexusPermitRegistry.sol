// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/*//////////////////////////////////////////////////////////////
                    REWARD ROUTER CLAIM SOURCE
//////////////////////////////////////////////////////////////*/

/// @notice Minimal interface used by NexusPermitRegistry to consume season allocations
///         that were accrued inside NexusRewardRouter.
/// @dev The registry itself should be granted CLAIM_MANAGER_ROLE on the router.
interface INexusRewardRouterClaimSource {
    function claimableSeasonCreditsOf(
        uint32 seasonId,
        address player
    ) external view returns (uint256);

    function claimableSeasonPermitUnitsOf(
        uint32 seasonId,
        address player
    ) external view returns (uint32);

    function consumeClaimableSeasonAllocation(
        uint32 seasonId,
        address player,
        uint256 creditAmount,
        uint32 permitUnits
    ) external;
}

/*//////////////////////////////////////////////////////////////
                        NEXUS PERMIT REGISTRY
//////////////////////////////////////////////////////////////*/

/// @title NexusPermitRegistry
/// @notice Season-bound claim / balance / consumption registry for Nexus permits.
/// @dev The registry is intentionally generic:
///      - players can convert router-accrued season allocations into concrete permit balances
///      - portal / dungeon / future drop contracts can consume those balances through permit keys
///      - admin / operator roles can grant, burn and configure permit classes without changing router logic
///
///      This contract does not mint NFTs or ERC1155s. It tracks abstract, non-transferable permit balances.
contract NexusPermitRegistry is AccessControl, Pausable, ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                                 ROLES
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant REGISTRY_ADMIN_ROLE = keccak256("REGISTRY_ADMIN_ROLE");
    bytes32 public constant REGISTRY_OPERATOR_ROLE = keccak256("REGISTRY_OPERATOR_ROLE");
    bytes32 public constant PERMIT_MANAGER_ROLE = keccak256("PERMIT_MANAGER_ROLE");
    bytes32 public constant PERMIT_CONSUMER_ROLE = keccak256("PERMIT_CONSUMER_ROLE");
    bytes32 public constant PORTAL_HOOK_ROLE = keccak256("PORTAL_HOOK_ROLE");
    bytes32 public constant DUNGEON_HOOK_ROLE = keccak256("DUNGEON_HOOK_ROLE");

    /*//////////////////////////////////////////////////////////////
                               OPTIONAL KEYS
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant PERMIT_KEY_PORTAL_ACCESS =
        keccak256("NEXUS_PERMIT_PORTAL_ACCESS");

    bytes32 public constant PERMIT_KEY_WORLD_BOSS_ACCESS =
        keccak256("NEXUS_PERMIT_WORLD_BOSS_ACCESS");

    bytes32 public constant PERMIT_KEY_EVENT_DROP_CLAIM =
        keccak256("NEXUS_PERMIT_EVENT_DROP_CLAIM");

    bytes32 public constant PERMIT_KEY_ARCHIVE_ACCESS =
        keccak256("NEXUS_PERMIT_ARCHIVE_ACCESS");

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error InvalidHookContract();
    error InvalidRouterContract();
    error InvalidPermitKey();
    error InvalidConsumerContract();
    error InvalidPlayer();
    error InvalidQuantity();
    error InvalidIndex();
    error InvalidRecordId();
    error InvalidClaimWindow();
    error ZeroCostPublicClaim();
    error RewardRouterNotSet();
    error AmountOverflow();

    error PermitClaimDisabled(bytes32 permitKey);
    error PermitClaimWindowInactive(bytes32 permitKey);
    error PermitPerWalletCapExceeded(bytes32 permitKey);
    error PermitSeasonSupplyCapExceeded(bytes32 permitKey);
    error RouterClaimableCreditsExceeded();
    error RouterClaimablePermitUnitsExceeded();
    error UnauthorizedPermitConsumer(address caller);
    error ConsumerNotAuthorized(bytes32 permitKey, address consumer);
    error AmountExceedsPermitBalance();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event RewardRouterSet(
        address indexed oldContract,
        address indexed newContract,
        address indexed executor
    );

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

    event PermitTypeConfigured(
        bytes32 indexed permitKey,
        bool enabled,
        bool claimActive,
        uint32 permitUnitsPerPermit,
        uint256 eventCreditsPerPermit,
        uint32 maxClaimsPerWalletPerSeason,
        uint32 maxSupplyPerSeason,
        uint64 claimStartAt,
        uint64 claimEndAt,
        address indexed executor
    );

    event PermitConsumerAuthorizationSet(
        bytes32 indexed permitKey,
        address indexed consumer,
        bool allowed,
        address indexed executor
    );

    event SeasonPermitClaimed(
        uint256 indexed claimId,
        uint32 indexed seasonId,
        address indexed player,
        bytes32 permitKey,
        uint256 quantity,
        uint32 permitUnitsSpent,
        uint256 creditAmountSpent,
        uint64 claimedAt
    );

    event SeasonPermitGranted(
        uint256 indexed claimId,
        uint32 indexed seasonId,
        address indexed player,
        bytes32 permitKey,
        uint256 quantity,
        address executor,
        uint64 grantedAt
    );

    event SeasonPermitBurned(
        uint32 indexed seasonId,
        address indexed player,
        bytes32 indexed permitKey,
        uint256 quantity,
        address executor,
        uint64 burnedAt
    );

    event SeasonPermitConsumed(
        uint256 indexed consumptionId,
        uint32 indexed seasonId,
        address indexed player,
        bytes32 permitKey,
        address consumer,
        uint256 quantity,
        bytes32 contextKey,
        uint64 consumedAt
    );

    event SeasonPermitRefunded(
        uint32 indexed seasonId,
        address indexed player,
        bytes32 indexed permitKey,
        address consumer,
        uint256 quantity,
        bytes32 contextKey,
        uint64 refundedAt
    );

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    address public rewardRouter;
    address public dungeonContract;
    address public portalContract;

    struct PermitTypeConfigInput {
        bool enabled;
        bool claimActive;
        uint32 permitUnitsPerPermit;
        uint256 eventCreditsPerPermit;
        uint32 maxClaimsPerWalletPerSeason;
        uint32 maxSupplyPerSeason;
        uint64 claimStartAt;
        uint64 claimEndAt;
    }

    struct PermitTypeConfig {
        bool enabled;
        bool claimActive;
        uint32 permitUnitsPerPermit;
        uint256 eventCreditsPerPermit;
        uint32 maxClaimsPerWalletPerSeason;
        uint32 maxSupplyPerSeason;
        uint64 claimStartAt;
        uint64 claimEndAt;
        uint64 updatedAt;
    }

    struct PermitClaimRecord {
        uint256 claimId;
        uint32 seasonId;
        address player;
        bytes32 permitKey;
        uint256 quantity;
        uint32 permitUnitsSpent;
        uint256 creditAmountSpent;
        uint64 claimedAt;
        bool adminIssued;
    }

    struct PermitConsumptionRecord {
        uint256 consumptionId;
        uint32 seasonId;
        address player;
        bytes32 permitKey;
        address consumer;
        uint256 quantity;
        bytes32 contextKey;
        uint64 consumedAt;
    }

    struct PlayerPermitSummary {
        uint64 totalClaims;
        uint64 totalAdminGrants;
        uint64 totalConsumptions;
        uint256 totalPermitsReceived;
        uint256 totalPermitUnitsSpent;
        uint256 totalEventCreditsSpent;
        uint64 lastInteractionAt;
    }

    mapping(bytes32 => PermitTypeConfig) private _permitTypeConfigByKey;
    mapping(bytes32 => mapping(address => bool)) public isConsumerAuthorizedForPermit;

    mapping(uint32 => mapping(address => mapping(bytes32 => uint256))) public permitBalanceOf;
    mapping(uint32 => mapping(address => mapping(bytes32 => uint256))) public claimedQuantityBySeasonOf;

    mapping(uint32 => mapping(bytes32 => uint256)) public totalIssuedBySeasonOf;
    mapping(uint32 => mapping(bytes32 => uint256)) public totalConsumedBySeasonOf;

    mapping(uint256 => PermitClaimRecord) private _claimRecordById;
    mapping(uint256 => PermitConsumptionRecord) private _consumptionRecordById;

    uint256 public claimRecordCount;
    uint256 public consumptionRecordCount;

    mapping(address => mapping(uint256 => uint256)) private _claimIdByPlayerAt;
    mapping(address => uint256) public claimCountOfPlayer;

    mapping(uint32 => mapping(uint256 => uint256)) private _claimIdBySeasonAt;
    mapping(uint32 => uint256) public claimCountOfSeason;

    mapping(address => mapping(uint256 => uint256)) private _consumptionIdByPlayerAt;
    mapping(address => uint256) public consumptionCountOfPlayer;

    mapping(uint32 => mapping(uint256 => uint256)) private _consumptionIdBySeasonAt;
    mapping(uint32 => uint256) public consumptionCountOfSeason;

    mapping(address => PlayerPermitSummary) private _playerPermitSummaryByAddress;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address admin_) {
        if (admin_ == address(0)) revert ZeroAddress();

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(REGISTRY_ADMIN_ROLE, admin_);
        _grantRole(REGISTRY_OPERATOR_ROLE, admin_);
        _grantRole(PERMIT_MANAGER_ROLE, admin_);
    }

    /*//////////////////////////////////////////////////////////////
                                  ADMIN
    //////////////////////////////////////////////////////////////*/

    function pause() external onlyRole(REGISTRY_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(REGISTRY_ADMIN_ROLE) {
        _unpause();
    }

    function setRewardRouter(address rewardRouter_) external onlyRole(REGISTRY_ADMIN_ROLE) {
        if (rewardRouter_ == address(0)) {
            address oldRouter = rewardRouter;
            rewardRouter = address(0);
            emit RewardRouterSet(oldRouter, address(0), msg.sender);
            return;
        }

        if (rewardRouter_.code.length == 0) revert InvalidRouterContract();

        address oldContract = rewardRouter;
        rewardRouter = rewardRouter_;

        emit RewardRouterSet(oldContract, rewardRouter_, msg.sender);
    }

    function setDungeonContract(address dungeonContract_) external onlyRole(REGISTRY_ADMIN_ROLE) {
        address oldContract = dungeonContract;

        if (oldContract != address(0)) {
            _revokeRole(DUNGEON_HOOK_ROLE, oldContract);
        }

        if (dungeonContract_ == address(0)) {
            dungeonContract = address(0);
            emit DungeonContractSet(oldContract, address(0), msg.sender);
            return;
        }

        if (dungeonContract_.code.length == 0) revert InvalidHookContract();

        dungeonContract = dungeonContract_;
        _grantRole(DUNGEON_HOOK_ROLE, dungeonContract_);

        emit DungeonContractSet(oldContract, dungeonContract_, msg.sender);
    }

    function setPortalContract(address portalContract_) external onlyRole(REGISTRY_ADMIN_ROLE) {
        address oldContract = portalContract;

        if (oldContract != address(0)) {
            _revokeRole(PORTAL_HOOK_ROLE, oldContract);
        }

        if (portalContract_ == address(0)) {
            portalContract = address(0);
            emit PortalContractSet(oldContract, address(0), msg.sender);
            return;
        }

        if (portalContract_.code.length == 0) revert InvalidHookContract();

        portalContract = portalContract_;
        _grantRole(PORTAL_HOOK_ROLE, portalContract_);

        emit PortalContractSet(oldContract, portalContract_, msg.sender);
    }

    function setPermitTypeConfig(
        bytes32 permitKey,
        PermitTypeConfigInput calldata config
    ) external onlyRole(REGISTRY_OPERATOR_ROLE) {
        if (permitKey == bytes32(0)) revert InvalidPermitKey();

        if (
            config.claimStartAt != 0 &&
            config.claimEndAt != 0 &&
            config.claimEndAt < config.claimStartAt
        ) {
            revert InvalidClaimWindow();
        }

        _permitTypeConfigByKey[permitKey] = PermitTypeConfig({
            enabled: config.enabled,
            claimActive: config.claimActive,
            permitUnitsPerPermit: config.permitUnitsPerPermit,
            eventCreditsPerPermit: config.eventCreditsPerPermit,
            maxClaimsPerWalletPerSeason: config.maxClaimsPerWalletPerSeason,
            maxSupplyPerSeason: config.maxSupplyPerSeason,
            claimStartAt: config.claimStartAt,
            claimEndAt: config.claimEndAt,
            updatedAt: uint64(block.timestamp)
        });

        emit PermitTypeConfigured(
            permitKey,
            config.enabled,
            config.claimActive,
            config.permitUnitsPerPermit,
            config.eventCreditsPerPermit,
            config.maxClaimsPerWalletPerSeason,
            config.maxSupplyPerSeason,
            config.claimStartAt,
            config.claimEndAt,
            msg.sender
        );
    }

    function setPermitConsumerAuthorization(
        bytes32 permitKey,
        address consumer,
        bool allowed
    ) external onlyRole(REGISTRY_OPERATOR_ROLE) {
        if (permitKey == bytes32(0)) revert InvalidPermitKey();
        if (consumer == address(0)) revert ZeroAddress();
        if (consumer.code.length == 0) revert InvalidConsumerContract();

        isConsumerAuthorizedForPermit[permitKey][consumer] = allowed;

        emit PermitConsumerAuthorizationSet(permitKey, consumer, allowed, msg.sender);
    }

    function grantSeasonPermit(
        uint32 seasonId,
        address player,
        bytes32 permitKey,
        uint256 quantity
    ) external onlyRole(PERMIT_MANAGER_ROLE) nonReentrant {
        if (player == address(0)) revert InvalidPlayer();
        if (permitKey == bytes32(0)) revert InvalidPermitKey();
        if (quantity == 0) revert InvalidQuantity();

        PermitTypeConfig memory config = _permitTypeConfigByKey[permitKey];
        _enforceSeasonSupplyCap(seasonId, permitKey, quantity, config.maxSupplyPerSeason);

        _issuePermit(
            seasonId,
            player,
            permitKey,
            quantity,
            0,
            0,
            true
        );
    }

    function burnSeasonPermit(
        uint32 seasonId,
        address player,
        bytes32 permitKey,
        uint256 quantity
    ) external onlyRole(PERMIT_MANAGER_ROLE) nonReentrant {
        if (player == address(0)) revert InvalidPlayer();
        if (permitKey == bytes32(0)) revert InvalidPermitKey();
        if (quantity == 0) revert InvalidQuantity();

        uint256 balance = permitBalanceOf[seasonId][player][permitKey];
        if (quantity > balance) revert AmountExceedsPermitBalance();

        permitBalanceOf[seasonId][player][permitKey] = balance - quantity;

        PlayerPermitSummary storage summary = _playerPermitSummaryByAddress[player];
        summary.lastInteractionAt = uint64(block.timestamp);

        emit SeasonPermitBurned(
            seasonId,
            player,
            permitKey,
            quantity,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 CLAIMS
    //////////////////////////////////////////////////////////////*/

    /// @notice Converts claimable season allocations from NexusRewardRouter into concrete permit balances.
    /// @dev The registry contract itself must hold CLAIM_MANAGER_ROLE on the configured reward router.
    function claimSeasonPermit(
        uint32 seasonId,
        bytes32 permitKey,
        uint256 quantity
    ) external whenNotPaused nonReentrant {
        if (permitKey == bytes32(0)) revert InvalidPermitKey();
        if (quantity == 0) revert InvalidQuantity();
        if (rewardRouter == address(0)) revert RewardRouterNotSet();

        PermitTypeConfig memory config = _permitTypeConfigByKey[permitKey];
        if (!config.enabled || !config.claimActive) {
            revert PermitClaimDisabled(permitKey);
        }

        if (config.permitUnitsPerPermit == 0 && config.eventCreditsPerPermit == 0) {
            revert ZeroCostPublicClaim();
        }

        _enforceClaimWindow(permitKey, config);
        _enforcePerWalletSeasonCap(
            seasonId,
            msg.sender,
            permitKey,
            quantity,
            config.maxClaimsPerWalletPerSeason
        );
        _enforceSeasonSupplyCap(
            seasonId,
            permitKey,
            quantity,
            config.maxSupplyPerSeason
        );

        (uint256 creditsCost, uint32 unitsCost) = _previewClaimCost(config, quantity);
        _checkRouterAvailability(seasonId, msg.sender, creditsCost, unitsCost);

        INexusRewardRouterClaimSource(rewardRouter).consumeClaimableSeasonAllocation(
            seasonId,
            msg.sender,
            creditsCost,
            unitsCost
        );

        _issuePermit(
            seasonId,
            msg.sender,
            permitKey,
            quantity,
            unitsCost,
            creditsCost,
            false
        );
    }

    /*//////////////////////////////////////////////////////////////
                              CONSUMPTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Consumes previously claimed / granted permits.
    /// @dev Portal, dungeon and later drop contracts should be granted either
    ///      PORTAL_HOOK_ROLE, DUNGEON_HOOK_ROLE or PERMIT_CONSUMER_ROLE,
    ///      and also be explicitly authorized for the relevant permit key.
    function consumePermit(
        uint32 seasonId,
        address player,
        bytes32 permitKey,
        uint256 quantity,
        bytes32 contextKey
    ) external whenNotPaused nonReentrant {
        if (player == address(0)) revert InvalidPlayer();
        if (permitKey == bytes32(0)) revert InvalidPermitKey();
        if (quantity == 0) revert InvalidQuantity();

        _checkConsumerCaller(permitKey);

        uint256 balance = permitBalanceOf[seasonId][player][permitKey];
        if (quantity > balance) revert AmountExceedsPermitBalance();

        permitBalanceOf[seasonId][player][permitKey] = balance - quantity;
        totalConsumedBySeasonOf[seasonId][permitKey] += quantity;

        uint256 consumptionId = consumptionRecordCount + 1;
        consumptionRecordCount = consumptionId;

        _consumptionRecordById[consumptionId] = PermitConsumptionRecord({
            consumptionId: consumptionId,
            seasonId: seasonId,
            player: player,
            permitKey: permitKey,
            consumer: msg.sender,
            quantity: quantity,
            contextKey: contextKey,
            consumedAt: uint64(block.timestamp)
        });

        uint256 playerIndex = consumptionCountOfPlayer[player];
        _consumptionIdByPlayerAt[player][playerIndex] = consumptionId;
        consumptionCountOfPlayer[player] = playerIndex + 1;

        uint256 seasonIndex = consumptionCountOfSeason[seasonId];
        _consumptionIdBySeasonAt[seasonId][seasonIndex] = consumptionId;
        consumptionCountOfSeason[seasonId] = seasonIndex + 1;

        PlayerPermitSummary storage summary = _playerPermitSummaryByAddress[player];
        summary.totalConsumptions = _addToU64(summary.totalConsumptions, 1);
        summary.lastInteractionAt = uint64(block.timestamp);

        emit SeasonPermitConsumed(
            consumptionId,
            seasonId,
            player,
            permitKey,
            msg.sender,
            quantity,
            contextKey,
            uint64(block.timestamp)
        );
    }

    /// @notice Returns permits back to a player balance after a cancelled / reverted downstream action.
    function refundPermit(
        uint32 seasonId,
        address player,
        bytes32 permitKey,
        uint256 quantity,
        bytes32 contextKey
    ) external whenNotPaused nonReentrant {
        if (player == address(0)) revert InvalidPlayer();
        if (permitKey == bytes32(0)) revert InvalidPermitKey();
        if (quantity == 0) revert InvalidQuantity();

        _checkConsumerCaller(permitKey);

        permitBalanceOf[seasonId][player][permitKey] += quantity;

        uint256 consumed = totalConsumedBySeasonOf[seasonId][permitKey];
        if (quantity > consumed) {
            totalConsumedBySeasonOf[seasonId][permitKey] = 0;
        } else {
            totalConsumedBySeasonOf[seasonId][permitKey] = consumed - quantity;
        }

        PlayerPermitSummary storage summary = _playerPermitSummaryByAddress[player];
        summary.lastInteractionAt = uint64(block.timestamp);

        emit SeasonPermitRefunded(
            seasonId,
            player,
            permitKey,
            msg.sender,
            quantity,
            contextKey,
            uint64(block.timestamp)
        );
    }

    /*//////////////////////////////////////////////////////////////
                                  READS
    //////////////////////////////////////////////////////////////*/

    function getPermitTypeConfig(
        bytes32 permitKey
    ) external view returns (PermitTypeConfig memory) {
        return _permitTypeConfigByKey[permitKey];
    }

    function getPlayerPermitSummary(
        address player
    ) external view returns (PlayerPermitSummary memory) {
        return _playerPermitSummaryByAddress[player];
    }

    function getRouterSeasonAvailability(
        uint32 seasonId,
        address player
    )
        public
        view
        returns (uint256 claimableCredits, uint32 claimablePermitUnits)
    {
        if (rewardRouter == address(0)) {
            return (0, 0);
        }

        claimableCredits = INexusRewardRouterClaimSource(rewardRouter)
            .claimableSeasonCreditsOf(seasonId, player);
        claimablePermitUnits = INexusRewardRouterClaimSource(rewardRouter)
            .claimableSeasonPermitUnitsOf(seasonId, player);
    }

    function previewPermitClaim(
        bytes32 permitKey,
        uint256 quantity
    ) external view returns (uint256 creditCost, uint32 permitUnitCost) {
        if (permitKey == bytes32(0)) revert InvalidPermitKey();
        if (quantity == 0) revert InvalidQuantity();

        return _previewClaimCost(_permitTypeConfigByKey[permitKey], quantity);
    }

    function getClaimRecord(
        uint256 claimId
    ) external view returns (PermitClaimRecord memory) {
        if (claimId == 0 || claimId > claimRecordCount) revert InvalidRecordId();
        return _claimRecordById[claimId];
    }

    function getConsumptionRecord(
        uint256 consumptionId
    ) external view returns (PermitConsumptionRecord memory) {
        if (consumptionId == 0 || consumptionId > consumptionRecordCount) {
            revert InvalidRecordId();
        }
        return _consumptionRecordById[consumptionId];
    }

    function getPlayerClaimIdAt(
        address player,
        uint256 index
    ) external view returns (uint256) {
        if (index >= claimCountOfPlayer[player]) revert InvalidIndex();
        return _claimIdByPlayerAt[player][index];
    }

    function getSeasonClaimIdAt(
        uint32 seasonId,
        uint256 index
    ) external view returns (uint256) {
        if (index >= claimCountOfSeason[seasonId]) revert InvalidIndex();
        return _claimIdBySeasonAt[seasonId][index];
    }

    function getPlayerConsumptionIdAt(
        address player,
        uint256 index
    ) external view returns (uint256) {
        if (index >= consumptionCountOfPlayer[player]) revert InvalidIndex();
        return _consumptionIdByPlayerAt[player][index];
    }

    function getSeasonConsumptionIdAt(
        uint32 seasonId,
        uint256 index
    ) external view returns (uint256) {
        if (index >= consumptionCountOfSeason[seasonId]) revert InvalidIndex();
        return _consumptionIdBySeasonAt[seasonId][index];
    }

    /*//////////////////////////////////////////////////////////////
                               INTERNALS
    //////////////////////////////////////////////////////////////*/

    function _issuePermit(
        uint32 seasonId,
        address player,
        bytes32 permitKey,
        uint256 quantity,
        uint32 permitUnitsSpent,
        uint256 creditAmountSpent,
        bool adminIssued
    ) internal {
        permitBalanceOf[seasonId][player][permitKey] += quantity;
        totalIssuedBySeasonOf[seasonId][permitKey] += quantity;

        if (!adminIssued) {
            claimedQuantityBySeasonOf[seasonId][player][permitKey] += quantity;
        }

        uint256 claimId = claimRecordCount + 1;
        claimRecordCount = claimId;

        _claimRecordById[claimId] = PermitClaimRecord({
            claimId: claimId,
            seasonId: seasonId,
            player: player,
            permitKey: permitKey,
            quantity: quantity,
            permitUnitsSpent: permitUnitsSpent,
            creditAmountSpent: creditAmountSpent,
            claimedAt: uint64(block.timestamp),
            adminIssued: adminIssued
        });

        uint256 playerIndex = claimCountOfPlayer[player];
        _claimIdByPlayerAt[player][playerIndex] = claimId;
        claimCountOfPlayer[player] = playerIndex + 1;

        uint256 seasonIndex = claimCountOfSeason[seasonId];
        _claimIdBySeasonAt[seasonId][seasonIndex] = claimId;
        claimCountOfSeason[seasonId] = seasonIndex + 1;

        PlayerPermitSummary storage summary = _playerPermitSummaryByAddress[player];
        if (adminIssued) {
            summary.totalAdminGrants = _addToU64(summary.totalAdminGrants, 1);
        } else {
            summary.totalClaims = _addToU64(summary.totalClaims, 1);
        }
        summary.totalPermitsReceived += quantity;
        summary.totalPermitUnitsSpent += permitUnitsSpent;
        summary.totalEventCreditsSpent += creditAmountSpent;
        summary.lastInteractionAt = uint64(block.timestamp);

        if (adminIssued) {
            emit SeasonPermitGranted(
                claimId,
                seasonId,
                player,
                permitKey,
                quantity,
                msg.sender,
                uint64(block.timestamp)
            );
        } else {
            emit SeasonPermitClaimed(
                claimId,
                seasonId,
                player,
                permitKey,
                quantity,
                permitUnitsSpent,
                creditAmountSpent,
                uint64(block.timestamp)
            );
        }
    }

    function _checkConsumerCaller(bytes32 permitKey) internal view {
        bool hasConsumerRole =
            hasRole(PERMIT_CONSUMER_ROLE, msg.sender) ||
            hasRole(PORTAL_HOOK_ROLE, msg.sender) ||
            hasRole(DUNGEON_HOOK_ROLE, msg.sender);

        if (!hasConsumerRole) {
            revert UnauthorizedPermitConsumer(msg.sender);
        }

        if (!isConsumerAuthorizedForPermit[permitKey][msg.sender]) {
            revert ConsumerNotAuthorized(permitKey, msg.sender);
        }
    }

    function _checkRouterAvailability(
        uint32 seasonId,
        address player,
        uint256 creditAmount,
        uint32 permitUnits
    ) internal view {
        (uint256 claimableCredits, uint32 claimablePermitUnits) = getRouterSeasonAvailability(
            seasonId,
            player
        );

        if (creditAmount > claimableCredits) {
            revert RouterClaimableCreditsExceeded();
        }
        if (permitUnits > claimablePermitUnits) {
            revert RouterClaimablePermitUnitsExceeded();
        }
    }

    function _enforceClaimWindow(
        bytes32 permitKey,
        PermitTypeConfig memory config
    ) internal view {
        if (config.claimStartAt != 0 && block.timestamp < config.claimStartAt) {
            revert PermitClaimWindowInactive(permitKey);
        }
        if (config.claimEndAt != 0 && block.timestamp > config.claimEndAt) {
            revert PermitClaimWindowInactive(permitKey);
        }
    }

    function _enforcePerWalletSeasonCap(
        uint32 seasonId,
        address player,
        bytes32 permitKey,
        uint256 quantity,
        uint32 maxClaimsPerWalletPerSeason
    ) internal view {
        if (maxClaimsPerWalletPerSeason == 0) return;

        uint256 alreadyClaimed = claimedQuantityBySeasonOf[seasonId][player][permitKey];
        if (alreadyClaimed + quantity > maxClaimsPerWalletPerSeason) {
            revert PermitPerWalletCapExceeded(permitKey);
        }
    }

    function _enforceSeasonSupplyCap(
        uint32 seasonId,
        bytes32 permitKey,
        uint256 quantity,
        uint32 maxSupplyPerSeason
    ) internal view {
        if (maxSupplyPerSeason == 0) return;

        uint256 alreadyIssued = totalIssuedBySeasonOf[seasonId][permitKey];
        if (alreadyIssued + quantity > maxSupplyPerSeason) {
            revert PermitSeasonSupplyCapExceeded(permitKey);
        }
    }

    function _previewClaimCost(
        PermitTypeConfig memory config,
        uint256 quantity
    ) internal pure returns (uint256 creditCost, uint32 permitUnitCost) {
        creditCost = config.eventCreditsPerPermit * quantity;

        uint256 totalUnits = uint256(config.permitUnitsPerPermit) * quantity;
        if (totalUnits > type(uint32).max) revert AmountOverflow();
        permitUnitCost = uint32(totalUnits);
    }

    function _addToU64(uint64 current, uint256 delta) internal pure returns (uint64) {
        uint256 next = uint256(current) + delta;
        if (next > type(uint64).max) {
            return type(uint64).max;
        }
        return uint64(next);
    }
}
