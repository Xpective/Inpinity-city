// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

contract CityPoints is Ownable {
    uint8 public constant CATEGORY_BUILD = 1;
    uint8 public constant CATEGORY_CROWDFUNDING = 2;
    uint8 public constant CATEGORY_TRADE = 3;
    uint8 public constant CATEGORY_UPKEEP = 4;
    uint8 public constant CATEGORY_CRAFTING = 5;
    uint8 public constant CATEGORY_DEFENSE = 6;
    uint8 public constant CATEGORY_RESEARCH = 7;
    uint8 public constant CATEGORY_SOCIAL = 8;
    uint8 public constant MAX_CATEGORY = 8;

    struct PlayerPointsData {
        uint256 lifetimePoints;
        uint256 spendablePoints;
        uint256 spentPoints;
        uint256 buildPoints;
        uint256 crowdfundingPoints;
        uint256 tradePoints;
        uint256 upkeepPoints;
        uint256 craftingPoints;
        uint256 defensePoints;
        uint256 researchPoints;
        uint256 socialPoints;
        string customTitle;
    }

    mapping(address => PlayerPointsData) public pointsOf;
    mapping(address => bool) public authorizedCallers;

    uint256[5] public rankThresholds;
    uint256 public titleMinPoints;
    uint256 public maxTitleLength;

    event AuthorizedCallerSet(address indexed caller, bool allowed);
    event PointsAdded(address indexed user, uint256 amount, uint8 indexed category);
    event PointsSpent(address indexed user, uint256 amount);
    event CustomTitleSet(address indexed user, string title);
    event PointsAwarded(
        address indexed user,
        uint256 amount,
        uint8 indexed category,
        bool spendable,
        bytes32 indexed reason,
        uint256 newLifetimePoints,
        uint256 newSpendablePoints
    );
    event RankThresholdsUpdated(
        uint256 rank1,
        uint256 rank2,
        uint256 rank3,
        uint256 rank4,
        uint256 rank5
    );
    event TitleRulesUpdated(uint256 titleMinPoints, uint256 maxTitleLength);

    error NotAuthorized();
    error InvalidValue();
    error InvalidCategory(uint8 category);
    error TitleTooLong(uint256 providedLength, uint256 maxLength);
    error TitleLocked(uint256 requiredPoints, uint256 currentPoints);

    constructor(address initialOwner) Ownable(initialOwner) {
        rankThresholds = [uint256(50), uint256(250), uint256(1000), uint256(2500), uint256(5000)];
        titleMinPoints = 250;
        maxTitleLength = 32;
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

    function setRankThresholds(uint256[5] calldata thresholds) external onlyOwner {
        if (
            thresholds[0] == 0 ||
            thresholds[0] >= thresholds[1] ||
            thresholds[1] >= thresholds[2] ||
            thresholds[2] >= thresholds[3] ||
            thresholds[3] >= thresholds[4]
        ) {
            revert InvalidValue();
        }

        rankThresholds = thresholds;
        emit RankThresholdsUpdated(
            thresholds[0],
            thresholds[1],
            thresholds[2],
            thresholds[3],
            thresholds[4]
        );
    }

    function setTitleRules(uint256 requiredPoints, uint256 maxLength) external onlyOwner {
        if (requiredPoints == 0 || maxLength == 0) revert InvalidValue();
        titleMinPoints = requiredPoints;
        maxTitleLength = maxLength;
        emit TitleRulesUpdated(requiredPoints, maxLength);
    }

    function addPoints(address user, uint256 amount, uint8 category) external onlyAuthorized {
        _award(user, amount, category, true, bytes32(0));
        emit PointsAdded(user, amount, category);
    }

    function awardPoints(
        address user,
        uint256 amount,
        uint8 category,
        bool spendable,
        bytes32 reason
    ) external onlyAuthorized {
        _award(user, amount, category, spendable, reason);
        emit PointsAdded(user, amount, category);
    }

    function spendPoints(address user, uint256 amount) external onlyAuthorized {
        if (user == address(0) || amount == 0) revert InvalidValue();

        PlayerPointsData storage p = pointsOf[user];
        if (p.spendablePoints < amount) revert InvalidValue();

        p.spendablePoints -= amount;
        p.spentPoints += amount;

        emit PointsSpent(user, amount);
    }

    function setCustomTitle(address user, string calldata title) external onlyAuthorized {
        _validateTitle(title);
        if (user == address(0)) revert InvalidValue();
        pointsOf[user].customTitle = title;
        emit CustomTitleSet(user, title);
    }

    function setOwnCustomTitle(string calldata title) external {
        _validateTitle(title);

        uint256 currentPoints = pointsOf[msg.sender].lifetimePoints;
        if (currentPoints < titleMinPoints) {
            revert TitleLocked(titleMinPoints, currentPoints);
        }

        pointsOf[msg.sender].customTitle = title;
        emit CustomTitleSet(msg.sender, title);
    }

    function getRank(address user) external view returns (uint8) {
        uint256 total = pointsOf[user].lifetimePoints;

        if (total >= rankThresholds[4]) return 5;
        if (total >= rankThresholds[3]) return 4;
        if (total >= rankThresholds[2]) return 3;
        if (total >= rankThresholds[1]) return 2;
        if (total >= rankThresholds[0]) return 1;
        return 0;
    }

    function categoryPointsOf(address user, uint8 category) external view returns (uint256) {
        PlayerPointsData memory p = pointsOf[user];

        if (category == CATEGORY_BUILD) return p.buildPoints;
        if (category == CATEGORY_CROWDFUNDING) return p.crowdfundingPoints;
        if (category == CATEGORY_TRADE) return p.tradePoints;
        if (category == CATEGORY_UPKEEP) return p.upkeepPoints;
        if (category == CATEGORY_CRAFTING) return p.craftingPoints;
        if (category == CATEGORY_DEFENSE) return p.defensePoints;
        if (category == CATEGORY_RESEARCH) return p.researchPoints;
        if (category == CATEGORY_SOCIAL) return p.socialPoints;

        revert InvalidCategory(category);
    }

    function getProfile(address user)
        external
        view
        returns (
            uint256 totalPoints,
            uint256 buildPoints,
            uint256 crowdfundingPoints,
            uint256 tradePoints,
            uint256 upkeepPoints,
            string memory customTitle
        )
    {
        PlayerPointsData memory p = pointsOf[user];
        return (
            p.lifetimePoints,
            p.buildPoints,
            p.crowdfundingPoints,
            p.tradePoints,
            p.upkeepPoints,
            p.customTitle
        );
    }

    function getProfileV2(address user)
        external
        view
        returns (
            uint256 lifetimePoints,
            uint256 spendablePoints,
            uint256 spentPoints,
            uint256 buildPoints,
            uint256 crowdfundingPoints,
            uint256 tradePoints,
            uint256 upkeepPoints,
            uint256 craftingPoints,
            uint256 defensePoints,
            uint256 researchPoints,
            uint256 socialPoints,
            uint8 rank,
            string memory customTitle
        )
    {
        PlayerPointsData memory p = pointsOf[user];
        rank = _rankFromTotal(p.lifetimePoints);

        return (
            p.lifetimePoints,
            p.spendablePoints,
            p.spentPoints,
            p.buildPoints,
            p.crowdfundingPoints,
            p.tradePoints,
            p.upkeepPoints,
            p.craftingPoints,
            p.defensePoints,
            p.researchPoints,
            p.socialPoints,
            rank,
            p.customTitle
        );
    }

    function _award(
        address user,
        uint256 amount,
        uint8 category,
        bool spendable,
        bytes32 reason
    ) internal {
        if (user == address(0) || amount == 0) revert InvalidValue();
        if (category == 0 || category > MAX_CATEGORY) revert InvalidCategory(category);

        PlayerPointsData storage p = pointsOf[user];
        p.lifetimePoints += amount;
        if (spendable) {
            p.spendablePoints += amount;
        }

        if (category == CATEGORY_BUILD) {
            p.buildPoints += amount;
        } else if (category == CATEGORY_CROWDFUNDING) {
            p.crowdfundingPoints += amount;
        } else if (category == CATEGORY_TRADE) {
            p.tradePoints += amount;
        } else if (category == CATEGORY_UPKEEP) {
            p.upkeepPoints += amount;
        } else if (category == CATEGORY_CRAFTING) {
            p.craftingPoints += amount;
        } else if (category == CATEGORY_DEFENSE) {
            p.defensePoints += amount;
        } else if (category == CATEGORY_RESEARCH) {
            p.researchPoints += amount;
        } else if (category == CATEGORY_SOCIAL) {
            p.socialPoints += amount;
        } else {
            revert InvalidCategory(category);
        }

        emit PointsAwarded(
            user,
            amount,
            category,
            spendable,
            reason,
            p.lifetimePoints,
            p.spendablePoints
        );
    }

    function _validateTitle(string calldata title) internal view {
        uint256 len = bytes(title).length;
        if (len > maxTitleLength) {
            revert TitleTooLong(len, maxTitleLength);
        }
    }

    function _rankFromTotal(uint256 total) internal view returns (uint8) {
        if (total >= rankThresholds[4]) return 5;
        if (total >= rankThresholds[3]) return 4;
        if (total >= rankThresholds[2]) return 3;
        if (total >= rankThresholds[1]) return 2;
        if (total >= rankThresholds[0]) return 1;
        return 0;
    }
}
