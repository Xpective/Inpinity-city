// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IInpinityNFT {
    function ownerOf(uint256 tokenId) external view returns (address);

    function getBlockPosition(uint256 tokenId)
        external
        view
        returns (uint16 row, uint16 col);

    function currentMaxRow() external view returns (uint16);

    function MAX_ROWS() external view returns (uint16);
}