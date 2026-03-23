// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "../libraries/CityBuildingTypes.sol";

/*//////////////////////////////////////////////////////////////
                         EXTERNAL INTERFACES
//////////////////////////////////////////////////////////////*/

interface ICityBuildingNFTV1Like {
    function ownerOf(uint256 tokenId) external view returns (address);

    function getBuildingCore(
        uint256 buildingId
    ) external view returns (CityBuildingTypes.BuildingCore memory);

    function getBuildingState(
        uint256 buildingId
    ) external view returns (CityBuildingTypes.BuildingState);

    function isArchived(uint256 buildingId) external view returns (bool);

    function isMigrationPrepared(uint256 buildingId) external view returns (bool);

    function setPlaced(uint256 buildingId, bool placed) external;
}

interface ICityBuildingPlacementPolicy {
    function validatePersonalPlacement(
        address owner,
        uint256 plotId,
        uint256 buildingId
    )
        external
        view
        returns (
            bool allowed,
            bool ownerMatches,
            bool plotCompleted,
            bool plotEligible,
            bool personalPlot,
            bool districtAllowed,
            bool factionAllowed,
            bytes32 reasonCode
        );
}

/*//////////////////////////////////////////////////////////////
                        CITY BUILDING PLACEMENT
//////////////////////////////////////////////////////////////*/

contract CityBuildingPlacement is AccessControl, Pausable, ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                                 ROLES
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant PLACEMENT_ADMIN_ROLE = keccak256("PLACEMENT_ADMIN_ROLE");
    bytes32 public constant FORCE_OPERATOR_ROLE = keccak256("FORCE_OPERATOR_ROLE");
    bytes32 public constant MIGRATION_ADMIN_ROLE = keccak256("MIGRATION_ADMIN_ROLE");

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint64 public constant MIGRATION_PREP_DELAY = 1 days;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error InvalidBuildingContract();
    error InvalidPolicyContract();
    error InvalidPlotId();

    error BuildingAlreadyPlaced();
    error BuildingNotPlaced();
    error PlotAlreadyOccupied();
    error NotBuildingOwner();

    error InvalidBuildingCategory();
    error InvalidBuildingType();

    error BuildingArchived();
    error BuildingStateNotUnplaced();
    error PlacementPolicyRejected(bytes32 reasonCode);

    error InvalidMigrationConfig();
    error MigrationTargetNotSet();
    error MigrationClosed();
    error AlreadyPreparedForMigration();
    error NotPreparedForMigration();
    error MigrationDelayNotElapsed();
    error AlreadyArchived();
    error CannotPrepareWhilePlaced();
    error OperationBlockedWhilePrepared();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event BuildingPlaced(
        uint256 indexed buildingId,
        uint256 indexed plotId,
        address indexed owner,
        uint64 placedAt
    );

    event BuildingUnplaced(
        uint256 indexed buildingId,
        uint256 indexed plotId,
        address indexed owner,
        uint64 unplacedAt
    );

    event BuildingForceUnplaced(
        uint256 indexed buildingId,
        uint256 indexed plotId,
        address indexed executor,
        uint64 unplacedAt,
        bytes32 reasonCode
    );

    event PlacementPolicySet(address indexed policy, address indexed executor);
    event BuildingNFTSet(address indexed buildingNFT, address indexed executor);

    event CoreReferenceSet(
        bytes32 indexed key,
        address indexed target,
        address indexed executor
    );

    event PlacementStateRepaired(
        uint256 indexed buildingId,
        uint256 indexed oldPlotId,
        uint256 indexed newPlotId,
        address executor
    );

    event MigrationTargetSet(address indexed target, bool open, address indexed executor);

    event PlacementPreparedForMigration(
        uint256 indexed buildingId,
        uint64 preparedAt,
        uint32 nonce
    );

    event PlacementUnpreparedForMigration(
        uint256 indexed buildingId,
        uint64 unpreparedAt
    );

    event PlacementArchivedToV2(
        uint256 indexed buildingId,
        uint256 indexed oldPlotId,
        address indexed executor,
        uint64 archivedAt
    );

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    ICityBuildingNFTV1Like public buildingNFT;
    ICityBuildingPlacementPolicy public placementPolicy;

    address public cityRegistry;
    address public cityLand;
    address public cityStatus;
    address public cityDistricts;
    address public cityValidation;

    mapping(uint256 => uint256) public buildingOnPlot;
    mapping(uint256 => uint256) public plotOfBuilding;
    mapping(uint256 => CityBuildingTypes.BuildingPlacement) private _placementOfBuilding;
    mapping(address => uint256) public placedBuildingCountByOwner;

    mapping(uint256 => bool) public preparedForMigration;
    mapping(uint256 => uint64) public preparedForMigrationAt;
    mapping(uint256 => uint32) public migrationPreparationNonce;
    mapping(uint256 => bool) public archivedToV2;

    bool public migrationOpen;
    address public migrationTarget;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address buildingNFT_,
        address placementPolicy_,
        address admin_
    ) {
        if (buildingNFT_ == address(0) || placementPolicy_ == address(0) || admin_ == address(0)) {
            revert ZeroAddress();
        }
        if (buildingNFT_.code.length == 0) revert InvalidBuildingContract();
        if (placementPolicy_.code.length == 0) revert InvalidPolicyContract();

        buildingNFT = ICityBuildingNFTV1Like(buildingNFT_);
        placementPolicy = ICityBuildingPlacementPolicy(placementPolicy_);

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(PLACEMENT_ADMIN_ROLE, admin_);
        _grantRole(FORCE_OPERATOR_ROLE, admin_);
        _grantRole(MIGRATION_ADMIN_ROLE, admin_);
    }

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyBuildingOwner(uint256 buildingId) {
        if (buildingNFT.ownerOf(buildingId) != msg.sender) revert NotBuildingOwner();
        _;
    }

    modifier notPrepared(uint256 buildingId) {
        if (preparedForMigration[buildingId]) revert AlreadyPreparedForMigration();
        _;
    }

    modifier isPrepared(uint256 buildingId) {
        if (!preparedForMigration[buildingId]) revert NotPreparedForMigration();
        _;
    }

    modifier notArchivedPlacement(uint256 buildingId) {
        if (archivedToV2[buildingId]) revert AlreadyArchived();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               ADMIN SETTERS
    //////////////////////////////////////////////////////////////*/

    function pause() external onlyRole(PLACEMENT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PLACEMENT_ADMIN_ROLE) {
        _unpause();
    }

    function setBuildingNFT(address buildingNFT_) external onlyRole(PLACEMENT_ADMIN_ROLE) {
        if (buildingNFT_ == address(0)) revert ZeroAddress();
        if (buildingNFT_.code.length == 0) revert InvalidBuildingContract();

        buildingNFT = ICityBuildingNFTV1Like(buildingNFT_);
        emit BuildingNFTSet(buildingNFT_, msg.sender);
    }

    function setPlacementPolicy(address policy_) external onlyRole(PLACEMENT_ADMIN_ROLE) {
        if (policy_ == address(0)) revert ZeroAddress();
        if (policy_.code.length == 0) revert InvalidPolicyContract();

        placementPolicy = ICityBuildingPlacementPolicy(policy_);
        emit PlacementPolicySet(policy_, msg.sender);
    }

    function setCoreReferences(
        address cityRegistry_,
        address cityLand_,
        address cityStatus_,
        address cityDistricts_,
        address cityValidation_
    ) external onlyRole(PLACEMENT_ADMIN_ROLE) {
        cityRegistry = cityRegistry_;
        cityLand = cityLand_;
        cityStatus = cityStatus_;
        cityDistricts = cityDistricts_;
        cityValidation = cityValidation_;

        emit CoreReferenceSet(keccak256("CITY_REGISTRY"), cityRegistry_, msg.sender);
        emit CoreReferenceSet(keccak256("CITY_LAND"), cityLand_, msg.sender);
        emit CoreReferenceSet(keccak256("CITY_STATUS"), cityStatus_, msg.sender);
        emit CoreReferenceSet(keccak256("CITY_DISTRICTS"), cityDistricts_, msg.sender);
        emit CoreReferenceSet(keccak256("CITY_VALIDATION"), cityValidation_, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                               USER ACTIONS
    //////////////////////////////////////////////////////////////*/

    function placeBuilding(
        uint256 buildingId,
        uint256 plotId
    )
        external
        whenNotPaused
        nonReentrant
        onlyBuildingOwner(buildingId)
        notPrepared(buildingId)
        notArchivedPlacement(buildingId)
    {
        if (plotId == 0) revert InvalidPlotId();

        _requireNftNotPrepared(buildingId);
        _validateBuildingPlaceable(buildingId);

        if (_isPlacedLocal(buildingId)) revert BuildingAlreadyPlaced();
        if (buildingOnPlot[plotId] != 0) revert PlotAlreadyOccupied();

        (
            bool allowed,
            bool ownerMatches,
            bool plotCompleted,
            bool plotEligible,
            bool personalPlot,
            bool districtAllowed,
            bool factionAllowed,
            bytes32 reasonCode
        ) = placementPolicy.validatePersonalPlacement(msg.sender, plotId, buildingId);

        ownerMatches;
        plotCompleted;
        plotEligible;
        personalPlot;
        districtAllowed;
        factionAllowed;

        if (!allowed) revert PlacementPolicyRejected(reasonCode);

        _place(buildingId, plotId, msg.sender);
    }

    function unplaceBuilding(
        uint256 buildingId
    )
        external
        whenNotPaused
        nonReentrant
        onlyBuildingOwner(buildingId)
        notPrepared(buildingId)
        notArchivedPlacement(buildingId)
    {
        _requireNftNotPrepared(buildingId);

        uint256 plotId = plotOfBuilding[buildingId];
        if (plotId == 0) revert BuildingNotPlaced();

        _unplace(buildingId, plotId, msg.sender, false, bytes32(0));
    }

    /*//////////////////////////////////////////////////////////////
                             FORCE / REPAIR ACTIONS
    //////////////////////////////////////////////////////////////*/

    function forceUnplaceBuilding(
        uint256 buildingId,
        bytes32 reasonCode
    )
        external
        whenNotPaused
        nonReentrant
        onlyRole(FORCE_OPERATOR_ROLE)
    {
        uint256 plotId = plotOfBuilding[buildingId];
        if (plotId == 0) revert BuildingNotPlaced();

        _unplace(buildingId, plotId, msg.sender, true, reasonCode);
    }

    function repairPlacementState(
        uint256 buildingId,
        uint256 newPlotId,
        bool syncNftPlacedFlag
    ) external onlyRole(FORCE_OPERATOR_ROLE) {
        uint256 oldPlotId = plotOfBuilding[buildingId];

        if (oldPlotId != 0 && buildingOnPlot[oldPlotId] == buildingId) {
            delete buildingOnPlot[oldPlotId];
        }

        if (newPlotId == 0) {
            delete plotOfBuilding[buildingId];

            CityBuildingTypes.BuildingPlacement storage cleared = _placementOfBuilding[buildingId];
            if (cleared.placedAt != 0) {
                cleared.lastPlacedAt = cleared.placedAt;
            }
            cleared.plotId = 0;
            cleared.placedAt = 0;
            cleared.placedBy = address(0);

            if (syncNftPlacedFlag) {
                buildingNFT.setPlaced(buildingId, false);
            }
        } else {
            if (buildingOnPlot[newPlotId] != 0 && buildingOnPlot[newPlotId] != buildingId) {
                revert PlotAlreadyOccupied();
            }

            buildingOnPlot[newPlotId] = buildingId;
            plotOfBuilding[buildingId] = newPlotId;

            CityBuildingTypes.BuildingPlacement storage placement = _placementOfBuilding[buildingId];
            uint64 ts = uint64(block.timestamp);
            uint64 previousPlacedAt = placement.placedAt != 0 ? placement.placedAt : placement.lastPlacedAt;

            placement.plotId = newPlotId;
            placement.lastPlacedAt = previousPlacedAt == 0 ? ts : previousPlacedAt;
            placement.placedAt = ts;
            placement.placedBy = msg.sender;

            if (syncNftPlacedFlag) {
                buildingNFT.setPlaced(buildingId, true);
            }
        }

        emit PlacementStateRepaired(buildingId, oldPlotId, newPlotId, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                          MIGRATION PREPARATION
    //////////////////////////////////////////////////////////////*/

    function setMigrationTarget(address target, bool open) external onlyRole(MIGRATION_ADMIN_ROLE) {
        if (open && target == address(0)) revert InvalidMigrationConfig();

        migrationTarget = target;
        migrationOpen = open;

        emit MigrationTargetSet(target, open, msg.sender);
    }

    function preparePlacementForMigration(
        uint256 buildingId
    )
        external
        whenNotPaused
        onlyBuildingOwner(buildingId)
        notPrepared(buildingId)
        notArchivedPlacement(buildingId)
    {
        _requireNftNotPrepared(buildingId);

        uint256 plotId = plotOfBuilding[buildingId];
        if (plotId != 0) revert CannotPrepareWhilePlaced();
        if (migrationTarget == address(0)) revert MigrationTargetNotSet();
        if (!migrationOpen) revert MigrationClosed();

        preparedForMigration[buildingId] = true;
        preparedForMigrationAt[buildingId] = uint64(block.timestamp);
        migrationPreparationNonce[buildingId] += 1;

        emit PlacementPreparedForMigration(
            buildingId,
            uint64(block.timestamp),
            migrationPreparationNonce[buildingId]
        );
    }

    function unpreparePlacementForMigration(
        uint256 buildingId
    )
        external
        whenNotPaused
        onlyBuildingOwner(buildingId)
        isPrepared(buildingId)
        notArchivedPlacement(buildingId)
    {
        preparedForMigration[buildingId] = false;
        delete preparedForMigrationAt[buildingId];

        emit PlacementUnpreparedForMigration(buildingId, uint64(block.timestamp));
    }

    function archivePlacementToV2(
        uint256 buildingId
    )
        external
        whenNotPaused
        onlyRole(MIGRATION_ADMIN_ROLE)
        isPrepared(buildingId)
        notArchivedPlacement(buildingId)
    {
        if (migrationTarget == address(0)) revert MigrationTargetNotSet();
        if (!migrationOpen) revert MigrationClosed();

        if (block.timestamp < preparedForMigrationAt[buildingId] + MIGRATION_PREP_DELAY) {
            revert MigrationDelayNotElapsed();
        }

        uint256 oldPlotId = plotOfBuilding[buildingId];
        if (oldPlotId != 0) revert CannotPrepareWhilePlaced();

        archivedToV2[buildingId] = true;
        preparedForMigration[buildingId] = false;
        delete preparedForMigrationAt[buildingId];

        emit PlacementArchivedToV2(
            buildingId,
            oldPlotId,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    /*//////////////////////////////////////////////////////////////
                                  READS
    //////////////////////////////////////////////////////////////*/

    function getPlacement(
        uint256 buildingId
    ) external view returns (CityBuildingTypes.BuildingPlacement memory) {
        return _placementOfBuilding[buildingId];
    }

    function isPlacedBuilding(uint256 buildingId) external view returns (bool) {
        return _isPlacedLocal(buildingId);
    }

    function canPlaceBuilding(
        address owner,
        uint256 buildingId,
        uint256 plotId
    )
        external
        view
        returns (
            bool allowed,
            bool ownerMatches,
            bool plotCompleted,
            bool plotEligible,
            bool personalPlot,
            bool districtAllowed,
            bool factionAllowed,
            bytes32 reasonCode
        )
    {
        if (plotId == 0) {
            return (false, false, false, false, false, false, false, keccak256("INVALID_PLOT"));
        }
        if (archivedToV2[buildingId]) {
            return (false, false, false, false, false, false, false, keccak256("ARCHIVED"));
        }
        if (preparedForMigration[buildingId]) {
            return (false, false, false, false, false, false, false, keccak256("PLACEMENT_PREPARED"));
        }
        if (buildingNFT.isArchived(buildingId)) {
            return (false, false, false, false, false, false, false, keccak256("NFT_ARCHIVED"));
        }
        if (buildingNFT.isMigrationPrepared(buildingId)) {
            return (false, false, false, false, false, false, false, keccak256("NFT_PREPARED"));
        }
        if (_isPlacedLocal(buildingId)) {
            return (false, false, false, false, false, false, false, keccak256("ALREADY_PLACED"));
        }
        if (buildingOnPlot[plotId] != 0) {
            return (false, false, false, false, false, false, false, keccak256("PLOT_OCCUPIED"));
        }

        CityBuildingTypes.BuildingCore memory core = buildingNFT.getBuildingCore(buildingId);
        if (core.category != CityBuildingTypes.BuildingCategory.Personal) {
            return (false, false, false, false, false, false, false, keccak256("INVALID_CATEGORY"));
        }
        if (!CityBuildingTypes.isValidBaseType(core.buildingType)) {
            return (false, false, false, false, false, false, false, keccak256("INVALID_TYPE"));
        }

        CityBuildingTypes.BuildingState currentState = buildingNFT.getBuildingState(buildingId);
        if (currentState != CityBuildingTypes.BuildingState.Unplaced) {
            return (false, false, false, false, false, false, false, keccak256("STATE_NOT_UNPLACED"));
        }

        return placementPolicy.validatePersonalPlacement(owner, plotId, buildingId);
    }

    function canUnplaceBuilding(uint256 buildingId) external view returns (bool) {
        return
            plotOfBuilding[buildingId] != 0 &&
            !preparedForMigration[buildingId] &&
            !archivedToV2[buildingId] &&
            !buildingNFT.isMigrationPrepared(buildingId) &&
            !buildingNFT.isArchived(buildingId);
    }

    function getPlacementSummary(
        uint256 buildingId
    )
        external
        view
        returns (
            uint256 plotId,
            bool placed,
            bool prepared,
            bool archived,
            uint64 placedAt,
            uint64 lastPlacedAt,
            address placedBy
        )
    {
        CityBuildingTypes.BuildingPlacement memory p = _placementOfBuilding[buildingId];
        return (
            p.plotId,
            p.plotId != 0,
            preparedForMigration[buildingId],
            archivedToV2[buildingId],
            p.placedAt,
            p.lastPlacedAt,
            p.placedBy
        );
    }

    /*//////////////////////////////////////////////////////////////
                               INTERNALS
    //////////////////////////////////////////////////////////////*/

    function _place(
        uint256 buildingId,
        uint256 plotId,
        address owner
    ) internal {
        uint64 ts = uint64(block.timestamp);

        buildingOnPlot[plotId] = buildingId;
        plotOfBuilding[buildingId] = plotId;

        CityBuildingTypes.BuildingPlacement storage placement = _placementOfBuilding[buildingId];
        uint64 previousPlacedAt = placement.placedAt != 0 ? placement.placedAt : placement.lastPlacedAt;

        placement.plotId = plotId;
        placement.lastPlacedAt = previousPlacedAt == 0 ? ts : previousPlacedAt;
        placement.placedAt = ts;
        placement.placedBy = owner;

        placedBuildingCountByOwner[owner] += 1;

        buildingNFT.setPlaced(buildingId, true);

        emit BuildingPlaced(buildingId, plotId, owner, ts);
    }

    function _unplace(
        uint256 buildingId,
        uint256 plotId,
        address executor,
        bool forced,
        bytes32 reasonCode
    ) internal {
        address owner = buildingNFT.ownerOf(buildingId);

        delete buildingOnPlot[plotId];
        delete plotOfBuilding[buildingId];

        CityBuildingTypes.BuildingPlacement storage placement = _placementOfBuilding[buildingId];
        if (placement.placedAt != 0) {
            placement.lastPlacedAt = placement.placedAt;
        }
        placement.plotId = 0;
        placement.placedAt = 0;
        placement.placedBy = address(0);

        if (placedBuildingCountByOwner[owner] > 0) {
            placedBuildingCountByOwner[owner] -= 1;
        }

        buildingNFT.setPlaced(buildingId, false);

        if (forced) {
            emit BuildingForceUnplaced(
                buildingId,
                plotId,
                executor,
                uint64(block.timestamp),
                reasonCode
            );
        } else {
            emit BuildingUnplaced(
                buildingId,
                plotId,
                owner,
                uint64(block.timestamp)
            );
        }
    }

    function _validateBuildingPlaceable(uint256 buildingId) internal view {
        if (buildingNFT.isArchived(buildingId)) revert BuildingArchived();
        if (buildingNFT.isMigrationPrepared(buildingId)) revert OperationBlockedWhilePrepared();

        CityBuildingTypes.BuildingCore memory core = buildingNFT.getBuildingCore(buildingId);
        if (core.category != CityBuildingTypes.BuildingCategory.Personal) {
            revert InvalidBuildingCategory();
        }
        if (!CityBuildingTypes.isValidBaseType(core.buildingType)) {
            revert InvalidBuildingType();
        }

        CityBuildingTypes.BuildingState currentState = buildingNFT.getBuildingState(buildingId);
        if (currentState != CityBuildingTypes.BuildingState.Unplaced) {
            revert BuildingStateNotUnplaced();
        }
    }

    function _isPlacedLocal(uint256 buildingId) internal view returns (bool) {
        return plotOfBuilding[buildingId] != 0;
    }

    function _requireNftNotPrepared(uint256 buildingId) internal view {
        if (buildingNFT.isMigrationPrepared(buildingId)) {
            revert OperationBlockedWhilePrepared();
        }
    }
}