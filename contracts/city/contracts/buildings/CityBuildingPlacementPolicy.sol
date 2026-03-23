// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

import "../libraries/CityBuildingTypes.sol";
import "../interfaces/ICityBuildingNFTV1Like.sol";

/*//////////////////////////////////////////////////////////////
                     EXTERNAL READ INTERFACES
//////////////////////////////////////////////////////////////*/

/// @notice Adapter that resolves plot owner.
interface ICityPlotOwnerAdapter {
    function getPlotOwner(uint256 plotId) external view returns (address owner);
}

/// @notice Adapter that resolves placement-relevant plot info.
interface ICityPlotInfoAdapter {
    function getPlotPlacementInfo(
        uint256 plotId
    )
        external
        view
        returns (
            bool exists,
            bool completed,
            bool personalPlot,
            uint8 districtKind,
            uint8 faction
        );
}

/// @notice Adapter that resolves placement-relevant status flags.
interface ICityPlotStatusAdapter {
    function getPlotStatusFlags(
        uint256 plotId
    )
        external
        view
        returns (
            bool dormant,
            bool decayed,
            bool layerEligible
        );
}

/*//////////////////////////////////////////////////////////////
                    CITY BUILDING PLACEMENT POLICY
//////////////////////////////////////////////////////////////*/

/// @title CityBuildingPlacementPolicy
/// @notice Policy/validator contract for personal building placement.
/// @dev This is the personal-placement module behind the router.
///      Community / Borderline / Nexus should later get sibling policy contracts.
contract CityBuildingPlacementPolicy is AccessControl, Pausable {
    /*//////////////////////////////////////////////////////////////
                                 ROLES
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant POLICY_ADMIN_ROLE = keccak256("POLICY_ADMIN_ROLE");

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error InvalidBuildingNFT();
    error InvalidOwnerAdapter();
    error InvalidInfoAdapter();
    error InvalidStatusAdapter();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event BuildingNFTSet(address indexed buildingNFT, address indexed executor);
    event PlotOwnerAdapterSet(address indexed adapter, address indexed executor);
    event PlotInfoAdapterSet(address indexed adapter, address indexed executor);
    event PlotStatusAdapterSet(address indexed adapter, address indexed executor);

    event RequireOwnerMatchSet(bool value, address indexed executor);
    event RequirePlotExistsSet(bool value, address indexed executor);
    event RequirePlotCompletedSet(bool value, address indexed executor);
    event RequirePersonalPlotSet(bool value, address indexed executor);
    event EnforceDistrictAllowlistSet(bool value, address indexed executor);
    event EnforceFactionAllowlistSet(bool value, address indexed executor);
    event BlockDormantSet(bool value, address indexed executor);
    event BlockDecayedSet(bool value, address indexed executor);
    event BlockLayerEligibleSet(bool value, address indexed executor);

    event DistrictAllowedSet(uint8 indexed districtKind, bool allowed, address indexed executor);
    event FactionAllowedSet(uint8 indexed faction, bool allowed, address indexed executor);

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    ICityBuildingNFTV1Like public buildingNFT;
    ICityPlotOwnerAdapter public plotOwnerAdapter;
    ICityPlotInfoAdapter public plotInfoAdapter;
    ICityPlotStatusAdapter public plotStatusAdapter;

    bool public requireOwnerMatch = true;
    bool public requirePlotExists = true;
    bool public requirePlotCompleted = true;
    bool public requirePersonalPlot = true;

    bool public enforceDistrictAllowlist = false;
    bool public enforceFactionAllowlist = false;

    bool public blockDormant = false;
    bool public blockDecayed = true;
    bool public blockLayerEligible = true;

    mapping(uint8 => bool) public allowedDistrictKinds;
    mapping(uint8 => bool) public allowedFactions;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address buildingNFT_,
        address plotOwnerAdapter_,
        address plotInfoAdapter_,
        address plotStatusAdapter_,
        address admin_
    ) {
        if (buildingNFT_ == address(0) || admin_ == address(0)) revert ZeroAddress();
        if (buildingNFT_.code.length == 0) revert InvalidBuildingNFT();

        if (plotOwnerAdapter_ != address(0) && plotOwnerAdapter_.code.length == 0) {
            revert InvalidOwnerAdapter();
        }
        if (plotInfoAdapter_ != address(0) && plotInfoAdapter_.code.length == 0) {
            revert InvalidInfoAdapter();
        }
        if (plotStatusAdapter_ != address(0) && plotStatusAdapter_.code.length == 0) {
            revert InvalidStatusAdapter();
        }

        buildingNFT = ICityBuildingNFTV1Like(buildingNFT_);
        plotOwnerAdapter = ICityPlotOwnerAdapter(plotOwnerAdapter_);
        plotInfoAdapter = ICityPlotInfoAdapter(plotInfoAdapter_);
        plotStatusAdapter = ICityPlotStatusAdapter(plotStatusAdapter_);

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(POLICY_ADMIN_ROLE, admin_);
    }

    /*//////////////////////////////////////////////////////////////
                               ADMIN SETTERS
    //////////////////////////////////////////////////////////////*/

    function pause() external onlyRole(POLICY_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(POLICY_ADMIN_ROLE) {
        _unpause();
    }

    function setBuildingNFT(address buildingNFT_) external onlyRole(POLICY_ADMIN_ROLE) {
        if (buildingNFT_ == address(0)) revert ZeroAddress();
        if (buildingNFT_.code.length == 0) revert InvalidBuildingNFT();

        buildingNFT = ICityBuildingNFTV1Like(buildingNFT_);
        emit BuildingNFTSet(buildingNFT_, msg.sender);
    }

    function setPlotOwnerAdapter(address adapter_) external onlyRole(POLICY_ADMIN_ROLE) {
        if (adapter_ == address(0)) {
            plotOwnerAdapter = ICityPlotOwnerAdapter(address(0));
        } else {
            if (adapter_.code.length == 0) revert InvalidOwnerAdapter();
            plotOwnerAdapter = ICityPlotOwnerAdapter(adapter_);
        }

        emit PlotOwnerAdapterSet(adapter_, msg.sender);
    }

    function setPlotInfoAdapter(address adapter_) external onlyRole(POLICY_ADMIN_ROLE) {
        if (adapter_ == address(0)) {
            plotInfoAdapter = ICityPlotInfoAdapter(address(0));
        } else {
            if (adapter_.code.length == 0) revert InvalidInfoAdapter();
            plotInfoAdapter = ICityPlotInfoAdapter(adapter_);
        }

        emit PlotInfoAdapterSet(adapter_, msg.sender);
    }

    function setPlotStatusAdapter(address adapter_) external onlyRole(POLICY_ADMIN_ROLE) {
        if (adapter_ == address(0)) {
            plotStatusAdapter = ICityPlotStatusAdapter(address(0));
        } else {
            if (adapter_.code.length == 0) revert InvalidStatusAdapter();
            plotStatusAdapter = ICityPlotStatusAdapter(adapter_);
        }

        emit PlotStatusAdapterSet(adapter_, msg.sender);
    }

    function setRequireOwnerMatch(bool value) external onlyRole(POLICY_ADMIN_ROLE) {
        requireOwnerMatch = value;
        emit RequireOwnerMatchSet(value, msg.sender);
    }

    function setRequirePlotExists(bool value) external onlyRole(POLICY_ADMIN_ROLE) {
        requirePlotExists = value;
        emit RequirePlotExistsSet(value, msg.sender);
    }

    function setRequirePlotCompleted(bool value) external onlyRole(POLICY_ADMIN_ROLE) {
        requirePlotCompleted = value;
        emit RequirePlotCompletedSet(value, msg.sender);
    }

    function setRequirePersonalPlot(bool value) external onlyRole(POLICY_ADMIN_ROLE) {
        requirePersonalPlot = value;
        emit RequirePersonalPlotSet(value, msg.sender);
    }

    function setEnforceDistrictAllowlist(bool value) external onlyRole(POLICY_ADMIN_ROLE) {
        enforceDistrictAllowlist = value;
        emit EnforceDistrictAllowlistSet(value, msg.sender);
    }

    function setEnforceFactionAllowlist(bool value) external onlyRole(POLICY_ADMIN_ROLE) {
        enforceFactionAllowlist = value;
        emit EnforceFactionAllowlistSet(value, msg.sender);
    }

    function setBlockDormant(bool value) external onlyRole(POLICY_ADMIN_ROLE) {
        blockDormant = value;
        emit BlockDormantSet(value, msg.sender);
    }

    function setBlockDecayed(bool value) external onlyRole(POLICY_ADMIN_ROLE) {
        blockDecayed = value;
        emit BlockDecayedSet(value, msg.sender);
    }

    function setBlockLayerEligible(bool value) external onlyRole(POLICY_ADMIN_ROLE) {
        blockLayerEligible = value;
        emit BlockLayerEligibleSet(value, msg.sender);
    }

    function setDistrictAllowed(uint8 districtKind, bool allowed) external onlyRole(POLICY_ADMIN_ROLE) {
        allowedDistrictKinds[districtKind] = allowed;
        emit DistrictAllowedSet(districtKind, allowed, msg.sender);
    }

    function setFactionAllowed(uint8 faction, bool allowed) external onlyRole(POLICY_ADMIN_ROLE) {
        allowedFactions[faction] = allowed;
        emit FactionAllowedSet(faction, allowed, msg.sender);
    }

    function setValidationProfile(
        bool requireOwnerMatch_,
        bool requirePlotExists_,
        bool requirePlotCompleted_,
        bool requirePersonalPlot_,
        bool enforceDistrictAllowlist_,
        bool enforceFactionAllowlist_,
        bool blockDormant_,
        bool blockDecayed_,
        bool blockLayerEligible_
    ) external onlyRole(POLICY_ADMIN_ROLE) {
        requireOwnerMatch = requireOwnerMatch_;
        requirePlotExists = requirePlotExists_;
        requirePlotCompleted = requirePlotCompleted_;
        requirePersonalPlot = requirePersonalPlot_;
        enforceDistrictAllowlist = enforceDistrictAllowlist_;
        enforceFactionAllowlist = enforceFactionAllowlist_;
        blockDormant = blockDormant_;
        blockDecayed = blockDecayed_;
        blockLayerEligible = blockLayerEligible_;

        emit RequireOwnerMatchSet(requireOwnerMatch_, msg.sender);
        emit RequirePlotExistsSet(requirePlotExists_, msg.sender);
        emit RequirePlotCompletedSet(requirePlotCompleted_, msg.sender);
        emit RequirePersonalPlotSet(requirePersonalPlot_, msg.sender);
        emit EnforceDistrictAllowlistSet(enforceDistrictAllowlist_, msg.sender);
        emit EnforceFactionAllowlistSet(enforceFactionAllowlist_, msg.sender);
        emit BlockDormantSet(blockDormant_, msg.sender);
        emit BlockDecayedSet(blockDecayed_, msg.sender);
        emit BlockLayerEligibleSet(blockLayerEligible_, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                           PLACEMENT VALIDATION
    //////////////////////////////////////////////////////////////*/

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
        )
    {
        if (paused()) return _fail("PAUSED");
        if (owner == address(0)) return _fail("OWNER_ZERO");
        if (plotId == 0) return _fail("PLOT_ZERO");

        if (address(buildingNFT) == address(0)) return _fail("BUILDING_NFT_NOT_SET");

        if (buildingNFT.isArchived(buildingId)) return _fail("BUILDING_ARCHIVED");
        if (buildingNFT.isMigrationPrepared(buildingId)) return _fail("BUILDING_PREPARED");

        CityBuildingTypes.BuildingCore memory core = buildingNFT.getBuildingCore(buildingId);

        if (core.category != CityBuildingTypes.BuildingCategory.Personal) {
            return _fail("INVALID_CATEGORY");
        }

        if (!CityBuildingTypes.isValidBaseType(core.buildingType)) {
            return _fail("INVALID_BUILDING_TYPE");
        }

        if (address(plotInfoAdapter) == address(0)) {
            return _fail("PLOT_INFO_ADAPTER_NOT_SET");
        }

        (
            bool exists_,
            bool completed_,
            bool personalPlot_,
            uint8 districtKind_,
            uint8 faction_
        ) = plotInfoAdapter.getPlotPlacementInfo(plotId);

        plotCompleted = completed_;
        personalPlot = personalPlot_;
        plotEligible = false;

        districtAllowed = !enforceDistrictAllowlist;
        factionAllowed = !enforceFactionAllowlist;
        ownerMatches = !requireOwnerMatch;

        if (requirePlotExists && !exists_) {
            return _composeResult(
                false,
                ownerMatches,
                plotCompleted,
                false,
                personalPlot,
                districtAllowed,
                factionAllowed,
                _rc("PLOT_NOT_FOUND")
            );
        }

        if (requirePlotCompleted && !completed_) {
            return _composeResult(
                false,
                ownerMatches,
                plotCompleted,
                false,
                personalPlot,
                districtAllowed,
                factionAllowed,
                _rc("PLOT_NOT_COMPLETED")
            );
        }

        if (requirePersonalPlot && !personalPlot_) {
            return _composeResult(
                false,
                ownerMatches,
                plotCompleted,
                false,
                personalPlot,
                districtAllowed,
                factionAllowed,
                _rc("NOT_PERSONAL_PLOT")
            );
        }

        if (requireOwnerMatch) {
            if (address(plotOwnerAdapter) == address(0)) {
                return _composeResult(
                    false,
                    false,
                    plotCompleted,
                    false,
                    personalPlot,
                    districtAllowed,
                    factionAllowed,
                    _rc("OWNER_ADAPTER_NOT_SET")
                );
            }

            address plotOwner = plotOwnerAdapter.getPlotOwner(plotId);
            ownerMatches = (plotOwner == owner);

            if (!ownerMatches) {
                return _composeResult(
                    false,
                    false,
                    plotCompleted,
                    false,
                    personalPlot,
                    districtAllowed,
                    factionAllowed,
                    _rc("PLOT_OWNER_MISMATCH")
                );
            }
        }

        if (enforceDistrictAllowlist) {
            districtAllowed = allowedDistrictKinds[districtKind_];
            if (!districtAllowed) {
                return _composeResult(
                    false,
                    ownerMatches,
                    plotCompleted,
                    false,
                    personalPlot,
                    false,
                    factionAllowed,
                    _rc("DISTRICT_NOT_ALLOWED")
                );
            }
        } else {
            districtAllowed = true;
        }

        if (enforceFactionAllowlist) {
            factionAllowed = allowedFactions[faction_];
            if (!factionAllowed) {
                return _composeResult(
                    false,
                    ownerMatches,
                    plotCompleted,
                    false,
                    personalPlot,
                    districtAllowed,
                    false,
                    _rc("FACTION_NOT_ALLOWED")
                );
            }
        } else {
            factionAllowed = true;
        }

        if (blockDormant || blockDecayed || blockLayerEligible) {
            if (address(plotStatusAdapter) == address(0)) {
                return _composeResult(
                    false,
                    ownerMatches,
                    plotCompleted,
                    false,
                    personalPlot,
                    districtAllowed,
                    factionAllowed,
                    _rc("STATUS_ADAPTER_NOT_SET")
                );
            }

            (
                bool dormant_,
                bool decayed_,
                bool layerEligible_
            ) = plotStatusAdapter.getPlotStatusFlags(plotId);

            if (blockDormant && dormant_) {
                return _composeResult(
                    false,
                    ownerMatches,
                    plotCompleted,
                    false,
                    personalPlot,
                    districtAllowed,
                    factionAllowed,
                    _rc("PLOT_DORMANT")
                );
            }

            if (blockDecayed && decayed_) {
                return _composeResult(
                    false,
                    ownerMatches,
                    plotCompleted,
                    false,
                    personalPlot,
                    districtAllowed,
                    factionAllowed,
                    _rc("PLOT_DECAYED")
                );
            }

            if (blockLayerEligible && layerEligible_) {
                return _composeResult(
                    false,
                    ownerMatches,
                    plotCompleted,
                    false,
                    personalPlot,
                    districtAllowed,
                    factionAllowed,
                    _rc("PLOT_LAYER_ELIGIBLE_BLOCKED")
                );
            }
        }

        plotEligible = true;

        return (
            true,
            ownerMatches,
            plotCompleted,
            plotEligible,
            personalPlot,
            districtAllowed,
            factionAllowed,
            bytes32(0)
        );
    }

    /*//////////////////////////////////////////////////////////////
                                  READS
    //////////////////////////////////////////////////////////////*/

    function getPolicySummary()
        external
        view
        returns (
            address buildingNFT_,
            address plotOwnerAdapter_,
            address plotInfoAdapter_,
            address plotStatusAdapter_,
            bool requireOwnerMatch_,
            bool requirePlotExists_,
            bool requirePlotCompleted_,
            bool requirePersonalPlot_,
            bool enforceDistrictAllowlist_,
            bool enforceFactionAllowlist_,
            bool blockDormant_,
            bool blockDecayed_,
            bool blockLayerEligible_,
            bool paused_
        )
    {
        return (
            address(buildingNFT),
            address(plotOwnerAdapter),
            address(plotInfoAdapter),
            address(plotStatusAdapter),
            requireOwnerMatch,
            requirePlotExists,
            requirePlotCompleted,
            requirePersonalPlot,
            enforceDistrictAllowlist,
            enforceFactionAllowlist,
            blockDormant,
            blockDecayed,
            blockLayerEligible,
            paused()
        );
    }

    /*//////////////////////////////////////////////////////////////
                               INTERNALS
    //////////////////////////////////////////////////////////////*/

    function _fail(
        string memory code
    )
        internal
        pure
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
        return (false, false, false, false, false, false, false, _rc(code));
    }

    function _composeResult(
        bool allowed,
        bool ownerMatches,
        bool plotCompleted,
        bool plotEligible,
        bool personalPlot,
        bool districtAllowed,
        bool factionAllowed,
        bytes32 reasonCode
    )
        internal
        pure
        returns (
            bool,
            bool,
            bool,
            bool,
            bool,
            bool,
            bool,
            bytes32
        )
    {
        return (
            allowed,
            ownerMatches,
            plotCompleted,
            plotEligible,
            personalPlot,
            districtAllowed,
            factionAllowed,
            reasonCode
        );
    }

    function _rc(string memory code) internal pure returns (bytes32) {
        return keccak256(bytes(code));
    }
}