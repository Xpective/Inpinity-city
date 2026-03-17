// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/CityErrors.sol";

contract CityBlueprints is ERC1155, Ownable {
    struct BlueprintDefinition {
        uint256 id;
        string name;
        uint256 rarityTier;
        uint256 techTier;
        uint256 factionLock;      // 0 = none
        uint256 districtLock;     // 0 = none
        bool enabled;
    }

    string public baseMetadataURI;

    mapping(uint256 => BlueprintDefinition) public blueprintDefinitionOf;
    mapping(address => bool) public authorizedMinters;

    event AuthorizedMinterSet(address indexed minter, bool allowed);
    event BaseMetadataURISet(string newBaseMetadataURI);

    event BlueprintDefinitionSet(
        uint256 indexed blueprintId,
        string name,
        uint256 rarityTier,
        uint256 techTier,
        uint256 factionLock,
        uint256 districtLock,
        bool enabled
    );

    event BlueprintMinted(
        address indexed to,
        uint256 indexed blueprintId,
        uint256 amount
    );

    constructor(address initialOwner, string memory initialURI)
        ERC1155(initialURI)
        Ownable(initialOwner)
    {
        if (initialOwner == address(0)) revert CityErrors.ZeroAddress();
        baseMetadataURI = initialURI;
    }

    modifier onlyAuthorizedMinter() {
        if (!(msg.sender == owner() || authorizedMinters[msg.sender])) {
            revert CityErrors.NotAuthorized();
        }
        _;
    }

    function setAuthorizedMinter(address minter, bool allowed) external onlyOwner {
        if (minter == address(0)) revert CityErrors.ZeroAddress();
        authorizedMinters[minter] = allowed;
        emit AuthorizedMinterSet(minter, allowed);
    }

    function setBaseMetadataURI(string calldata newBaseMetadataURI) external onlyOwner {
        baseMetadataURI = newBaseMetadataURI;
        emit BaseMetadataURISet(newBaseMetadataURI);
    }

    function uri(uint256 blueprintId) public view override returns (string memory) {
        return string(abi.encodePacked(baseMetadataURI, _toString(blueprintId), ".json"));
    }

    function setBlueprintDefinition(
        uint256 blueprintId,
        string calldata name,
        uint256 rarityTier,
        uint256 techTier,
        uint256 factionLock,
        uint256 districtLock,
        bool enabled
    ) external onlyOwner {
        if (blueprintId == 0) revert CityErrors.InvalidValue();
        if (bytes(name).length == 0) revert CityErrors.InvalidValue();

        blueprintDefinitionOf[blueprintId] = BlueprintDefinition({
            id: blueprintId,
            name: name,
            rarityTier: rarityTier,
            techTier: techTier,
            factionLock: factionLock,
            districtLock: districtLock,
            enabled: enabled
        });

        emit BlueprintDefinitionSet(
            blueprintId,
            name,
            rarityTier,
            techTier,
            factionLock,
            districtLock,
            enabled
        );
    }

    function mintBlueprint(
        address to,
        uint256 blueprintId,
        uint256 amount
    ) external onlyAuthorizedMinter {
        if (to == address(0)) revert CityErrors.ZeroAddress();
        if (amount == 0) revert CityErrors.InvalidValue();

        BlueprintDefinition memory def = blueprintDefinitionOf[blueprintId];
        if (def.id == 0 || !def.enabled) revert CityErrors.InvalidValue();

        _mint(to, blueprintId, amount, "");
        emit BlueprintMinted(to, blueprintId, amount);
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";

        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }

        return string(buffer);
    }
}