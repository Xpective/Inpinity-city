// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "../libraries/CityTypes.sol";
import "../libraries/CityErrors.sol";
import "../interfaces/IResourceToken.sol";
import "../interfaces/ICityCrowdfunding.sol";
import "../core/CityConfig.sol";
import "../core/CityRegistry.sol";

contract CityCrowdfunding is Ownable, ERC1155Holder, ICityCrowdfunding {
    uint256 public constant RESOURCE_OIL = 0;
    uint256 public constant RESOURCE_LEMONS = 1;
    uint256 public constant RESOURCE_IRON = 2;
    uint256 public constant RESOURCE_GOLD = 3;

    struct ProjectFunding {
        uint256 oilTarget;
        uint256 lemonsTarget;
        uint256 ironTarget;
        uint256 goldTarget;
        uint256 oilRaised;
        uint256 lemonsRaised;
        uint256 ironRaised;
        uint256 goldRaised;
        bool exists;
        bool funded;
        bool active;
    }

    CityConfig public immutable cityConfig;
    CityRegistry public immutable cityRegistry;

    mapping(address => bool) public authorizedCallers;
    mapping(uint256 => ProjectFunding) public projectOfPlot;
    mapping(uint256 => mapping(address => uint256)) public oilContributedBy;
    mapping(uint256 => mapping(address => uint256)) public lemonsContributedBy;
    mapping(uint256 => mapping(address => uint256)) public ironContributedBy;
    mapping(uint256 => mapping(address => uint256)) public goldContributedBy;

    event AuthorizedCallerSet(address indexed caller, bool allowed);

    event CommunityProjectCreated(
        uint256 indexed plotId,
        uint256 oilTarget,
        uint256 lemonsTarget,
        uint256 ironTarget,
        uint256 goldTarget
    );

    event CommunityProjectContribution(
        uint256 indexed plotId,
        address indexed contributor,
        uint256 oil,
        uint256 lemons,
        uint256 iron,
        uint256 gold
    );

    event CommunityProjectFunded(uint256 indexed plotId);
    event CommunityProjectClosed(uint256 indexed plotId);

    constructor(
        address initialOwner,
        address cityConfigAddress,
        address cityRegistryAddress
    ) Ownable(initialOwner) {
        if (
            initialOwner == address(0) ||
            cityConfigAddress == address(0) ||
            cityRegistryAddress == address(0)
        ) {
            revert CityErrors.ZeroAddress();
        }

        cityConfig = CityConfig(cityConfigAddress);
        cityRegistry = CityRegistry(cityRegistryAddress);
    }

    modifier onlyAuthorized() {
        if (!(msg.sender == owner() || authorizedCallers[msg.sender])) {
            revert CityErrors.NotAuthorized();
        }
        _;
    }

    function setAuthorizedCaller(address caller, bool allowed) external onlyOwner {
        if (caller == address(0)) revert CityErrors.ZeroAddress();
        authorizedCallers[caller] = allowed;
        emit AuthorizedCallerSet(caller, allowed);
    }

    function createProject(
        uint256 plotId,
        uint256 oilTarget,
        uint256 lemonsTarget,
        uint256 ironTarget,
        uint256 goldTarget
    ) external onlyAuthorized {
        CityTypes.PlotCore memory plot = cityRegistry.getPlotCore(plotId);
        if (plot.plotType != CityTypes.PlotType.Community) revert CityErrors.InvalidPlotType();
        if (oilTarget == 0 && lemonsTarget == 0 && ironTarget == 0 && goldTarget == 0) {
            revert CityErrors.InvalidValue();
        }

        ProjectFunding storage p = projectOfPlot[plotId];
        if (p.exists && p.active) revert CityErrors.InvalidValue();

        projectOfPlot[plotId] = ProjectFunding({
            oilTarget: oilTarget,
            lemonsTarget: lemonsTarget,
            ironTarget: ironTarget,
            goldTarget: goldTarget,
            oilRaised: 0,
            lemonsRaised: 0,
            ironRaised: 0,
            goldRaised: 0,
            exists: true,
            funded: false,
            active: true
        });

        emit CommunityProjectCreated(plotId, oilTarget, lemonsTarget, ironTarget, goldTarget);
    }

    function getProjectRaised(uint256 plotId)
        external
        view
        override
        returns (uint256 oil, uint256 lemons, uint256 iron, uint256 gold)
    {
        ProjectFunding memory p = projectOfPlot[plotId];
        return (p.oilRaised, p.lemonsRaised, p.ironRaised, p.goldRaised);
    }

    function getProjectTargets(uint256 plotId)
        external
        view
        returns (uint256 oil, uint256 lemons, uint256 iron, uint256 gold)
    {
        ProjectFunding memory p = projectOfPlot[plotId];
        return (p.oilTarget, p.lemonsTarget, p.ironTarget, p.goldTarget);
    }

    function isProjectFunded(uint256 plotId) external view override returns (bool) {
        return projectOfPlot[plotId].funded;
    }

    function contributeToProject(
        uint256 plotId,
        uint256 oilAmount,
        uint256 lemonsAmount,
        uint256 ironAmount,
        uint256 goldAmount
    ) external override {
        ProjectFunding storage p = projectOfPlot[plotId];
        if (!p.exists || !p.active) revert CityErrors.InvalidValue();
        if (p.funded) revert CityErrors.InvalidValue();

        CityTypes.PlotCore memory plot = cityRegistry.getPlotCore(plotId);
        if (plot.plotType != CityTypes.PlotType.Community) revert CityErrors.InvalidPlotType();

        (oilAmount, lemonsAmount, ironAmount, goldAmount) = _capToRemaining(
            p,
            oilAmount,
            lemonsAmount,
            ironAmount,
            goldAmount
        );

        if (oilAmount == 0 && lemonsAmount == 0 && ironAmount == 0 && goldAmount == 0) {
            revert CityErrors.InvalidValue();
        }

        address resourceTokenAddr = cityConfig.getAddressConfig(cityConfig.KEY_RESOURCE_TOKEN());
        if (resourceTokenAddr == address(0)) revert CityErrors.InvalidConfig();

        IResourceToken resourceToken = IResourceToken(resourceTokenAddr);

        if (oilAmount > 0) {
            resourceToken.safeTransferFrom(msg.sender, address(this), RESOURCE_OIL, oilAmount, "");
            p.oilRaised += oilAmount;
            oilContributedBy[plotId][msg.sender] += oilAmount;
        }
        if (lemonsAmount > 0) {
            resourceToken.safeTransferFrom(msg.sender, address(this), RESOURCE_LEMONS, lemonsAmount, "");
            p.lemonsRaised += lemonsAmount;
            lemonsContributedBy[plotId][msg.sender] += lemonsAmount;
        }
        if (ironAmount > 0) {
            resourceToken.safeTransferFrom(msg.sender, address(this), RESOURCE_IRON, ironAmount, "");
            p.ironRaised += ironAmount;
            ironContributedBy[plotId][msg.sender] += ironAmount;
        }
        if (goldAmount > 0) {
            resourceToken.safeTransferFrom(msg.sender, address(this), RESOURCE_GOLD, goldAmount, "");
            p.goldRaised += goldAmount;
            goldContributedBy[plotId][msg.sender] += goldAmount;
        }

        emit CommunityProjectContribution(
            plotId,
            msg.sender,
            oilAmount,
            lemonsAmount,
            ironAmount,
            goldAmount
        );

        if (_isFunded(p)) {
            p.funded = true;
            p.active = false;
            emit CommunityProjectFunded(plotId);
        }
    }

    function closeProject(uint256 plotId) external onlyAuthorized {
        ProjectFunding storage p = projectOfPlot[plotId];
        if (!p.exists || !p.active) revert CityErrors.InvalidValue();

        p.active = false;
        emit CommunityProjectClosed(plotId);
    }

    function _capToRemaining(
        ProjectFunding storage p,
        uint256 oilAmount,
        uint256 lemonsAmount,
        uint256 ironAmount,
        uint256 goldAmount
    ) internal view returns (uint256, uint256, uint256, uint256) {
        uint256 oilRemaining = p.oilTarget > p.oilRaised ? p.oilTarget - p.oilRaised : 0;
        uint256 lemonsRemaining = p.lemonsTarget > p.lemonsRaised ? p.lemonsTarget - p.lemonsRaised : 0;
        uint256 ironRemaining = p.ironTarget > p.ironRaised ? p.ironTarget - p.ironRaised : 0;
        uint256 goldRemaining = p.goldTarget > p.goldRaised ? p.goldTarget - p.goldRaised : 0;

        if (oilAmount > oilRemaining) oilAmount = oilRemaining;
        if (lemonsAmount > lemonsRemaining) lemonsAmount = lemonsRemaining;
        if (ironAmount > ironRemaining) ironAmount = ironRemaining;
        if (goldAmount > goldRemaining) goldAmount = goldRemaining;

        return (oilAmount, lemonsAmount, ironAmount, goldAmount);
    }

    function _isFunded(ProjectFunding storage p) internal view returns (bool) {
        return (
            p.oilRaised >= p.oilTarget &&
            p.lemonsRaised >= p.lemonsTarget &&
            p.ironRaised >= p.ironTarget &&
            p.goldRaised >= p.goldTarget
        );
    }
}