/* FILE: contracts/city/contracts/buildings/CommunityBuildings.sol */
/* TYPE: community buildings orchestrator / faction crowdfunding / custody layer — NOT PersonalBuildings */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import "../libraries/CityTypes.sol";
import "../libraries/CollectiveBuildingTypes.sol";
import "../interfaces/IResourceToken.sol";
import "../interfaces/ICityLand.sol";

/*//////////////////////////////////////////////////////////////
                        EXTERNAL INTERFACES
//////////////////////////////////////////////////////////////*/

interface ICollectiveBuildingNFTV1Community {
    function mintCommunityBuilding(
        address custodyHolder,
        CollectiveBuildingTypes.CommunityBuildingKind kind,
        uint8 faction,
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

    function setCommunityBranch(
        uint256 tokenId,
        CollectiveBuildingTypes.CommunityBuildingBranch newBranch
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

interface ICityRegistryCommunityRead {
    function hasCityKeyOf(address user) external view returns (bool);

    function chosenFactionOf(address user) external view returns (CityTypes.Faction);

    function getPlotCore(
        uint256 plotId
    ) external view returns (CityTypes.PlotCore memory);
}

interface ICityStatusTouchHook {
    function touchActivity(uint256 plotId) external;
}

/*//////////////////////////////////////////////////////////////
                         COMMUNITY BUILDINGS
//////////////////////////////////////////////////////////////*/

contract CommunityBuildings is
    AccessControl,
    Pausable,
    ReentrancyGuard,
    ERC1155Holder,
    ERC721Holder
{
    /*//////////////////////////////////////////////////////////////
                                 ROLES
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant COMMUNITY_ADMIN_ROLE = keccak256("COMMUNITY_ADMIN_ROLE");
    bytes32 public constant COMMUNITY_OPERATOR_ROLE = keccak256("COMMUNITY_OPERATOR_ROLE");
    bytes32 public constant FACTION_ROLE_SETTER_ROLE = keccak256("FACTION_ROLE_SETTER_ROLE");
    bytes32 public constant CUSTODY_MANAGER_ROLE = keccak256("CUSTODY_MANAGER_ROLE");

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error InvalidCollectiveNFT();
    error InvalidCityRegistry();
    error InvalidCityLand();
    error InvalidResourceToken();
    error InvalidStatusHook();

    error InvalidFaction();
    error InvalidPlot();
    error InvalidPlotType();
    error PlotNotCompleted();
    error BuildingAlreadyExistsOnPlot();
    error CommunityBuildingNotFound();

    error InvalidCommunityKind();
    error InvalidCommunityBranch();
    error InvalidVersionTag();
    error InvalidTargetLevel();
    error NoStateChange();

    error NotFactionMember();
    error NotFactionAuthorized();
    error NoCityKey();

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

    event FactionGovernanceRoleSet(
        uint8 indexed faction,
        address indexed account,
        CollectiveBuildingTypes.CollectiveGovernanceRole role,
        address indexed executor
    );

    event CommunityCampaignStarted(
        uint256 indexed tokenId,
        uint256 indexed campaignId,
        uint256 indexed plotId,
        CollectiveBuildingTypes.CommunityBuildingKind kind,
        uint8 faction,
        address starter,
        address custodyHolder
    );

    event CommunityFundingRoundOpened(
        uint256 indexed tokenId,
        uint256 indexed roundId,
        bool indexed isUpgrade,
        uint8 targetLevel,
        address executor,
        uint64 openedAt
    );

    event CommunityContributionReceived(
        uint256 indexed tokenId,
        uint256 indexed roundId,
        address indexed contributor,
        uint32 contributorCountAfter
    );

    event CommunityFundingRoundFunded(
        uint256 indexed tokenId,
        uint256 indexed roundId,
        bool indexed isUpgrade,
        uint8 targetLevel,
        uint64 fundedAt
    );

    event CommunityFundingRoundCancelled(
        uint256 indexed tokenId,
        uint256 indexed roundId,
        address indexed executor,
        uint64 cancelledAt
    );

    event CommunityFundingRoundFailed(
        uint256 indexed tokenId,
        uint256 indexed roundId,
        address indexed executor,
        uint64 failedAt
    );

    event CommunityFundingRefundClaimed(
        uint256 indexed tokenId,
        uint256 indexed roundId,
        address indexed contributor
    );

    event CommunityBuildingActivated(
        uint256 indexed tokenId,
        uint256 indexed roundId,
        uint256 indexed plotId,
        uint8 faction,
        address executor,
        uint64 activatedAt
    );

    event CommunityUpgradeFinalized(
        uint256 indexed tokenId,
        uint256 indexed roundId,
        uint8 oldLevel,
        uint8 newLevel,
        address indexed executor,
        uint64 finalizedAt
    );

    event CommunityBranchSelected(
        uint256 indexed tokenId,
        CollectiveBuildingTypes.CommunityBuildingBranch indexed branch,
        address indexed executor
    );

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    ICollectiveBuildingNFTV1Community public collectiveNFT;
    ICityRegistryCommunityRead public cityRegistry;
    ICityLand public cityLand;
    IResourceToken public resourceToken;
    ICityStatusTouchHook public statusHook;

    /// @notice Optional external custody / collection contract.
    /// @dev If zero, the CommunityBuildings contract custodies the NFTs itself.
    address public custodyHolder;

    uint256 public nextCampaignId = 1;

    struct CommunityBuildingRecord {
        uint256 tokenId;
        CollectiveBuildingTypes.CommunityBuildingKind kind;
        uint8 faction;
        uint256 plotId;
        uint256 creationCampaignId;
        address campaignStarter;
        bool exists;
        bool active;
    }

    struct CommunityFundingRound {
        uint256 roundId;
        bool exists;
        bool isUpgrade;
        uint8 targetLevel;
        CollectiveBuildingTypes.CollectiveFundingLedger ledger;
    }

    struct CommunityFundingRoundView {
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

    mapping(uint256 => CommunityBuildingRecord) public buildingByTokenId;
    mapping(uint256 => uint256) public tokenIdByPlotId;

    mapping(uint256 => uint256) public activeRoundIdOf;
    mapping(uint256 => uint256) public nextRoundIdOf;
    mapping(uint256 => uint256) public lastRoundIdOf;

    mapping(uint256 => mapping(uint256 => CommunityFundingRound)) private _roundOfToken;
    mapping(uint256 => mapping(uint256 => mapping(address => uint256[10]))) private _contributionOf;
    mapping(uint256 => mapping(uint256 => mapping(address => bool))) private _refundClaimed;
    mapping(uint256 => mapping(uint256 => mapping(address => bool))) private _isContributorInRound;

    mapping(uint8 => mapping(address => CollectiveBuildingTypes.CollectiveGovernanceRole))
        public governanceRoleOfFactionMember;

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
        if (statusHook_ != address(0) && statusHook_.code.length == 0) revert InvalidStatusHook();

        collectiveNFT = ICollectiveBuildingNFTV1Community(collectiveNFT_);
        cityRegistry = ICityRegistryCommunityRead(cityRegistry_);
        cityLand = ICityLand(cityLand_);
        resourceToken = IResourceToken(resourceToken_);
        statusHook = ICityStatusTouchHook(statusHook_);

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(COMMUNITY_ADMIN_ROLE, admin_);
        _grantRole(COMMUNITY_OPERATOR_ROLE, admin_);
        _grantRole(FACTION_ROLE_SETTER_ROLE, admin_);
        _grantRole(CUSTODY_MANAGER_ROLE, admin_);
    }

    /*//////////////////////////////////////////////////////////////
                                  ADMIN
    //////////////////////////////////////////////////////////////*/

    function pause() external onlyRole(COMMUNITY_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(COMMUNITY_ADMIN_ROLE) {
        _unpause();
    }

    function setCollectiveNFT(address collectiveNFT_) external onlyRole(COMMUNITY_ADMIN_ROLE) {
        if (collectiveNFT_ == address(0)) revert ZeroAddress();
        if (collectiveNFT_.code.length == 0) revert InvalidCollectiveNFT();

        collectiveNFT = ICollectiveBuildingNFTV1Community(collectiveNFT_);
        emit CollectiveNFTSet(collectiveNFT_, msg.sender);
    }

    function setCityRegistry(address cityRegistry_) external onlyRole(COMMUNITY_ADMIN_ROLE) {
        if (cityRegistry_ == address(0)) revert ZeroAddress();
        if (cityRegistry_.code.length == 0) revert InvalidCityRegistry();

        cityRegistry = ICityRegistryCommunityRead(cityRegistry_);
        emit CityRegistrySet(cityRegistry_, msg.sender);
    }

    function setCityLand(address cityLand_) external onlyRole(COMMUNITY_ADMIN_ROLE) {
        if (cityLand_ == address(0)) revert ZeroAddress();
        if (cityLand_.code.length == 0) revert InvalidCityLand();

        cityLand = ICityLand(cityLand_);
        emit CityLandSet(cityLand_, msg.sender);
    }

    function setResourceToken(address resourceToken_) external onlyRole(COMMUNITY_ADMIN_ROLE) {
        if (resourceToken_ == address(0)) revert ZeroAddress();
        if (resourceToken_.code.length == 0) revert InvalidResourceToken();

        resourceToken = IResourceToken(resourceToken_);
        emit ResourceTokenSet(resourceToken_, msg.sender);
    }

    function setStatusHook(address statusHook_) external onlyRole(COMMUNITY_ADMIN_ROLE) {
        if (statusHook_ == address(0)) {
            statusHook = ICityStatusTouchHook(address(0));
        } else {
            if (statusHook_.code.length == 0) revert InvalidStatusHook();
            statusHook = ICityStatusTouchHook(statusHook_);
        }

        emit StatusHookSet(statusHook_, msg.sender);
    }

    function setCustodyHolder(address custodyHolder_) external onlyRole(CUSTODY_MANAGER_ROLE) {
        if (custodyHolder_ != address(0) && custodyHolder_.code.length == 0) {
            revert ZeroAddress();
        }

        custodyHolder = custodyHolder_;
        emit CustodyHolderSet(custodyHolder_, msg.sender);
    }

    function setFactionGovernanceRole(
        uint8 faction,
        address account,
        CollectiveBuildingTypes.CollectiveGovernanceRole role
    ) external onlyRole(FACTION_ROLE_SETTER_ROLE) {
        if (!_isOperationalFaction(faction)) revert InvalidFaction();
        if (account == address(0)) revert ZeroAddress();

        if (role != CollectiveBuildingTypes.CollectiveGovernanceRole.None) {
            if (!cityRegistry.hasCityKeyOf(account)) revert NoCityKey();
            if (!_isFactionMember(faction, account)) revert NotFactionMember();
        }

        governanceRoleOfFactionMember[faction][account] = role;

        emit FactionGovernanceRoleSet(
            faction,
            account,
            role,
            msg.sender
        );
    }

    /*//////////////////////////////////////////////////////////////
                        COMMUNITY CAMPAIGN FLOW
    //////////////////////////////////////////////////////////////*/

    function startCommunityBuildingCampaign(
        uint256 plotId,
        CollectiveBuildingTypes.CommunityBuildingKind kind,
        uint8 faction,
        uint256[10] calldata targetAmounts,
        uint32 versionTag
    ) external whenNotPaused nonReentrant returns (uint256 tokenId) {
        if (!CollectiveBuildingTypes.isValidCommunityKind(kind)) revert InvalidCommunityKind();
        if (!_isOperationalFaction(faction)) revert InvalidFaction();

        _requireCommunityPlotReady(plotId);
        _requireFactionStewardOrBuilder(faction, msg.sender);
        _requireNonEmptyFundingTarget(targetAmounts);

        if (tokenIdByPlotId[plotId] != 0) revert BuildingAlreadyExistsOnPlot();

        uint256 campaignId = nextCampaignId++;
        address resolvedCustodyHolder = _resolvedCustodyHolder();

        tokenId = collectiveNFT.mintCommunityBuilding(
            resolvedCustodyHolder,
            kind,
            faction,
            plotId,
            campaignId,
            CollectiveBuildingTypes.CollectiveCustodyMode.ContractCustodied,
            versionTag
        );

        buildingByTokenId[tokenId] = CommunityBuildingRecord({
            tokenId: tokenId,
            kind: kind,
            faction: faction,
            plotId: plotId,
            creationCampaignId: campaignId,
            campaignStarter: msg.sender,
            exists: true,
            active: false
        });

        tokenIdByPlotId[plotId] = tokenId;
        nextRoundIdOf[tokenId] = 2;
        activeRoundIdOf[tokenId] = 1;
        lastRoundIdOf[tokenId] = 1;

        CommunityFundingRound storage round = _roundOfToken[tokenId][1];
        round.roundId = 1;
        round.exists = true;
        round.isUpgrade = false;
        round.targetLevel = 1;
        round.ledger.targetAmounts = targetAmounts;
        round.ledger.campaignState = CollectiveBuildingTypes.CollectiveCampaignState.Funding;
        round.ledger.campaignOpenedAt = uint64(block.timestamp);

        emit CommunityCampaignStarted(
            tokenId,
            campaignId,
            plotId,
            kind,
            faction,
            msg.sender,
            resolvedCustodyHolder
        );

        emit CommunityFundingRoundOpened(
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
        CommunityBuildingRecord memory record = _requireCommunityBuilding(tokenId);
        _requireFactionStewardOrBuilder(record.faction, msg.sender);

        if (record.active) revert NoStateChange();
        if (activeRoundIdOf[tokenId] != 0) revert FundingRoundAlreadyActive();

        _requireNonEmptyFundingTarget(targetAmounts);

        uint256 roundId = nextRoundIdOf[tokenId];
        if (roundId == 0) roundId = 1;
        nextRoundIdOf[tokenId] = roundId + 1;
        activeRoundIdOf[tokenId] = roundId;
        lastRoundIdOf[tokenId] = roundId;

        CommunityFundingRound storage round = _roundOfToken[tokenId][roundId];
        round.roundId = roundId;
        round.exists = true;
        round.isUpgrade = false;
        round.targetLevel = 1;
        round.ledger.targetAmounts = targetAmounts;
        round.ledger.campaignState = CollectiveBuildingTypes.CollectiveCampaignState.Funding;
        round.ledger.campaignOpenedAt = uint64(block.timestamp);

        emit CommunityFundingRoundOpened(
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
        CommunityBuildingRecord memory record = _requireCommunityBuilding(tokenId);
        _requireFactionMemberWithKey(record.faction, msg.sender);

        uint256 roundId = activeRoundIdOf[tokenId];
        if (roundId == 0) revert NoActiveFundingRound();

        CommunityFundingRound storage round = _roundOfToken[tokenId][roundId];
        if (
            round.ledger.campaignState != CollectiveBuildingTypes.CollectiveCampaignState.Funding
        ) revert FundingRoundNotOpen();

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

        emit CommunityContributionReceived(
            tokenId,
            roundId,
            msg.sender,
            round.ledger.contributorCount
        );

        if (_isRoundFunded(round.ledger)) {
            round.ledger.campaignState = CollectiveBuildingTypes.CollectiveCampaignState.Funded;
            round.ledger.fundedAt = uint64(block.timestamp);

            emit CommunityFundingRoundFunded(
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
        CommunityBuildingRecord memory record = _requireCommunityBuilding(tokenId);
        _requireFactionStewardOrBuilder(record.faction, msg.sender);

        uint256 roundId = activeRoundIdOf[tokenId];
        if (roundId == 0) revert NoActiveFundingRound();

        CommunityFundingRound storage round = _roundOfToken[tokenId][roundId];
        if (
            round.ledger.campaignState != CollectiveBuildingTypes.CollectiveCampaignState.Funding
        ) revert FundingRoundNotOpen();

        round.ledger.campaignState = CollectiveBuildingTypes.CollectiveCampaignState.Cancelled;
        round.ledger.campaignClosedAt = uint64(block.timestamp);
        activeRoundIdOf[tokenId] = 0;

        if (round.isUpgrade && record.active) {
            _syncNftState(tokenId, CollectiveBuildingTypes.CollectiveBuildingState.Active);
        }

        emit CommunityFundingRoundCancelled(
            tokenId,
            roundId,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    function markFundingRoundFailed(
        uint256 tokenId,
        uint256 roundId
    ) external whenNotPaused onlyRole(COMMUNITY_OPERATOR_ROLE) {
        CommunityBuildingRecord memory record = _requireCommunityBuilding(tokenId);

        CommunityFundingRound storage round = _roundOfToken[tokenId][roundId];
        if (!round.exists) revert NoActiveFundingRound();

        if (
            round.ledger.campaignState != CollectiveBuildingTypes.CollectiveCampaignState.Funding
        ) revert FundingRoundNotOpen();

        round.ledger.campaignState = CollectiveBuildingTypes.CollectiveCampaignState.Failed;
        round.ledger.campaignClosedAt = uint64(block.timestamp);

        if (activeRoundIdOf[tokenId] == roundId) {
            activeRoundIdOf[tokenId] = 0;
        }

        if (round.isUpgrade && record.active) {
            _syncNftState(tokenId, CollectiveBuildingTypes.CollectiveBuildingState.Active);
        }

        emit CommunityFundingRoundFailed(
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
        CommunityBuildingRecord memory record = _requireCommunityBuilding(tokenId);
        record;

        CommunityFundingRound storage round = _roundOfToken[tokenId][roundId];
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

        emit CommunityFundingRefundClaimed(tokenId, roundId, msg.sender);
    }

    function activateFundedCommunityBuilding(
        uint256 tokenId
    ) external whenNotPaused nonReentrant {
        CommunityBuildingRecord storage record = _requireCommunityBuildingStorage(tokenId);
        _requireFactionStewardOrBuilder(record.faction, msg.sender);

        uint256 roundId = activeRoundIdOf[tokenId];
        if (roundId == 0) revert NoActiveFundingRound();

        CommunityFundingRound storage round = _roundOfToken[tokenId][roundId];
        if (round.isUpgrade) revert FundingRoundNotFunded();
        if (
            round.ledger.campaignState != CollectiveBuildingTypes.CollectiveCampaignState.Funded
        ) revert FundingRoundNotFunded();

        round.ledger.campaignState = CollectiveBuildingTypes.CollectiveCampaignState.Closed;
        round.ledger.campaignClosedAt = uint64(block.timestamp);
        round.ledger.activatedAt = uint64(block.timestamp);

        activeRoundIdOf[tokenId] = 0;
        record.active = true;

        _syncNftState(tokenId, CollectiveBuildingTypes.CollectiveBuildingState.Active);
        collectiveNFT.addPrestigeScore(tokenId, 25);
        collectiveNFT.addHistoryScore(tokenId, 25);

        _touchStatus(record.plotId);

        emit CommunityBuildingActivated(
            tokenId,
            roundId,
            record.plotId,
            record.faction,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    function openUpgradeFundingRound(
        uint256 tokenId,
        uint8 targetLevel,
        uint256[10] calldata targetAmounts
    ) external whenNotPaused nonReentrant {
        CommunityBuildingRecord memory record = _requireCommunityBuilding(tokenId);
        _requireFactionStewardOrBuilder(record.faction, msg.sender);

        if (!record.active) revert FundingRoundNotOpen();
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

        CommunityFundingRound storage round = _roundOfToken[tokenId][roundId];
        round.roundId = roundId;
        round.exists = true;
        round.isUpgrade = true;
        round.targetLevel = targetLevel;
        round.ledger.targetAmounts = targetAmounts;
        round.ledger.campaignState = CollectiveBuildingTypes.CollectiveCampaignState.Funding;
        round.ledger.campaignOpenedAt = uint64(block.timestamp);

        _syncNftState(tokenId, CollectiveBuildingTypes.CollectiveBuildingState.Upgrading);

        emit CommunityFundingRoundOpened(
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
        CommunityBuildingRecord memory record = _requireCommunityBuilding(tokenId);
        _requireFactionStewardOrBuilder(record.faction, msg.sender);

        uint256 roundId = activeRoundIdOf[tokenId];
        if (roundId == 0) revert NoActiveFundingRound();

        CommunityFundingRound storage round = _roundOfToken[tokenId][roundId];
        if (!round.isUpgrade) revert FundingRoundNotFunded();
        if (
            round.ledger.campaignState != CollectiveBuildingTypes.CollectiveCampaignState.Funded
        ) revert FundingRoundNotFunded();

        CollectiveBuildingTypes.CollectiveIdentity memory id_ =
            collectiveNFT.getCollectiveIdentity(tokenId);

        uint8 oldLevel = id_.level;
        uint8 newLevel = round.targetLevel;

        collectiveNFT.upgradeCollectiveBuilding(tokenId, newLevel);
        collectiveNFT.addPrestigeScore(tokenId, uint32(newLevel) * 10);
        collectiveNFT.addHistoryScore(tokenId, uint32(newLevel) * 8);
        _syncNftState(tokenId, CollectiveBuildingTypes.CollectiveBuildingState.Active);

        round.ledger.campaignState = CollectiveBuildingTypes.CollectiveCampaignState.Closed;
        round.ledger.campaignClosedAt = uint64(block.timestamp);
        round.ledger.activatedAt = uint64(block.timestamp);
        activeRoundIdOf[tokenId] = 0;

        _touchStatus(record.plotId);

        emit CommunityUpgradeFinalized(
            tokenId,
            roundId,
            oldLevel,
            newLevel,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    function setCommunityBranch(
        uint256 tokenId,
        CollectiveBuildingTypes.CommunityBuildingBranch branch
    ) external whenNotPaused nonReentrant {
        CommunityBuildingRecord memory record = _requireCommunityBuilding(tokenId);
        _requireFactionStewardOrBuilder(record.faction, msg.sender);

        CollectiveBuildingTypes.CollectiveIdentity memory id_ =
            collectiveNFT.getCollectiveIdentity(tokenId);

        if (
            !CollectiveBuildingTypes.canChooseCommunityBranch(
                id_.communityKind,
                id_.level,
                branch
            )
        ) revert InvalidCommunityBranch();

        collectiveNFT.setCommunityBranch(tokenId, branch);
        collectiveNFT.addHistoryScore(tokenId, 5);

        emit CommunityBranchSelected(tokenId, branch, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                                  READS
    //////////////////////////////////////////////////////////////*/

    function getCommunityBuildingRecord(
        uint256 tokenId
    ) external view returns (CommunityBuildingRecord memory) {
        return _requireCommunityBuilding(tokenId);
    }

    function getFundingRound(
        uint256 tokenId,
        uint256 roundId
    ) external view returns (CommunityFundingRoundView memory v) {
        CommunityFundingRound storage round = _roundOfToken[tokenId][roundId];

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

    function getFactionGovernanceRole(
        uint8 faction,
        address account
    ) external view returns (CollectiveBuildingTypes.CollectiveGovernanceRole) {
        return governanceRoleOfFactionMember[faction][account];
    }

    function isFactionMemberEligible(
        uint8 faction,
        address account
    ) external view returns (bool) {
        return _isFactionMember(faction, account);
    }

    function resolvedCustodyHolder() external view returns (address) {
        return _resolvedCustodyHolder();
    }

    /*//////////////////////////////////////////////////////////////
                               INTERNALS
    //////////////////////////////////////////////////////////////*/

    function _requireCommunityBuilding(
        uint256 tokenId
    ) internal view returns (CommunityBuildingRecord memory record) {
        record = buildingByTokenId[tokenId];
        if (!record.exists) revert CommunityBuildingNotFound();
    }

    function _requireCommunityBuildingStorage(
        uint256 tokenId
    ) internal view returns (CommunityBuildingRecord storage record) {
        record = buildingByTokenId[tokenId];
        if (!record.exists) revert CommunityBuildingNotFound();
    }

    function _requireCommunityPlotReady(uint256 plotId) internal view {
        if (plotId == 0) revert InvalidPlot();

        CityTypes.PlotCore memory plot = cityRegistry.getPlotCore(plotId);
        if (plot.plotType != CityTypes.PlotType.Community) revert InvalidPlotType();
        if (!cityLand.isPlotFullyCompleted(plotId)) revert PlotNotCompleted();
    }

    function _requireFactionMemberWithKey(uint8 faction, address account) internal view {
        if (!cityRegistry.hasCityKeyOf(account)) revert NoCityKey();
        if (!_isFactionMember(faction, account)) revert NotFactionMember();
    }

    function _requireFactionStewardOrBuilder(uint8 faction, address account) internal view {
        if (_isAdminOrOperator(account)) return;

        if (!_isFactionMember(faction, account)) revert NotFactionMember();

        CollectiveBuildingTypes.CollectiveGovernanceRole role =
            governanceRoleOfFactionMember[faction][account];

        if (
            role != CollectiveBuildingTypes.CollectiveGovernanceRole.Steward &&
            role != CollectiveBuildingTypes.CollectiveGovernanceRole.Builder
        ) {
            revert NotFactionAuthorized();
        }
    }

    function _isAdminOrOperator(address account) internal view returns (bool) {
        return
            hasRole(COMMUNITY_ADMIN_ROLE, account) ||
            hasRole(COMMUNITY_OPERATOR_ROLE, account) ||
            hasRole(DEFAULT_ADMIN_ROLE, account);
    }

    function _isOperationalFaction(uint8 faction) internal pure returns (bool) {
        return
            faction == uint8(CityTypes.Faction.Inpinity) ||
            faction == uint8(CityTypes.Faction.Inphinity);
    }

    function _isFactionMember(uint8 faction, address account) internal view returns (bool) {
        if (!_isOperationalFaction(faction)) return false;
        if (!cityRegistry.hasCityKeyOf(account)) return false;

        return uint8(cityRegistry.chosenFactionOf(account)) == faction;
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

    /*//////////////////////////////////////////////////////////////
                           INTERFACE SUPPORT
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(AccessControl, ERC1155Holder) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}