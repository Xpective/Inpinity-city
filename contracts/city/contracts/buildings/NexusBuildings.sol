/* FILE: contracts/city/contracts/buildings/NexusBuildings.sol */
/* TYPE: nexus buildings orchestrator / citywide crowdfunding / custody layer — NOT PersonalBuildings */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import "../libraries/CityTypes.sol";
import "../libraries/CityBuildingTypes.sol";
import "../libraries/CollectiveBuildingTypes.sol";
import "../libraries/NexusTypes.sol";
import "../interfaces/IResourceToken.sol";
import "../interfaces/ICityLand.sol";

/*//////////////////////////////////////////////////////////////
                        EXTERNAL INTERFACES
//////////////////////////////////////////////////////////////*/

interface ICollectiveBuildingNFTV1Nexus {
    function mintNexusBuilding(
        address custodyHolder,
        CollectiveBuildingTypes.NexusBuildingKind kind,
        uint256 plotId,
        uint256 campaignId,
        CollectiveBuildingTypes.CollectiveCustodyMode custodyMode,
        uint32 versionTag
    ) external returns (uint256 tokenId);

    function getCollectiveIdentity(
        uint256 tokenId
    ) external view returns (CollectiveBuildingTypes.CollectiveIdentity memory);

    function getCollectiveState(
        uint256 tokenId
    ) external view returns (CollectiveBuildingTypes.CollectiveBuildingState);

    function setCollectiveState(
        uint256 tokenId,
        CollectiveBuildingTypes.CollectiveBuildingState newState
    ) external;

    function upgradeCollectiveBuilding(
        uint256 tokenId,
        uint8 newLevel
    ) external;

    function setNexusBranch(
        uint256 tokenId,
        CollectiveBuildingTypes.NexusBuildingBranch newBranch
    ) external;

    function addPrestigeScore(
        uint256 tokenId,
        uint32 amount
    ) external;

    function addHistoryScore(
        uint256 tokenId,
        uint32 amount
    ) external;
}

interface ICityRegistryNexusRead {
    function hasCityKeyOf(address user) external view returns (bool);

    function getPlotCore(
        uint256 plotId
    ) external view returns (CityTypes.PlotCore memory);
}

interface INexusStatusTouchHook {
    function touchActivity(uint256 plotId) external;
}

/*//////////////////////////////////////////////////////////////
                         NEXUS BUILDINGS
//////////////////////////////////////////////////////////////*/

contract NexusBuildings is
    AccessControl,
    Pausable,
    ReentrancyGuard,
    ERC1155Holder,
    ERC721Holder
{
    /*//////////////////////////////////////////////////////////////
                                 ROLES
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant NEXUS_ADMIN_ROLE = keccak256("NEXUS_ADMIN_ROLE");
    bytes32 public constant NEXUS_OPERATOR_ROLE = keccak256("NEXUS_OPERATOR_ROLE");
    bytes32 public constant NEXUS_ROLE_SETTER_ROLE = keccak256("NEXUS_ROLE_SETTER_ROLE");
    bytes32 public constant CUSTODY_MANAGER_ROLE = keccak256("CUSTODY_MANAGER_ROLE");
    bytes32 public constant NEXUS_SYSTEM_ROLE = keccak256("NEXUS_SYSTEM_ROLE");

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error InvalidCollectiveNFT();
    error InvalidCityRegistry();
    error InvalidCityLand();
    error InvalidResourceToken();
    error InvalidStatusHook();
    error InvalidSystemContract();

    error InvalidPlot();
    error InvalidPlotType();
    error PlotNotCompleted();
    error BuildingAlreadyExistsOnPlot();
    error NexusKindAlreadyExists();
    error NexusBuildingNotFound();

    error InvalidNexusKind();
    error InvalidNexusBranch();
    error InvalidVersionTag();
    error InvalidTargetLevel();
    error InvalidTier();
    error InvalidBps();
    error NoStateChange();
    error BuildingInactive();

    error NoCityKey();
    error NotCityAuthorized();

    error ResourceApprovalMissing();
    error EmptyFundingTarget();
    error EmptyContribution();
    error FundingRoundAlreadyActive();
    error NoActiveFundingRound();
    error FundingRoundNotOpen();
    error FundingRoundNotFunded();
    error FundingRoundNotRefundable();
    error FundingRoundAlreadyRefunded();
    error NoContributionToRefund();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event CollectiveNFTSet(address indexed nft, address indexed executor);
    event CityRegistrySet(address indexed registry, address indexed executor);
    event CityLandSet(address indexed land, address indexed executor);
    event ResourceTokenSet(address indexed token, address indexed executor);
    event StatusHookSet(address indexed hook, address indexed executor);
    event CustodyHolderSet(address indexed custodyHolder, address indexed executor);

    event PortalContractSet(address indexed portalContract, address indexed executor);
    event DungeonContractSet(address indexed dungeonContract, address indexed executor);
    event RewardRouterSet(address indexed rewardRouter, address indexed executor);
    event PermitRegistrySet(address indexed permitRegistry, address indexed executor);

    event CityGovernanceRoleSet(
        address indexed account,
        CollectiveBuildingTypes.CollectiveGovernanceRole role,
        address indexed executor
    );

    event NexusCampaignStarted(
        uint256 indexed tokenId,
        uint256 indexed campaignId,
        uint256 indexed plotId,
        CollectiveBuildingTypes.NexusBuildingKind kind,
        address starter,
        address custodyHolder
    );

    event NexusFundingRoundOpened(
        uint256 indexed tokenId,
        uint256 indexed roundId,
        bool indexed isUpgrade,
        uint8 targetLevel,
        address executor,
        uint64 openedAt
    );

    event NexusContributionReceived(
        uint256 indexed tokenId,
        uint256 indexed roundId,
        address indexed contributor,
        uint32 contributorCountAfter
    );

    event NexusFundingRoundFunded(
        uint256 indexed tokenId,
        uint256 indexed roundId,
        bool indexed isUpgrade,
        uint8 targetLevel,
        uint64 fundedAt
    );

    event NexusFundingRoundCancelled(
        uint256 indexed tokenId,
        uint256 indexed roundId,
        address indexed executor,
        uint64 cancelledAt
    );

    event NexusFundingRoundFailed(
        uint256 indexed tokenId,
        uint256 indexed roundId,
        address indexed executor,
        uint64 failedAt
    );

    event NexusFundingRefundClaimed(
        uint256 indexed tokenId,
        uint256 indexed roundId,
        address indexed contributor
    );

    event NexusBuildingActivated(
        uint256 indexed tokenId,
        uint256 indexed roundId,
        uint256 indexed plotId,
        CollectiveBuildingTypes.NexusBuildingKind kind,
        address executor,
        uint64 activatedAt
    );

    event NexusUpgradeFinalized(
        uint256 indexed tokenId,
        uint256 indexed roundId,
        uint8 oldLevel,
        uint8 newLevel,
        address indexed executor,
        uint64 finalizedAt
    );

    event NexusBranchSelected(
        uint256 indexed tokenId,
        CollectiveBuildingTypes.NexusBuildingBranch indexed branch,
        address indexed executor
    );

    event NexusSeasonShifted(
        uint32 indexed seasonId,
        uint8 outerworldTier,
        uint8 dungeonTier,
        address indexed executor,
        uint64 shiftedAt
    );

    event NexusEmergencySealSet(
        bool active,
        address indexed executor,
        uint64 updatedAt
    );

    event NexusWorldBossWindowSet(
        bool active,
        address indexed executor,
        uint64 updatedAt
    );

    event NexusMetricsSynced(
        uint32 activeRouteCount,
        uint32 hiddenRouteCount,
        uint32 activeDungeonCount,
        uint32 cityStabilityBps,
        uint32 cityInstabilityBps,
        address indexed executor,
        uint64 updatedAt
    );

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    ICollectiveBuildingNFTV1Nexus public collectiveNFT;
    ICityRegistryNexusRead public cityRegistry;
    ICityLand public cityLand;
    IResourceToken public resourceToken;
    INexusStatusTouchHook public statusHook;

    /// @notice Optional external custody / collection contract.
    /// @dev If zero, the NexusBuildings contract custodies the NFTs itself.
    address public custodyHolder;

    address public portalContract;
    address public dungeonContract;
    address public rewardRouter;
    address public permitRegistry;

    uint256 public nextCampaignId = 1;

    struct NexusBuildingRecord {
        uint256 tokenId;
        CollectiveBuildingTypes.NexusBuildingKind kind;
        uint256 plotId;
        uint256 creationCampaignId;
        address campaignStarter;
        bool exists;
        bool active;
        bool portalRelevant;
        bool dungeonRelevant;
    }

    struct NexusFundingRound {
        uint256 roundId;
        bool exists;
        bool isUpgrade;
        uint8 targetLevel;
        CollectiveBuildingTypes.CollectiveFundingLedger ledger;
    }

    struct NexusFundingRoundView {
        uint256 roundId;
        bool exists;
        bool isUpgrade;
        uint8 targetLevel;
        CollectiveBuildingTypes.CollectiveCampaignState campaignState;
        uint32 contributorCount;
        uint64 campaignOpenedAt;
        uint64 campaignClosedAt;
        uint64 fundedAt;
        uint64 activatedAt;
        uint256[10] targetAmounts;
        uint256[10] raisedAmounts;
    }

    mapping(uint256 => NexusBuildingRecord) public buildingByTokenId;
    mapping(uint256 => uint256) public tokenIdByPlotId;
    mapping(uint8 => uint256) public tokenIdByKind;

    mapping(uint256 => uint256) public activeRoundIdOf;
    mapping(uint256 => uint256) public nextRoundIdOf;
    mapping(uint256 => uint256) public lastRoundIdOf;

    mapping(uint256 => mapping(uint256 => NexusFundingRound)) private _roundOfToken;
    mapping(uint256 => mapping(uint256 => mapping(address => uint256[10]))) private _contributionOf;
    mapping(uint256 => mapping(uint256 => mapping(address => bool))) private _refundClaimed;
    mapping(uint256 => mapping(uint256 => mapping(address => bool))) private _isContributorInRound;

    mapping(address => CollectiveBuildingTypes.CollectiveGovernanceRole)
        public governanceRoleOfMember;

    NexusTypes.NexusGlobalState private _globalState;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address collectiveNFT_,
        address cityRegistry_,
        address cityLand_,
        address resourceToken_,
        address statusHook_,
        address admin_
    ) {
        if (admin_ == address(0)) revert ZeroAddress();
        if (collectiveNFT_ == address(0)) revert ZeroAddress();
        if (cityRegistry_ == address(0)) revert ZeroAddress();
        if (cityLand_ == address(0)) revert ZeroAddress();
        if (resourceToken_ == address(0)) revert ZeroAddress();

        if (collectiveNFT_.code.length == 0) revert InvalidCollectiveNFT();
        if (cityRegistry_.code.length == 0) revert InvalidCityRegistry();
        if (cityLand_.code.length == 0) revert InvalidCityLand();
        if (resourceToken_.code.length == 0) revert InvalidResourceToken();
        if (statusHook_ != address(0) && statusHook_.code.length == 0) {
            revert InvalidStatusHook();
        }

        collectiveNFT = ICollectiveBuildingNFTV1Nexus(collectiveNFT_);
        cityRegistry = ICityRegistryNexusRead(cityRegistry_);
        cityLand = ICityLand(cityLand_);
        resourceToken = IResourceToken(resourceToken_);
        statusHook = INexusStatusTouchHook(statusHook_);

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(NEXUS_ADMIN_ROLE, admin_);
        _grantRole(NEXUS_OPERATOR_ROLE, admin_);
        _grantRole(NEXUS_ROLE_SETTER_ROLE, admin_);
        _grantRole(CUSTODY_MANAGER_ROLE, admin_);
        _grantRole(NEXUS_SYSTEM_ROLE, admin_);

        _globalState.versionTag = CityBuildingTypes.VERSION_TAG_V1;
    }

    /*//////////////////////////////////////////////////////////////
                                  ADMIN
    //////////////////////////////////////////////////////////////*/

    function pause() external onlyRole(NEXUS_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(NEXUS_ADMIN_ROLE) {
        _unpause();
    }

    function setCollectiveNFT(address collectiveNFT_) external onlyRole(NEXUS_ADMIN_ROLE) {
        if (collectiveNFT_ == address(0)) revert ZeroAddress();
        if (collectiveNFT_.code.length == 0) revert InvalidCollectiveNFT();

        collectiveNFT = ICollectiveBuildingNFTV1Nexus(collectiveNFT_);
        emit CollectiveNFTSet(collectiveNFT_, msg.sender);
    }

    function setCityRegistry(address cityRegistry_) external onlyRole(NEXUS_ADMIN_ROLE) {
        if (cityRegistry_ == address(0)) revert ZeroAddress();
        if (cityRegistry_.code.length == 0) revert InvalidCityRegistry();

        cityRegistry = ICityRegistryNexusRead(cityRegistry_);
        emit CityRegistrySet(cityRegistry_, msg.sender);
    }

    function setCityLand(address cityLand_) external onlyRole(NEXUS_ADMIN_ROLE) {
        if (cityLand_ == address(0)) revert ZeroAddress();
        if (cityLand_.code.length == 0) revert InvalidCityLand();

        cityLand = ICityLand(cityLand_);
        emit CityLandSet(cityLand_, msg.sender);
    }

    function setResourceToken(address resourceToken_) external onlyRole(NEXUS_ADMIN_ROLE) {
        if (resourceToken_ == address(0)) revert ZeroAddress();
        if (resourceToken_.code.length == 0) revert InvalidResourceToken();

        resourceToken = IResourceToken(resourceToken_);
        emit ResourceTokenSet(resourceToken_, msg.sender);
    }

    function setStatusHook(address statusHook_) external onlyRole(NEXUS_ADMIN_ROLE) {
        if (statusHook_ == address(0)) {
            statusHook = INexusStatusTouchHook(address(0));
        } else {
            if (statusHook_.code.length == 0) revert InvalidStatusHook();
            statusHook = INexusStatusTouchHook(statusHook_);
        }

        emit StatusHookSet(statusHook_, msg.sender);
    }

    function setCustodyHolder(address custodyHolder_) external onlyRole(CUSTODY_MANAGER_ROLE) {
        if (custodyHolder_ != address(0) && custodyHolder_.code.length == 0) {
            revert InvalidSystemContract();
        }

        custodyHolder = custodyHolder_;
        emit CustodyHolderSet(custodyHolder_, msg.sender);
    }

    function setPortalContract(address portalContract_) external onlyRole(NEXUS_ADMIN_ROLE) {
        if (portalContract_ != address(0) && portalContract_.code.length == 0) {
            revert InvalidSystemContract();
        }

        portalContract = portalContract_;
        emit PortalContractSet(portalContract_, msg.sender);
    }

    function setDungeonContract(address dungeonContract_) external onlyRole(NEXUS_ADMIN_ROLE) {
        if (dungeonContract_ != address(0) && dungeonContract_.code.length == 0) {
            revert InvalidSystemContract();
        }

        dungeonContract = dungeonContract_;
        emit DungeonContractSet(dungeonContract_, msg.sender);
    }

    function setRewardRouter(address rewardRouter_) external onlyRole(NEXUS_ADMIN_ROLE) {
        if (rewardRouter_ != address(0) && rewardRouter_.code.length == 0) {
            revert InvalidSystemContract();
        }

        rewardRouter = rewardRouter_;
        emit RewardRouterSet(rewardRouter_, msg.sender);
    }

    function setPermitRegistry(address permitRegistry_) external onlyRole(NEXUS_ADMIN_ROLE) {
        if (permitRegistry_ != address(0) && permitRegistry_.code.length == 0) {
            revert InvalidSystemContract();
        }

        permitRegistry = permitRegistry_;
        emit PermitRegistrySet(permitRegistry_, msg.sender);
    }

    function setCityGovernanceRole(
        address account,
        CollectiveBuildingTypes.CollectiveGovernanceRole role
    ) external onlyRole(NEXUS_ROLE_SETTER_ROLE) {
        if (account == address(0)) revert ZeroAddress();

        if (role != CollectiveBuildingTypes.CollectiveGovernanceRole.None) {
            if (!cityRegistry.hasCityKeyOf(account)) revert NoCityKey();
        }

        governanceRoleOfMember[account] = role;

        emit CityGovernanceRoleSet(
            account,
            role,
            msg.sender
        );
    }

    function setSeasonShift(
        uint32 seasonId,
        uint8 outerworldTier,
        uint8 dungeonTier
    ) external whenNotPaused {
        _requireStewardOrOperator(msg.sender);
        if (outerworldTier > CollectiveBuildingTypes.MAX_COLLECTIVE_LEVEL) revert InvalidTier();
        if (dungeonTier > CollectiveBuildingTypes.MAX_COLLECTIVE_LEVEL) revert InvalidTier();
        if (
            _globalState.seasonId == seasonId &&
            _globalState.outerworldTier == outerworldTier &&
            _globalState.dungeonTier == dungeonTier
        ) revert NoStateChange();

        _globalState.seasonId = seasonId;
        _globalState.outerworldTier = outerworldTier;
        _globalState.dungeonTier = dungeonTier;
        _globalState.lastSeasonShiftAt = uint64(block.timestamp);

        emit NexusSeasonShifted(
            seasonId,
            outerworldTier,
            dungeonTier,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    function setEmergencySealActive(bool active) external whenNotPaused {
        _requireDefenderOrStewardOrOperator(msg.sender);
        if (_globalState.emergencySealActive == active) revert NoStateChange();

        _globalState.emergencySealActive = active;
        _globalState.lastEmergencyActionAt = uint64(block.timestamp);

        emit NexusEmergencySealSet(
            active,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    function setWorldBossWindowOpen(bool active) external whenNotPaused {
        _requireArchivistOrStewardOrOperator(msg.sender);
        if (_globalState.worldBossWindowOpen == active) revert NoStateChange();

        _globalState.worldBossWindowOpen = active;

        emit NexusWorldBossWindowSet(
            active,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    function syncNexusMetrics(
        uint32 activeRouteCount,
        uint32 hiddenRouteCount,
        uint32 activeDungeonCount,
        uint32 cityStabilityBps,
        uint32 cityInstabilityBps
    ) external onlyRole(NEXUS_SYSTEM_ROLE) whenNotPaused {
        if (cityStabilityBps > 10_000 || cityInstabilityBps > 10_000) revert InvalidBps();

        _globalState.activeRouteCount = activeRouteCount;
        _globalState.hiddenRouteCount = hiddenRouteCount;
        _globalState.activeDungeonCount = activeDungeonCount;
        _globalState.cityStabilityBps = cityStabilityBps;
        _globalState.cityInstabilityBps = cityInstabilityBps;

        emit NexusMetricsSynced(
            activeRouteCount,
            hiddenRouteCount,
            activeDungeonCount,
            cityStabilityBps,
            cityInstabilityBps,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    /*//////////////////////////////////////////////////////////////
                         NEXUS CAMPAIGN FLOW
    //////////////////////////////////////////////////////////////*/

    function startNexusBuildingCampaign(
        uint256 plotId,
        CollectiveBuildingTypes.NexusBuildingKind kind,
        uint256[10] calldata targetAmounts,
        uint32 versionTag
    ) external whenNotPaused nonReentrant returns (uint256 tokenId) {
        if (!CollectiveBuildingTypes.isValidNexusKind(kind)) revert InvalidNexusKind();

        _requireNexusPlotReady(plotId);
        _requireStewardOrBuilder(msg.sender);
        _requireNonEmptyFundingTarget(targetAmounts);

        if (tokenIdByPlotId[plotId] != 0) revert BuildingAlreadyExistsOnPlot();
        if (tokenIdByKind[uint8(kind)] != 0) revert NexusKindAlreadyExists();

        uint32 effectiveVersionTag = versionTag == 0
            ? CityBuildingTypes.VERSION_TAG_V1
            : versionTag;
        if (
            effectiveVersionTag != CityBuildingTypes.VERSION_TAG_V1 &&
            effectiveVersionTag != CityBuildingTypes.VERSION_TAG_V2
        ) revert InvalidVersionTag();

        uint256 campaignId = nextCampaignId++;
        address resolvedCustody = _resolvedCustodyHolder();

        tokenId = collectiveNFT.mintNexusBuilding(
            resolvedCustody,
            kind,
            plotId,
            campaignId,
            CollectiveBuildingTypes.CollectiveCustodyMode.CityCustodied,
            effectiveVersionTag
        );

        buildingByTokenId[tokenId] = NexusBuildingRecord({
            tokenId: tokenId,
            kind: kind,
            plotId: plotId,
            creationCampaignId: campaignId,
            campaignStarter: msg.sender,
            exists: true,
            active: false,
            portalRelevant: _isPortalRelevant(kind),
            dungeonRelevant: _isDungeonRelevant(kind)
        });

        tokenIdByPlotId[plotId] = tokenId;
        tokenIdByKind[uint8(kind)] = tokenId;

        nextRoundIdOf[tokenId] = 2;
        activeRoundIdOf[tokenId] = 1;
        lastRoundIdOf[tokenId] = 1;

        NexusFundingRound storage round = _roundOfToken[tokenId][1];
        round.roundId = 1;
        round.exists = true;
        round.isUpgrade = false;
        round.targetLevel = 1;
        round.ledger.targetAmounts = targetAmounts;
        round.ledger.campaignState = CollectiveBuildingTypes.CollectiveCampaignState.Funding;
        round.ledger.campaignOpenedAt = uint64(block.timestamp);

        emit NexusCampaignStarted(
            tokenId,
            campaignId,
            plotId,
            kind,
            msg.sender,
            resolvedCustody
        );

        emit NexusFundingRoundOpened(
            tokenId,
            1,
            false,
            1,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    function reopenInitialFundingRound(
        uint256 tokenId,
        uint256[10] calldata targetAmounts
    ) external whenNotPaused nonReentrant {
        NexusBuildingRecord memory record = _requireNexusBuilding(tokenId);
        _requireStewardOrBuilder(msg.sender);

        if (record.active) revert NoStateChange();
        if (activeRoundIdOf[tokenId] != 0) revert FundingRoundAlreadyActive();

        _requireNonEmptyFundingTarget(targetAmounts);

        uint256 roundId = nextRoundIdOf[tokenId];
        if (roundId == 0) roundId = 1;
        nextRoundIdOf[tokenId] = roundId + 1;
        activeRoundIdOf[tokenId] = roundId;
        lastRoundIdOf[tokenId] = roundId;

        NexusFundingRound storage round = _roundOfToken[tokenId][roundId];
        round.roundId = roundId;
        round.exists = true;
        round.isUpgrade = false;
        round.targetLevel = 1;
        round.ledger.targetAmounts = targetAmounts;
        round.ledger.campaignState = CollectiveBuildingTypes.CollectiveCampaignState.Funding;
        round.ledger.campaignOpenedAt = uint64(block.timestamp);

        emit NexusFundingRoundOpened(
            tokenId,
            roundId,
            false,
            1,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    function contributeToFundingRound(
        uint256 tokenId,
        uint256[10] calldata amounts
    ) external whenNotPaused nonReentrant {
        NexusBuildingRecord memory record = _requireNexusBuilding(tokenId);
        record;

        _requireCityMemberWithKey(msg.sender);

        uint256 roundId = activeRoundIdOf[tokenId];
        if (roundId == 0) revert NoActiveFundingRound();

        NexusFundingRound storage round = _roundOfToken[tokenId][roundId];
        if (round.ledger.campaignState != CollectiveBuildingTypes.CollectiveCampaignState.Funding) {
            revert FundingRoundNotOpen();
        }

        bool hasContribution;
        for (uint256 i = 0; i < 10; i++) {
            if (amounts[i] != 0) {
                hasContribution = true;
                break;
            }
        }
        if (!hasContribution) revert EmptyContribution();

        if (!resourceToken.isApprovedForAll(msg.sender, address(this))) {
            revert ResourceApprovalMissing();
        }

        if (!_isContributorInRound[tokenId][roundId][msg.sender]) {
            _isContributorInRound[tokenId][roundId][msg.sender] = true;
            round.ledger.contributorCount += 1;
        }

        for (uint256 i = 0; i < 10; i++) {
            uint256 amount = amounts[i];
            if (amount == 0) continue;

            resourceToken.safeTransferFrom(
                msg.sender,
                address(this),
                i,
                amount,
                ""
            );

            round.ledger.raisedAmounts[i] += amount;
            _contributionOf[tokenId][roundId][msg.sender][i] += amount;
        }

        emit NexusContributionReceived(
            tokenId,
            roundId,
            msg.sender,
            round.ledger.contributorCount
        );

        if (_isRoundFunded(round.ledger)) {
            round.ledger.campaignState = CollectiveBuildingTypes.CollectiveCampaignState.Funded;
            round.ledger.fundedAt = uint64(block.timestamp);

            emit NexusFundingRoundFunded(
                tokenId,
                roundId,
                round.isUpgrade,
                round.targetLevel,
                uint64(block.timestamp)
            );
        }
    }

    function cancelFundingRound(
        uint256 tokenId
    ) external whenNotPaused nonReentrant {
        NexusBuildingRecord memory record = _requireNexusBuilding(tokenId);
        _requireStewardOrBuilder(msg.sender);

        uint256 roundId = activeRoundIdOf[tokenId];
        if (roundId == 0) revert NoActiveFundingRound();

        NexusFundingRound storage round = _roundOfToken[tokenId][roundId];
        if (round.ledger.campaignState != CollectiveBuildingTypes.CollectiveCampaignState.Funding) {
            revert FundingRoundNotOpen();
        }

        round.ledger.campaignState = CollectiveBuildingTypes.CollectiveCampaignState.Cancelled;
        round.ledger.campaignClosedAt = uint64(block.timestamp);
        activeRoundIdOf[tokenId] = 0;

        if (round.isUpgrade && record.active) {
            _syncNftState(tokenId, CollectiveBuildingTypes.CollectiveBuildingState.Active);
        }

        emit NexusFundingRoundCancelled(
            tokenId,
            roundId,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    function markFundingRoundFailed(
        uint256 tokenId,
        uint256 roundId
    ) external whenNotPaused onlyRole(NEXUS_OPERATOR_ROLE) {
        NexusBuildingRecord memory record = _requireNexusBuilding(tokenId);

        NexusFundingRound storage round = _roundOfToken[tokenId][roundId];
        if (!round.exists) revert NoActiveFundingRound();
        if (round.ledger.campaignState != CollectiveBuildingTypes.CollectiveCampaignState.Funding) {
            revert FundingRoundNotOpen();
        }

        round.ledger.campaignState = CollectiveBuildingTypes.CollectiveCampaignState.Failed;
        round.ledger.campaignClosedAt = uint64(block.timestamp);

        if (activeRoundIdOf[tokenId] == roundId) {
            activeRoundIdOf[tokenId] = 0;
        }

        if (round.isUpgrade && record.active) {
            _syncNftState(tokenId, CollectiveBuildingTypes.CollectiveBuildingState.Active);
        }

        emit NexusFundingRoundFailed(
            tokenId,
            roundId,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    function claimFundingRefund(
        uint256 tokenId,
        uint256 roundId
    ) external whenNotPaused nonReentrant {
        NexusBuildingRecord memory record = _requireNexusBuilding(tokenId);
        record;

        NexusFundingRound storage round = _roundOfToken[tokenId][roundId];
        if (!round.exists) revert NoActiveFundingRound();

        if (
            round.ledger.campaignState != CollectiveBuildingTypes.CollectiveCampaignState.Failed &&
            round.ledger.campaignState != CollectiveBuildingTypes.CollectiveCampaignState.Cancelled
        ) revert FundingRoundNotRefundable();

        if (_refundClaimed[tokenId][roundId][msg.sender]) {
            revert FundingRoundAlreadyRefunded();
        }

        uint256[10] storage contribution = _contributionOf[tokenId][roundId][msg.sender];
        bool hasContribution;

        for (uint256 i = 0; i < 10; i++) {
            uint256 amount = contribution[i];
            if (amount == 0) continue;

            hasContribution = true;
            resourceToken.safeTransferFrom(
                address(this),
                msg.sender,
                i,
                amount,
                ""
            );
        }

        if (!hasContribution) revert NoContributionToRefund();

        _refundClaimed[tokenId][roundId][msg.sender] = true;

        emit NexusFundingRefundClaimed(tokenId, roundId, msg.sender);
    }

    function activateFundedNexusBuilding(
        uint256 tokenId
    ) external whenNotPaused nonReentrant {
        NexusBuildingRecord storage record = _requireNexusBuildingStorage(tokenId);
        _requireStewardOrBuilder(msg.sender);

        uint256 roundId = activeRoundIdOf[tokenId];
        if (roundId == 0) revert NoActiveFundingRound();

        NexusFundingRound storage round = _roundOfToken[tokenId][roundId];
        if (round.isUpgrade) revert FundingRoundNotFunded();
        if (round.ledger.campaignState != CollectiveBuildingTypes.CollectiveCampaignState.Funded) {
            revert FundingRoundNotFunded();
        }

        round.ledger.campaignState = CollectiveBuildingTypes.CollectiveCampaignState.Closed;
        round.ledger.campaignClosedAt = uint64(block.timestamp);
        round.ledger.activatedAt = uint64(block.timestamp);

        activeRoundIdOf[tokenId] = 0;
        record.active = true;

        _syncNftState(tokenId, CollectiveBuildingTypes.CollectiveBuildingState.Active);
        collectiveNFT.addPrestigeScore(tokenId, _activationPrestige(record.kind));
        collectiveNFT.addHistoryScore(tokenId, _activationHistory(record.kind));

        _touchStatus(record.plotId);

        emit NexusBuildingActivated(
            tokenId,
            roundId,
            record.plotId,
            record.kind,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    function openUpgradeFundingRound(
        uint256 tokenId,
        uint8 targetLevel,
        uint256[10] calldata targetAmounts
    ) external whenNotPaused nonReentrant {
        NexusBuildingRecord memory record = _requireNexusBuilding(tokenId);
        _requireStewardOrBuilder(msg.sender);

        if (!record.active) revert BuildingInactive();
        if (activeRoundIdOf[tokenId] != 0) revert FundingRoundAlreadyActive();

        CollectiveBuildingTypes.CollectiveIdentity memory id_ =
            collectiveNFT.getCollectiveIdentity(tokenId);

        if (!CollectiveBuildingTypes.isValidCollectiveLevel(targetLevel)) {
            revert InvalidTargetLevel();
        }
        if (targetLevel <= id_.level) revert InvalidTargetLevel();

        _requireNonEmptyFundingTarget(targetAmounts);

        uint256 roundId = nextRoundIdOf[tokenId];
        if (roundId == 0) roundId = 1;
        nextRoundIdOf[tokenId] = roundId + 1;
        activeRoundIdOf[tokenId] = roundId;
        lastRoundIdOf[tokenId] = roundId;

        NexusFundingRound storage round = _roundOfToken[tokenId][roundId];
        round.roundId = roundId;
        round.exists = true;
        round.isUpgrade = true;
        round.targetLevel = targetLevel;
        round.ledger.targetAmounts = targetAmounts;
        round.ledger.campaignState = CollectiveBuildingTypes.CollectiveCampaignState.Funding;
        round.ledger.campaignOpenedAt = uint64(block.timestamp);

        _syncNftState(tokenId, CollectiveBuildingTypes.CollectiveBuildingState.Upgrading);

        emit NexusFundingRoundOpened(
            tokenId,
            roundId,
            true,
            targetLevel,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    function finalizeFundedUpgrade(
        uint256 tokenId
    ) external whenNotPaused nonReentrant {
        NexusBuildingRecord memory record = _requireNexusBuilding(tokenId);
        _requireStewardOrBuilder(msg.sender);

        uint256 roundId = activeRoundIdOf[tokenId];
        if (roundId == 0) revert NoActiveFundingRound();

        NexusFundingRound storage round = _roundOfToken[tokenId][roundId];
        if (!round.isUpgrade) revert FundingRoundNotFunded();
        if (round.ledger.campaignState != CollectiveBuildingTypes.CollectiveCampaignState.Funded) {
            revert FundingRoundNotFunded();
        }

        CollectiveBuildingTypes.CollectiveIdentity memory id_ =
            collectiveNFT.getCollectiveIdentity(tokenId);

        uint8 oldLevel = id_.level;
        uint8 newLevel = round.targetLevel;

        collectiveNFT.upgradeCollectiveBuilding(tokenId, newLevel);
        collectiveNFT.addPrestigeScore(tokenId, _upgradePrestige(record.kind, newLevel));
        collectiveNFT.addHistoryScore(tokenId, _upgradeHistory(record.kind, newLevel));
        _syncNftState(tokenId, CollectiveBuildingTypes.CollectiveBuildingState.Active);

        round.ledger.campaignState = CollectiveBuildingTypes.CollectiveCampaignState.Closed;
        round.ledger.campaignClosedAt = uint64(block.timestamp);
        round.ledger.activatedAt = uint64(block.timestamp);
        activeRoundIdOf[tokenId] = 0;

        _touchStatus(record.plotId);

        emit NexusUpgradeFinalized(
            tokenId,
            roundId,
            oldLevel,
            newLevel,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    function setNexusBranch(
        uint256 tokenId,
        CollectiveBuildingTypes.NexusBuildingBranch branch
    ) external whenNotPaused nonReentrant {
        NexusBuildingRecord memory record = _requireNexusBuilding(tokenId);
        _requireStewardOrBuilder(msg.sender);
        record;

        CollectiveBuildingTypes.CollectiveIdentity memory id_ =
            collectiveNFT.getCollectiveIdentity(tokenId);

        if (
            !CollectiveBuildingTypes.canChooseNexusBranch(
                id_.nexusKind,
                id_.level,
                branch
            )
        ) revert InvalidNexusBranch();

        collectiveNFT.setNexusBranch(tokenId, branch);
        collectiveNFT.addHistoryScore(tokenId, 5);

        emit NexusBranchSelected(tokenId, branch, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                                  READS
    //////////////////////////////////////////////////////////////*/

    function getNexusBuildingRecord(
        uint256 tokenId
    ) external view returns (NexusBuildingRecord memory) {
        return _requireNexusBuilding(tokenId);
    }

    function getFundingRound(
        uint256 tokenId,
        uint256 roundId
    ) external view returns (NexusFundingRoundView memory v) {
        NexusFundingRound storage round = _roundOfToken[tokenId][roundId];

        v.roundId = round.roundId;
        v.exists = round.exists;
        v.isUpgrade = round.isUpgrade;
        v.targetLevel = round.targetLevel;
        v.campaignState = round.ledger.campaignState;
        v.contributorCount = round.ledger.contributorCount;
        v.campaignOpenedAt = round.ledger.campaignOpenedAt;
        v.campaignClosedAt = round.ledger.campaignClosedAt;
        v.fundedAt = round.ledger.fundedAt;
        v.activatedAt = round.ledger.activatedAt;
        v.targetAmounts = round.ledger.targetAmounts;
        v.raisedAmounts = round.ledger.raisedAmounts;
    }

    function getCurrentFundingRoundId(
        uint256 tokenId
    ) external view returns (uint256) {
        return activeRoundIdOf[tokenId];
    }

    function getContributionOf(
        uint256 tokenId,
        uint256 roundId,
        address contributor
    )
        external
        view
        returns (
            uint256[10] memory amounts,
            bool refunded,
            bool countedAsContributor
        )
    {
        amounts = _contributionOf[tokenId][roundId][contributor];
        refunded = _refundClaimed[tokenId][roundId][contributor];
        countedAsContributor = _isContributorInRound[tokenId][roundId][contributor];
    }

    function getCityGovernanceRole(
        address account
    ) external view returns (CollectiveBuildingTypes.CollectiveGovernanceRole) {
        return governanceRoleOfMember[account];
    }

    function isCityMemberEligible(
        address account
    ) external view returns (bool) {
        return cityRegistry.hasCityKeyOf(account);
    }

    function getTokenIdForKind(
        CollectiveBuildingTypes.NexusBuildingKind kind
    ) external view returns (uint256) {
        return tokenIdByKind[uint8(kind)];
    }

    function kindIsActive(
        CollectiveBuildingTypes.NexusBuildingKind kind
    ) external view returns (bool) {
        uint256 tokenId = tokenIdByKind[uint8(kind)];
        if (tokenId == 0) return false;
        return buildingByTokenId[tokenId].active;
    }

    function getNexusGlobalState()
        external
        view
        returns (NexusTypes.NexusGlobalState memory)
    {
        return _globalState;
    }

    function getLinkedSystems()
        external
        view
        returns (
            address portalContract_,
            address dungeonContract_,
            address rewardRouter_,
            address permitRegistry_
        )
    {
        return (portalContract, dungeonContract, rewardRouter, permitRegistry);
    }

    function resolvedCustodyHolder() external view returns (address) {
        return _resolvedCustodyHolder();
    }

    /*//////////////////////////////////////////////////////////////
                               INTERNALS
    //////////////////////////////////////////////////////////////*/

    function _requireNexusBuilding(
        uint256 tokenId
    ) internal view returns (NexusBuildingRecord memory record) {
        record = buildingByTokenId[tokenId];
        if (!record.exists) revert NexusBuildingNotFound();
    }

    function _requireNexusBuildingStorage(
        uint256 tokenId
    ) internal view returns (NexusBuildingRecord storage record) {
        record = buildingByTokenId[tokenId];
        if (!record.exists) revert NexusBuildingNotFound();
    }

    function _requireNexusPlotReady(uint256 plotId) internal view {
        if (plotId == 0) revert InvalidPlot();

        CityTypes.PlotCore memory plot = cityRegistry.getPlotCore(plotId);
        if (plot.plotType != CityTypes.PlotType.Nexus) revert InvalidPlotType();
        if (!cityLand.isPlotFullyCompleted(plotId)) revert PlotNotCompleted();
    }

    function _requireCityMemberWithKey(address account) internal view {
        if (!cityRegistry.hasCityKeyOf(account)) revert NoCityKey();
    }

    function _requireStewardOrBuilder(address account) internal view {
        if (_isAdminOrOperator(account)) return;

        if (!cityRegistry.hasCityKeyOf(account)) revert NoCityKey();

        CollectiveBuildingTypes.CollectiveGovernanceRole role = governanceRoleOfMember[account];
        if (
            role != CollectiveBuildingTypes.CollectiveGovernanceRole.Steward &&
            role != CollectiveBuildingTypes.CollectiveGovernanceRole.Builder
        ) revert NotCityAuthorized();
    }

    function _requireStewardOrOperator(address account) internal view {
        if (_isAdminOrOperator(account)) return;

        if (!cityRegistry.hasCityKeyOf(account)) revert NoCityKey();

        CollectiveBuildingTypes.CollectiveGovernanceRole role = governanceRoleOfMember[account];
        if (role != CollectiveBuildingTypes.CollectiveGovernanceRole.Steward) {
            revert NotCityAuthorized();
        }
    }

    function _requireDefenderOrStewardOrOperator(address account) internal view {
        if (_isAdminOrOperator(account)) return;

        if (!cityRegistry.hasCityKeyOf(account)) revert NoCityKey();

        CollectiveBuildingTypes.CollectiveGovernanceRole role = governanceRoleOfMember[account];
        if (
            role != CollectiveBuildingTypes.CollectiveGovernanceRole.Steward &&
            role != CollectiveBuildingTypes.CollectiveGovernanceRole.Defender
        ) revert NotCityAuthorized();
    }

    function _requireArchivistOrStewardOrOperator(address account) internal view {
        if (_isAdminOrOperator(account)) return;

        if (!cityRegistry.hasCityKeyOf(account)) revert NoCityKey();

        CollectiveBuildingTypes.CollectiveGovernanceRole role = governanceRoleOfMember[account];
        if (
            role != CollectiveBuildingTypes.CollectiveGovernanceRole.Steward &&
            role != CollectiveBuildingTypes.CollectiveGovernanceRole.Archivist
        ) revert NotCityAuthorized();
    }

    function _isAdminOrOperator(address account) internal view returns (bool) {
        return
            hasRole(NEXUS_ADMIN_ROLE, account) ||
            hasRole(NEXUS_OPERATOR_ROLE, account) ||
            hasRole(DEFAULT_ADMIN_ROLE, account);
    }

    function _requireNonEmptyFundingTarget(
        uint256[10] calldata targetAmounts
    ) internal pure {
        for (uint256 i = 0; i < 10; i++) {
            if (targetAmounts[i] != 0) {
                return;
            }
        }
        revert EmptyFundingTarget();
    }

    function _isRoundFunded(
        CollectiveBuildingTypes.CollectiveFundingLedger storage ledger
    ) internal view returns (bool) {
        for (uint256 i = 0; i < 10; i++) {
            if (ledger.raisedAmounts[i] < ledger.targetAmounts[i]) {
                return false;
            }
        }
        return true;
    }

    function _resolvedCustodyHolder() internal view returns (address) {
        return custodyHolder == address(0) ? address(this) : custodyHolder;
    }

    function _touchStatus(uint256 plotId) internal {
        if (address(statusHook) == address(0)) return;
        if (plotId == 0) return;

        statusHook.touchActivity(plotId);
    }

    function _syncNftState(
        uint256 tokenId,
        CollectiveBuildingTypes.CollectiveBuildingState desiredState
    ) internal {
        if (collectiveNFT.getCollectiveState(tokenId) != desiredState) {
            collectiveNFT.setCollectiveState(tokenId, desiredState);
        }
    }

    function _isPortalRelevant(
        CollectiveBuildingTypes.NexusBuildingKind kind
    ) internal pure returns (bool) {
        return
            kind == CollectiveBuildingTypes.NexusBuildingKind.NexusCore ||
            kind == CollectiveBuildingTypes.NexusBuildingKind.NexusSignalSpire ||
            kind == CollectiveBuildingTypes.NexusBuildingKind.NexusArchive ||
            kind == CollectiveBuildingTypes.NexusBuildingKind.NexusExchangeHub;
    }

    function _isDungeonRelevant(
        CollectiveBuildingTypes.NexusBuildingKind kind
    ) internal pure returns (bool) {
        return
            kind == CollectiveBuildingTypes.NexusBuildingKind.NexusCore ||
            kind == CollectiveBuildingTypes.NexusBuildingKind.NexusSignalSpire ||
            kind == CollectiveBuildingTypes.NexusBuildingKind.NexusArchive ||
            kind == CollectiveBuildingTypes.NexusBuildingKind.NexusExchangeHub;
    }

    function _activationPrestige(
        CollectiveBuildingTypes.NexusBuildingKind kind
    ) internal pure returns (uint32) {
        if (kind == CollectiveBuildingTypes.NexusBuildingKind.NexusCore) return 40;
        if (kind == CollectiveBuildingTypes.NexusBuildingKind.NexusSignalSpire) return 30;
        if (kind == CollectiveBuildingTypes.NexusBuildingKind.NexusArchive) return 35;
        if (kind == CollectiveBuildingTypes.NexusBuildingKind.NexusExchangeHub) return 30;
        return 25;
    }

    function _activationHistory(
        CollectiveBuildingTypes.NexusBuildingKind kind
    ) internal pure returns (uint32) {
        if (kind == CollectiveBuildingTypes.NexusBuildingKind.NexusCore) return 40;
        if (kind == CollectiveBuildingTypes.NexusBuildingKind.NexusSignalSpire) return 28;
        if (kind == CollectiveBuildingTypes.NexusBuildingKind.NexusArchive) return 35;
        if (kind == CollectiveBuildingTypes.NexusBuildingKind.NexusExchangeHub) return 26;
        return 20;
    }

    function _upgradePrestige(
        CollectiveBuildingTypes.NexusBuildingKind kind,
        uint8 newLevel
    ) internal pure returns (uint32) {
        uint32 base = uint32(newLevel) * 12;

        if (kind == CollectiveBuildingTypes.NexusBuildingKind.NexusCore) return base + 8;
        if (kind == CollectiveBuildingTypes.NexusBuildingKind.NexusArchive) return base + 4;
        return base;
    }

    function _upgradeHistory(
        CollectiveBuildingTypes.NexusBuildingKind kind,
        uint8 newLevel
    ) internal pure returns (uint32) {
        uint32 base = uint32(newLevel) * 9;

        if (kind == CollectiveBuildingTypes.NexusBuildingKind.NexusSignalSpire) return base + 4;
        if (kind == CollectiveBuildingTypes.NexusBuildingKind.NexusArchive) return base + 6;
        return base;
    }

    /*//////////////////////////////////////////////////////////////
                           INTERFACE SUPPORT
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(AccessControl, ERC1155Holder) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}