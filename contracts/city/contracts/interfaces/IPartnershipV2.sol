// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPartnershipV2 {
    function isPartnerBlock(uint256 tokenId) external view returns (bool);
    function getPartnerBlock(uint256 partnerId) external view returns (uint256);
    function inpinityNFT() external view returns (address);
    function farming() external view returns (address);
}