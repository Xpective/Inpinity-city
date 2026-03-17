// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/CityErrors.sol";

contract CityPoints is Ownable {
    struct PlayerPointsData {
        uint256 totalPoints;
        uint256 buildPoints;
        uint256 crowdfundingPoints;
        uint256 tradePoints;
        uint256 upkeepPoints;
        string customTitle;
    }

    mapping(address => PlayerPointsData) public pointsOf;
    mapping(address => bool) public authorizedCallers;

    event AuthorizedCallerSet(address indexed caller, bool allowed);
    event PointsAdded(address indexed user, uint256 amount, uint8 indexed category);
    event PointsSpent(address indexed user, uint256 amount);
    event CustomTitleSet(address indexed user, string title);

    constructor(address initialOwner) Ownable(initialOwner) {
        if (initialOwner == address(0)) revert CityErrors.ZeroAddress();
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

    // 1 = build, 2 = crowdfunding, 3 = trade, 4 = upkeep
    function addPoints(address user, uint256 amount, uint8 category) external onlyAuthorized {
        if (user == address(0)) revert CityErrors.ZeroAddress();
        if (amount == 0) revert CityErrors.InvalidValue();

        PlayerPointsData storage p = pointsOf[user];
        p.totalPoints += amount;

        if (category == 1) {
            p.buildPoints += amount;
        } else if (category == 2) {
            p.crowdfundingPoints += amount;
        } else if (category == 3) {
            p.tradePoints += amount;
        } else if (category == 4) {
            p.upkeepPoints += amount;
        } else {
            revert CityErrors.InvalidValue();
        }

        emit PointsAdded(user, amount, category);
    }

    function spendPoints(address user, uint256 amount) external onlyAuthorized {
        if (user == address(0)) revert CityErrors.ZeroAddress();
        if (amount == 0) revert CityErrors.InvalidValue();

        PlayerPointsData storage p = pointsOf[user];
        if (p.totalPoints < amount) revert CityErrors.InvalidValue();

        p.totalPoints -= amount;
        emit PointsSpent(user, amount);
    }

    function setCustomTitle(address user, string calldata title) external onlyAuthorized {
        if (user == address(0)) revert CityErrors.ZeroAddress();
        pointsOf[user].customTitle = title;
        emit CustomTitleSet(user, title);
    }

    function getRank(address user) external view returns (uint8) {
        uint256 total = pointsOf[user].totalPoints;

        if (total >= 5000) return 5;
        if (total >= 2500) return 4;
        if (total >= 1000) return 3;
        if (total >= 250) return 2;
        if (total >= 50) return 1;
        return 0;
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
            p.totalPoints,
            p.buildPoints,
            p.crowdfundingPoints,
            p.tradePoints,
            p.upkeepPoints,
            p.customTitle
        );
    }
}