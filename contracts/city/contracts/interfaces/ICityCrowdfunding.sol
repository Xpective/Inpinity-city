// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ICityCrowdfunding {
    function getProjectRaised(uint256 plotId)
        external
        view
        returns (uint256 oil, uint256 lemons, uint256 iron, uint256 gold);

    function isProjectFunded(uint256 plotId) external view returns (bool);

    function contributeToProject(
        uint256 plotId,
        uint256 oilAmount,
        uint256 lemonsAmount,
        uint256 ironAmount,
        uint256 goldAmount
    ) external;
}