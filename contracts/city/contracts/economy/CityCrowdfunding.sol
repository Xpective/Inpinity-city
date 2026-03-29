// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../libraries/CityTypes.sol";
import "../interfaces/ICityConfig.sol";
import "../interfaces/ICityRegistryRead.sol";
import "../interfaces/IResourceToken.sol";
import "../interfaces/ICityCrowdfunding.sol";
import "../interfaces/ICityPoints.sol";

contract CityCrowdfunding is Ownable, ERC1155Holder, ReentrancyGuard, ICityCrowdfunding {
    uint8 public constant RESOURCE_COUNT = 10;
    uint8 public constant RESOURCE_OIL = 0;
    uint8 public constant RESOURCE_LEMONS = 1;
    uint8 public constant RESOURCE_IRON = 2;
    uint8 public constant RESOURCE_GOLD = 3;
    uint8 public constant CATEGORY_CROWDFUNDING_POINTS = 2;

    enum ProjectState {
        None,
        Active,
        Funded,
        Released,
        Cancelled,
        Failed
    }

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

    struct ProjectData {
        address beneficiary;
        uint64 createdAt;
        uint64 deadline;
        uint64 fundedAt;
        uint64 releasedAt;
        ProjectState state;
        bool exists;
        uint256[10] targets;
        uint256[10] raised;
    }

    ICityConfig public immutable cityConfig;
    ICityRegistryRead public immutable cityRegistry;

    address public cityPoints;
    uint64 public defaultProjectDuration;

    mapping(address => bool) public authorizedCallers;
    mapping(uint256 => ProjectFunding) public projectOfPlot;
    mapping(uint256 => mapping(address => uint256)) public oilContributedBy;
    mapping(uint256 => mapping(address => uint256)) public lemonsContributedBy;
    mapping(uint256 => mapping(address => uint256)) public ironContributedBy;
    mapping(uint256 => mapping(address => uint256)) public goldContributedBy;
    mapping(uint8 => uint32) public pointsWeightOf;

    mapping(uint256 => ProjectData) private _projectDataOf;
    mapping(uint256 => mapping(address => uint256[10])) private _contributedOf;

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
    event CommunityProjectFailed(uint256 indexed plotId);
    event CommunityProjectReleased(uint256 indexed plotId, address indexed beneficiary);
    event CommunityProjectCreatedV2(
        uint256 indexed plotId,
        address indexed beneficiary,
        uint64 deadline,
        uint8[] resourceIds,
        uint256[] targetAmounts
    );
    event CommunityProjectContributionV2(
        uint256 indexed plotId,
        address indexed contributor,
        uint8[] resourceIds,
        uint256[] amounts
    );
    event CommunityProjectRefunded(
        uint256 indexed plotId,
        address indexed contributor,
        uint8[] resourceIds,
        uint256[] amounts
    );
    event CityPointsSet(address indexed cityPointsAddress);
    event DefaultProjectDurationSet(uint64 duration);
    event ResourcePointsWeightSet(uint8 indexed resourceId, uint32 weight);

    error NotAuthorized();
    error InvalidValue();
    error InvalidConfig();
    error InvalidArrayLength();
    error InvalidResourceId(uint8 resourceId);
    error InvalidPlotType(uint256 plotId, uint8 plotType);
    error ProjectAlreadyExists(uint256 plotId);
    error ProjectNotFound(uint256 plotId);
    error ProjectNotActive(uint256 plotId);
    error ProjectNotFunded(uint256 plotId);
    error ProjectNotRefundable(uint256 plotId);
    error ProjectDeadlinePassed(uint256 plotId, uint256 deadline);
    error ResourceNotRequested(uint256 plotId, uint8 resourceId);
    error NothingToRefund(uint256 plotId, address contributor);

    constructor(
        address initialOwner,
        address cityConfigAddress,
        address cityRegistryAddress
    ) Ownable(initialOwner) {
        if (cityConfigAddress == address(0) || cityRegistryAddress == address(0)) {
            revert InvalidValue();
        }

        cityConfig = ICityConfig(cityConfigAddress);
        cityRegistry = ICityRegistryRead(cityRegistryAddress);
        defaultProjectDuration = 30 days;

        for (uint8 i = 0; i < RESOURCE_COUNT; i++) {
            pointsWeightOf[i] = 1;
        }
    }

    modifier onlyAuthorized() {
        if (!(msg.sender == owner() || authorizedCallers[msg.sender])) {
            revert NotAuthorized();
        }
        _;
    }

    function setAuthorizedCaller(address caller, bool allowed) external onlyOwner {
        if (caller == address(0)) revert InvalidValue();
        authorizedCallers[caller] = allowed;
        emit AuthorizedCallerSet(caller, allowed);
    }

    function setCityPoints(address cityPointsAddress) external onlyOwner {
        cityPoints = cityPointsAddress;
        emit CityPointsSet(cityPointsAddress);
    }

    function setDefaultProjectDuration(uint64 duration) external onlyOwner {
        defaultProjectDuration = duration;
        emit DefaultProjectDurationSet(duration);
    }

    function setResourcePointsWeight(uint8 resourceId, uint32 weight) external onlyOwner {
        if (resourceId >= RESOURCE_COUNT) revert InvalidResourceId(resourceId);
        pointsWeightOf[resourceId] = weight;
        emit ResourcePointsWeightSet(resourceId, weight);
    }

    function createProject(
        uint256 plotId,
        uint256 oilTarget,
        uint256 lemonsTarget,
        uint256 ironTarget,
        uint256 goldTarget
    ) external onlyAuthorized {
        uint256 count;
        if (oilTarget > 0) count++;
        if (lemonsTarget > 0) count++;
        if (ironTarget > 0) count++;
        if (goldTarget > 0) count++;
        if (count == 0) revert InvalidValue();

        uint8[] memory resourceIds = new uint8[](count);
        uint256[] memory targetAmounts = new uint256[](count);
        uint256 index;

        if (oilTarget > 0) {
            resourceIds[index] = RESOURCE_OIL;
            targetAmounts[index] = oilTarget;
            index++;
        }
        if (lemonsTarget > 0) {
            resourceIds[index] = RESOURCE_LEMONS;
            targetAmounts[index] = lemonsTarget;
            index++;
        }
        if (ironTarget > 0) {
            resourceIds[index] = RESOURCE_IRON;
            targetAmounts[index] = ironTarget;
            index++;
        }
        if (goldTarget > 0) {
            resourceIds[index] = RESOURCE_GOLD;
            targetAmounts[index] = goldTarget;
        }

        uint64 deadline = defaultProjectDuration == 0
            ? 0
            : uint64(block.timestamp + defaultProjectDuration);

        _createProject(plotId, _defaultBeneficiary(), deadline, resourceIds, targetAmounts);
    }

    function createProjectV2(
        uint256 plotId,
        address beneficiary,
        uint64 deadline,
        uint8[] calldata resourceIds,
        uint256[] calldata targetAmounts
    ) external onlyAuthorized {
        address resolvedBeneficiary = beneficiary == address(0) ? _defaultBeneficiary() : beneficiary;
        _createProject(plotId, resolvedBeneficiary, deadline, resourceIds, targetAmounts);
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
        ProjectData memory p = _projectDataOf[plotId];
        if (!p.exists) return false;
        ProjectState state = _viewProjectState(p);
        return state == ProjectState.Funded || state == ProjectState.Released;
    }

    function getProjectState(uint256 plotId) external view returns (uint8) {
        ProjectData memory p = _projectDataOf[plotId];
        if (!p.exists) return uint8(ProjectState.None);
        return uint8(_viewProjectState(p));
    }

    function getProjectMeta(uint256 plotId)
        external
        view
        returns (
            address beneficiary,
            uint64 createdAt,
            uint64 deadline,
            uint64 fundedAt,
            uint64 releasedAt,
            uint8 state
        )
    {
        ProjectData memory p = _projectDataOf[plotId];
        if (!p.exists) revert ProjectNotFound(plotId);
        ProjectState resolvedState = _viewProjectState(p);
        return (
            p.beneficiary,
            p.createdAt,
            p.deadline,
            p.fundedAt,
            p.releasedAt,
            uint8(resolvedState)
        );
    }

    function getProjectBasket(uint256 plotId)
        external
        view
        returns (uint8[] memory resourceIds, uint256[] memory targetAmounts, uint256[] memory raisedAmounts)
    {
        ProjectData memory p = _projectDataOf[plotId];
        if (!p.exists) revert ProjectNotFound(plotId);
        return _compressBasket(p.targets, p.raised);
    }

    function getContributionOf(uint256 plotId, address contributor)
        external
        view
        returns (uint256[10] memory amounts)
    {
        return _contributedOf[plotId][contributor];
    }

    function contributeToProject(
        uint256 plotId,
        uint256 oilAmount,
        uint256 lemonsAmount,
        uint256 ironAmount,
        uint256 goldAmount
    ) external override {
        uint256 count;
        if (oilAmount > 0) count++;
        if (lemonsAmount > 0) count++;
        if (ironAmount > 0) count++;
        if (goldAmount > 0) count++;
        if (count == 0) revert InvalidValue();

        uint8[] memory resourceIds = new uint8[](count);
        uint256[] memory amounts = new uint256[](count);
        uint256 index;

        if (oilAmount > 0) {
            resourceIds[index] = RESOURCE_OIL;
            amounts[index] = oilAmount;
            index++;
        }
        if (lemonsAmount > 0) {
            resourceIds[index] = RESOURCE_LEMONS;
            amounts[index] = lemonsAmount;
            index++;
        }
        if (ironAmount > 0) {
            resourceIds[index] = RESOURCE_IRON;
            amounts[index] = ironAmount;
            index++;
        }
        if (goldAmount > 0) {
            resourceIds[index] = RESOURCE_GOLD;
            amounts[index] = goldAmount;
        }

        _contribute(plotId, resourceIds, amounts);
    }

    function contributeToProjectV2(
        uint256 plotId,
        uint8[] calldata resourceIds,
        uint256[] calldata amounts
    ) external {
        _contribute(plotId, resourceIds, amounts);
    }

    function closeProject(uint256 plotId) external onlyAuthorized {
        ProjectData storage p = _projectDataOf[plotId];
        if (!p.exists) revert ProjectNotFound(plotId);

        _syncProjectState(plotId, p);
        if (p.state != ProjectState.Active) revert ProjectNotActive(plotId);

        p.state = ProjectState.Cancelled;
        _syncLegacyProject(plotId);

        emit CommunityProjectClosed(plotId);
    }

    function releaseProjectFunds(uint256 plotId) external onlyAuthorized nonReentrant {
        ProjectData storage p = _projectDataOf[plotId];
        if (!p.exists) revert ProjectNotFound(plotId);

        _syncProjectState(plotId, p);
        if (p.state != ProjectState.Funded) revert ProjectNotFunded(plotId);

        IResourceToken resourceToken = _resourceToken();
        for (uint8 resourceId = 0; resourceId < RESOURCE_COUNT; resourceId++) {
            uint256 amount = p.raised[resourceId];
            if (amount == 0) continue;
            resourceToken.safeTransferFrom(address(this), p.beneficiary, resourceId, amount, "");
        }

        p.state = ProjectState.Released;
        p.releasedAt = uint64(block.timestamp);
        _syncLegacyProject(plotId);

        emit CommunityProjectReleased(plotId, p.beneficiary);
    }

    function claimRefund(uint256 plotId) external nonReentrant {
        ProjectData storage p = _projectDataOf[plotId];
        if (!p.exists) revert ProjectNotFound(plotId);

        _syncProjectState(plotId, p);
        if (p.state != ProjectState.Cancelled && p.state != ProjectState.Failed) {
            revert ProjectNotRefundable(plotId);
        }

        IResourceToken resourceToken = _resourceToken();
        uint8[] memory resourceIds = new uint8[](RESOURCE_COUNT);
        uint256[] memory refundAmounts = new uint256[](RESOURCE_COUNT);
        uint256 refundCount;

        for (uint8 resourceId = 0; resourceId < RESOURCE_COUNT; resourceId++) {
            uint256 amount = _contributedOf[plotId][msg.sender][resourceId];
            if (amount == 0) continue;

            _contributedOf[plotId][msg.sender][resourceId] = 0;
            if (p.raised[resourceId] >= amount) {
                p.raised[resourceId] -= amount;
            } else {
                p.raised[resourceId] = 0;
            }

            resourceIds[refundCount] = resourceId;
            refundAmounts[refundCount] = amount;
            refundCount++;

            resourceToken.safeTransferFrom(address(this), msg.sender, resourceId, amount, "");
        }

        if (refundCount == 0) revert NothingToRefund(plotId, msg.sender);

        oilContributedBy[plotId][msg.sender] = 0;
        lemonsContributedBy[plotId][msg.sender] = 0;
        ironContributedBy[plotId][msg.sender] = 0;
        goldContributedBy[plotId][msg.sender] = 0;
        _syncLegacyProject(plotId);

        (uint8[] memory compactIds, uint256[] memory compactAmounts) = _trimEventArrays(
            resourceIds,
            refundAmounts,
            refundCount
        );
        emit CommunityProjectRefunded(plotId, msg.sender, compactIds, compactAmounts);
    }

    function syncProjectState(uint256 plotId) external {
        ProjectData storage p = _projectDataOf[plotId];
        if (!p.exists) revert ProjectNotFound(plotId);
        _syncProjectState(plotId, p);
        _syncLegacyProject(plotId);
    }

    function _createProject(
        uint256 plotId,
        address beneficiary,
        uint64 deadline,
        uint8[] memory resourceIds,
        uint256[] memory targetAmounts
    ) internal {
        CityTypes.PlotCore memory plot = cityRegistry.getPlotCore(plotId);
        if (plot.plotType != CityTypes.PlotType.Community) {
            revert InvalidPlotType(plotId, uint8(plot.plotType));
        }
        if (beneficiary == address(0)) revert InvalidConfig();
        if (resourceIds.length == 0 || resourceIds.length != targetAmounts.length) {
            revert InvalidArrayLength();
        }
        if (deadline != 0 && deadline <= block.timestamp) revert InvalidValue();

        ProjectData storage p = _projectDataOf[plotId];
        if (p.exists) revert ProjectAlreadyExists(plotId);

        p.exists = true;
        p.state = ProjectState.Active;
        p.beneficiary = beneficiary;
        p.createdAt = uint64(block.timestamp);
        p.deadline = deadline;

        for (uint256 i = 0; i < resourceIds.length; i++) {
            uint8 resourceId = resourceIds[i];
            uint256 targetAmount = targetAmounts[i];

            if (resourceId >= RESOURCE_COUNT) revert InvalidResourceId(resourceId);
            if (targetAmount == 0) revert InvalidValue();
            if (p.targets[resourceId] != 0) revert InvalidValue();

            p.targets[resourceId] = targetAmount;
        }

        _syncLegacyProject(plotId);

        emit CommunityProjectCreated(
            plotId,
            p.targets[RESOURCE_OIL],
            p.targets[RESOURCE_LEMONS],
            p.targets[RESOURCE_IRON],
            p.targets[RESOURCE_GOLD]
        );
        emit CommunityProjectCreatedV2(plotId, beneficiary, deadline, resourceIds, targetAmounts);
    }

    function _contribute(
        uint256 plotId,
        uint8[] memory resourceIds,
        uint256[] memory amounts
    ) internal nonReentrant {
        if (resourceIds.length == 0 || resourceIds.length != amounts.length) {
            revert InvalidArrayLength();
        }

        ProjectData storage p = _projectDataOf[plotId];
        if (!p.exists) revert ProjectNotFound(plotId);

        _syncProjectState(plotId, p);
        if (p.state != ProjectState.Active) revert ProjectNotActive(plotId);

        CityTypes.PlotCore memory plot = cityRegistry.getPlotCore(plotId);
        if (plot.plotType != CityTypes.PlotType.Community) {
            revert InvalidPlotType(plotId, uint8(plot.plotType));
        }

        IResourceToken resourceToken = _resourceToken();

        uint256[10] memory accepted;
        uint256 pointsToAward;
        bool hasAcceptedContribution;

        for (uint256 i = 0; i < resourceIds.length; i++) {
            uint8 resourceId = resourceIds[i];
            uint256 amount = amounts[i];

            if (resourceId >= RESOURCE_COUNT) revert InvalidResourceId(resourceId);
            if (amount == 0) continue;
            if (p.targets[resourceId] == 0) revert ResourceNotRequested(plotId, resourceId);

            uint256 remaining = p.targets[resourceId] > p.raised[resourceId]
                ? p.targets[resourceId] - p.raised[resourceId]
                : 0;
            if (remaining == 0) continue;
            if (amount > remaining) {
                amount = remaining;
            }

            resourceToken.safeTransferFrom(msg.sender, address(this), resourceId, amount, "");

            p.raised[resourceId] += amount;
            _contributedOf[plotId][msg.sender][resourceId] += amount;
            accepted[resourceId] += amount;
            pointsToAward += amount * pointsWeightOf[resourceId];
            hasAcceptedContribution = true;
        }

        if (!hasAcceptedContribution) revert InvalidValue();

        _syncLegacyContribution(plotId, msg.sender);
        _syncLegacyProject(plotId);

        emit CommunityProjectContribution(
            plotId,
            msg.sender,
            accepted[RESOURCE_OIL],
            accepted[RESOURCE_LEMONS],
            accepted[RESOURCE_IRON],
            accepted[RESOURCE_GOLD]
        );

        (uint8[] memory compactIds, uint256[] memory compactAmounts) = _compressAccepted(accepted);
        emit CommunityProjectContributionV2(plotId, msg.sender, compactIds, compactAmounts);

        if (_isFunded(p)) {
            p.state = ProjectState.Funded;
            p.fundedAt = uint64(block.timestamp);
            _syncLegacyProject(plotId);
            emit CommunityProjectFunded(plotId);
        }

        if (cityPoints != address(0) && pointsToAward > 0) {
            try ICityPoints(cityPoints).addPoints(msg.sender, pointsToAward, CATEGORY_CROWDFUNDING_POINTS) {} catch {}
        }
    }

    function _resourceToken() internal view returns (IResourceToken) {
        address resourceTokenAddr = cityConfig.getAddressConfig(cityConfig.KEY_RESOURCE_TOKEN());
        if (resourceTokenAddr == address(0)) revert InvalidConfig();
        return IResourceToken(resourceTokenAddr);
    }

    function _defaultBeneficiary() internal view returns (address) {
        address treasury = cityConfig.getAddressConfig(cityConfig.KEY_TREASURY());
        if (treasury == address(0)) revert InvalidConfig();
        return treasury;
    }

    function _syncLegacyProject(uint256 plotId) internal {
        ProjectData storage p = _projectDataOf[plotId];
        ProjectFunding storage legacy = projectOfPlot[plotId];

        legacy.oilTarget = p.targets[RESOURCE_OIL];
        legacy.lemonsTarget = p.targets[RESOURCE_LEMONS];
        legacy.ironTarget = p.targets[RESOURCE_IRON];
        legacy.goldTarget = p.targets[RESOURCE_GOLD];
        legacy.oilRaised = p.raised[RESOURCE_OIL];
        legacy.lemonsRaised = p.raised[RESOURCE_LEMONS];
        legacy.ironRaised = p.raised[RESOURCE_IRON];
        legacy.goldRaised = p.raised[RESOURCE_GOLD];
        legacy.exists = p.exists;
        legacy.funded = _isFunded(p) || p.state == ProjectState.Released;
        legacy.active = p.state == ProjectState.Active;
    }

    function _syncLegacyContribution(uint256 plotId, address contributor) internal {
        oilContributedBy[plotId][contributor] = _contributedOf[plotId][contributor][RESOURCE_OIL];
        lemonsContributedBy[plotId][contributor] = _contributedOf[plotId][contributor][RESOURCE_LEMONS];
        ironContributedBy[plotId][contributor] = _contributedOf[plotId][contributor][RESOURCE_IRON];
        goldContributedBy[plotId][contributor] = _contributedOf[plotId][contributor][RESOURCE_GOLD];
    }

    function _syncProjectState(uint256 plotId, ProjectData storage p) internal {
        if (!p.exists) return;
        if (p.state != ProjectState.Active) return;

        if (_isFunded(p)) {
            p.state = ProjectState.Funded;
            if (p.fundedAt == 0) {
                p.fundedAt = uint64(block.timestamp);
                emit CommunityProjectFunded(plotId);
            }
            return;
        }

        if (p.deadline != 0 && block.timestamp > p.deadline) {
            p.state = ProjectState.Failed;
            emit CommunityProjectFailed(plotId);
        }
    }

    function _viewProjectState(ProjectData memory p) internal view returns (ProjectState) {
        if (!p.exists) return ProjectState.None;
        if (p.state != ProjectState.Active) return p.state;
        if (_isFunded(p)) return ProjectState.Funded;
        if (p.deadline != 0 && block.timestamp > p.deadline) return ProjectState.Failed;
        return ProjectState.Active;
    }

    function _isFunded(ProjectData storage p) internal view returns (bool) {
        for (uint8 resourceId = 0; resourceId < RESOURCE_COUNT; resourceId++) {
            uint256 target = p.targets[resourceId];
            if (target == 0) continue;
            if (p.raised[resourceId] < target) return false;
        }
        return true;
    }

    function _isFunded(ProjectData memory p) internal pure returns (bool) {
        for (uint8 resourceId = 0; resourceId < RESOURCE_COUNT; resourceId++) {
            uint256 target = p.targets[resourceId];
            if (target == 0) continue;
            if (p.raised[resourceId] < target) return false;
        }
        return true;
    }

    function _compressBasket(uint256[10] memory targets, uint256[10] memory raised)
        internal
        pure
        returns (uint8[] memory resourceIds, uint256[] memory targetAmounts, uint256[] memory raisedAmounts)
    {
        uint256 count;
        for (uint8 resourceId = 0; resourceId < RESOURCE_COUNT; resourceId++) {
            if (targets[resourceId] > 0 || raised[resourceId] > 0) {
                count++;
            }
        }

        resourceIds = new uint8[](count);
        targetAmounts = new uint256[](count);
        raisedAmounts = new uint256[](count);

        uint256 index;
        for (uint8 resourceId = 0; resourceId < RESOURCE_COUNT; resourceId++) {
            if (targets[resourceId] == 0 && raised[resourceId] == 0) continue;
            resourceIds[index] = resourceId;
            targetAmounts[index] = targets[resourceId];
            raisedAmounts[index] = raised[resourceId];
            index++;
        }
    }

    function _compressAccepted(uint256[10] memory accepted)
        internal
        pure
        returns (uint8[] memory resourceIds, uint256[] memory amounts)
    {
        uint256 count;
        for (uint8 resourceId = 0; resourceId < RESOURCE_COUNT; resourceId++) {
            if (accepted[resourceId] > 0) count++;
        }

        resourceIds = new uint8[](count);
        amounts = new uint256[](count);

        uint256 index;
        for (uint8 resourceId = 0; resourceId < RESOURCE_COUNT; resourceId++) {
            uint256 amount = accepted[resourceId];
            if (amount == 0) continue;
            resourceIds[index] = resourceId;
            amounts[index] = amount;
            index++;
        }
    }

    function _trimEventArrays(
        uint8[] memory resourceIds,
        uint256[] memory amounts,
        uint256 count
    ) internal pure returns (uint8[] memory compactIds, uint256[] memory compactAmounts) {
        compactIds = new uint8[](count);
        compactAmounts = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            compactIds[i] = resourceIds[i];
            compactAmounts[i] = amounts[i];
        }
    }
}
