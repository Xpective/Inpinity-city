/* FILE: contracts/city/contracts/adapters/interfaces/ICityLandLike.sol */
/* TYPE: lightweight adapter-side live land interface */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ICityLandLike {
    function isPlotFullyCompleted(uint256 plotId) external view returns (bool);
}