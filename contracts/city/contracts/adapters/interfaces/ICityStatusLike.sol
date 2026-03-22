// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ICityStatusLike {
    function getDerivedStatus(uint256 plotId) external view returns (uint8);
    function isLayerEligible(uint256 plotId) external view returns (bool);
}