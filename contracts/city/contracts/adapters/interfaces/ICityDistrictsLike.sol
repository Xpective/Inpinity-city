/* FILE: contracts/city/contracts/adapters/interfaces/ICityDistrictsLike.sol */
/* TYPE: lightweight adapter-side live districts interface */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ICityDistrictsLike {
    struct DistrictData {
        uint8 kind;
        uint8 faction;
        uint32 bonusBps;
        bool exists;
    }

    function getDistrict(uint256 plotId) external view returns (DistrictData memory);
    function isBorderline(uint256 plotId) external view returns (bool);
}