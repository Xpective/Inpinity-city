/* FILE: contracts/city/contracts/adapters/interfaces/ICityRegistryLike.sol */
/* TYPE: lightweight adapter-side live registry interface */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ICityRegistryLike {
    struct PlotCore {
        uint256 id;
        uint8 plotType;
        uint8 faction;
        uint8 status;
        address owner;
        uint32 width;
        uint32 height;
        uint64 createdAt;
        bool exists;
    }

    function getPlotCore(uint256 plotId) external view returns (PlotCore memory);
}