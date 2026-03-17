// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/CityErrors.sol";
import "./CityMateria.sol";

contract CityMateriaItems is ERC1155, Ownable {
    struct MateriaItemDefinition {
        uint256 id;
        uint256 materiaDefinitionId;
        uint256 level;
        uint256 rarityTier;
        bool burnOnUse;
        bool enabled;
    }

    string public baseMetadataURI;

    CityMateria public immutable cityMateria;

    mapping(uint256 => MateriaItemDefinition) public materiaItemDefinitionOf;
    mapping(address => bool) public authorizedMinters;
    mapping(address => bool) public authorizedConsumers;

    event AuthorizedMinterSet(address indexed minter, bool allowed);
    event AuthorizedConsumerSet(address indexed consumer, bool allowed);
    event BaseMetadataURISet(string newBaseMetadataURI);

    event MateriaItemDefinitionSet(
        uint256 indexed itemId,
        uint256 indexed materiaDefinitionId,
        uint256 level,
        uint256 rarityTier,
        bool burnOnUse,
        bool enabled
    );

    event MateriaItemMinted(
        address indexed to,
        uint256 indexed itemId,
        uint256 amount
    );

    event MateriaItemBurned(
        address indexed from,
        uint256 indexed itemId,
        uint256 amount
    );

    constructor(
        address initialOwner,
        address cityMateriaAddress,
        string memory initialURI
    )
        ERC1155(initialURI)
        Ownable(initialOwner)
    {
        if (
            initialOwner == address(0) ||
            cityMateriaAddress == address(0)
        ) {
            revert CityErrors.ZeroAddress();
        }

        cityMateria = CityMateria(cityMateriaAddress);
        baseMetadataURI = initialURI;
    }

    modifier onlyAuthorizedMinter() {
        if (!(msg.sender == owner() || authorizedMinters[msg.sender])) {
            revert CityErrors.NotAuthorized();
        }
        _;
    }

    modifier onlyAuthorizedConsumer() {
        if (!(msg.sender == owner() || authorizedConsumers[msg.sender])) {
            revert CityErrors.NotAuthorized();
        }
        _;
    }

    function setAuthorizedMinter(address minter, bool allowed) external onlyOwner {
        if (minter == address(0)) revert CityErrors.ZeroAddress();
        authorizedMinters[minter] = allowed;
        emit AuthorizedMinterSet(minter, allowed);
    }

    function setAuthorizedConsumer(address consumer, bool allowed) external onlyOwner {
        if (consumer == address(0)) revert CityErrors.ZeroAddress();
        authorizedConsumers[consumer] = allowed;
        emit AuthorizedConsumerSet(consumer, allowed);
    }

    function setBaseMetadataURI(string calldata newBaseMetadataURI) external onlyOwner {
        baseMetadataURI = newBaseMetadataURI;
        emit BaseMetadataURISet(newBaseMetadataURI);
    }

    function uri(uint256 itemId) public view override returns (string memory) {
        return string(abi.encodePacked(baseMetadataURI, _toString(itemId), ".json"));
    }

    function setMateriaItemDefinition(
        uint256 itemId,
        uint256 materiaDefinitionId,
        uint256 level,
        uint256 rarityTier,
        bool burnOnUse,
        bool enabled
    ) external onlyOwner {
        if (itemId == 0) revert CityErrors.InvalidValue();
        if (materiaDefinitionId == 0) revert CityErrors.InvalidValue();
        if (level == 0) revert CityErrors.InvalidValue();

        if (!cityMateria.materiaExists(materiaDefinitionId)) {
            revert CityErrors.InvalidValue();
        }

        if (!cityMateria.isMateriaUsable(materiaDefinitionId, level)) {
            revert CityErrors.InvalidValue();
        }

        materiaItemDefinitionOf[itemId] = MateriaItemDefinition({
            id: itemId,
            materiaDefinitionId: materiaDefinitionId,
            level: level,
            rarityTier: rarityTier,
            burnOnUse: burnOnUse,
            enabled: enabled
        });

        emit MateriaItemDefinitionSet(
            itemId,
            materiaDefinitionId,
            level,
            rarityTier,
            burnOnUse,
            enabled
        );
    }

    function mintMateriaItem(
        address to,
        uint256 itemId,
        uint256 amount
    ) external onlyAuthorizedMinter {
        if (to == address(0)) revert CityErrors.ZeroAddress();
        if (amount == 0) revert CityErrors.InvalidValue();

        MateriaItemDefinition memory def = materiaItemDefinitionOf[itemId];
        if (def.id == 0 || !def.enabled) revert CityErrors.InvalidValue();

        _mint(to, itemId, amount, "");
        emit MateriaItemMinted(to, itemId, amount);
    }

    function burnMateriaItem(
        address from,
        uint256 itemId,
        uint256 amount
    ) external onlyAuthorizedConsumer {
        if (from == address(0)) revert CityErrors.ZeroAddress();
        if (amount == 0) revert CityErrors.InvalidValue();

        MateriaItemDefinition memory def = materiaItemDefinitionOf[itemId];
        if (def.id == 0 || !def.enabled) revert CityErrors.InvalidValue();

        _burn(from, itemId, amount);
        emit MateriaItemBurned(from, itemId, amount);
    }

    function getMateriaItemMeta(
        uint256 itemId
    )
        external
        view
        returns (
            uint256 materiaDefinitionId,
            uint256 level,
            uint256 rarityTier,
            bool burnOnUse,
            bool enabled
        )
    {
        MateriaItemDefinition memory def = materiaItemDefinitionOf[itemId];
        return (
            def.materiaDefinitionId,
            def.level,
            def.rarityTier,
            def.burnOnUse,
            def.enabled
        );
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
