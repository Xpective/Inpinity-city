// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/CityErrors.sol";
import "./CityEnchantments.sol";

contract CityEnchantmentItems is ERC1155, Ownable {
    struct EnchantmentItemDefinition {
        uint256 id;
        uint256 enchantmentDefinitionId;
        uint256 level;
        uint256 rarityTier;
        bool burnOnUse;
        bool enabled;
    }

    string public baseMetadataURI;

    CityEnchantments public immutable cityEnchantments;

    mapping(uint256 => EnchantmentItemDefinition) public enchantmentItemDefinitionOf;
    mapping(address => bool) public authorizedMinters;
    mapping(address => bool) public authorizedConsumers;

    event AuthorizedMinterSet(address indexed minter, bool allowed);
    event AuthorizedConsumerSet(address indexed consumer, bool allowed);
    event BaseMetadataURISet(string newBaseMetadataURI);

    event EnchantmentItemDefinitionSet(
        uint256 indexed itemId,
        uint256 indexed enchantmentDefinitionId,
        uint256 level,
        uint256 rarityTier,
        bool burnOnUse,
        bool enabled
    );

    event EnchantmentItemMinted(
        address indexed to,
        uint256 indexed itemId,
        uint256 amount
    );

    event EnchantmentItemBurned(
        address indexed from,
        uint256 indexed itemId,
        uint256 amount
    );

    constructor(
        address initialOwner,
        address cityEnchantmentsAddress,
        string memory initialURI
    )
        ERC1155(initialURI)
        Ownable(initialOwner)
    {
        if (
            initialOwner == address(0) ||
            cityEnchantmentsAddress == address(0)
        ) {
            revert CityErrors.ZeroAddress();
        }

        cityEnchantments = CityEnchantments(cityEnchantmentsAddress);
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

    function setEnchantmentItemDefinition(
        uint256 itemId,
        uint256 enchantmentDefinitionId,
        uint256 level,
        uint256 rarityTier,
        bool burnOnUse,
        bool enabled
    ) external onlyOwner {
        if (itemId == 0) revert CityErrors.InvalidValue();
        if (enchantmentDefinitionId == 0) revert CityErrors.InvalidValue();
        if (level == 0) revert CityErrors.InvalidValue();

        if (!cityEnchantments.enchantmentExists(enchantmentDefinitionId)) {
            revert CityErrors.InvalidValue();
        }

        if (!cityEnchantments.isEnchantmentUsable(enchantmentDefinitionId, level)) {
            revert CityErrors.InvalidValue();
        }

        enchantmentItemDefinitionOf[itemId] = EnchantmentItemDefinition({
            id: itemId,
            enchantmentDefinitionId: enchantmentDefinitionId,
            level: level,
            rarityTier: rarityTier,
            burnOnUse: burnOnUse,
            enabled: enabled
        });

        emit EnchantmentItemDefinitionSet(
            itemId,
            enchantmentDefinitionId,
            level,
            rarityTier,
            burnOnUse,
            enabled
        );
    }

    function mintEnchantmentItem(
        address to,
        uint256 itemId,
        uint256 amount
    ) external onlyAuthorizedMinter {
        if (to == address(0)) revert CityErrors.ZeroAddress();
        if (amount == 0) revert CityErrors.InvalidValue();

        EnchantmentItemDefinition memory def = enchantmentItemDefinitionOf[itemId];
        if (def.id == 0 || !def.enabled) revert CityErrors.InvalidValue();

        _mint(to, itemId, amount, "");
        emit EnchantmentItemMinted(to, itemId, amount);
    }

    function burnEnchantmentItem(
        address from,
        uint256 itemId,
        uint256 amount
    ) external onlyAuthorizedConsumer {
        if (from == address(0)) revert CityErrors.ZeroAddress();
        if (amount == 0) revert CityErrors.InvalidValue();

        EnchantmentItemDefinition memory def = enchantmentItemDefinitionOf[itemId];
        if (def.id == 0 || !def.enabled) revert CityErrors.InvalidValue();

        _burn(from, itemId, amount);
        emit EnchantmentItemBurned(from, itemId, amount);
    }

    function getEnchantmentItemMeta(
        uint256 itemId
    )
        external
        view
        returns (
            uint256 enchantmentDefinitionId,
            uint256 level,
            uint256 rarityTier,
            bool burnOnUse,
            bool enabled
        )
    {
        EnchantmentItemDefinition memory def = enchantmentItemDefinitionOf[itemId];
        return (
            def.enchantmentDefinitionId,
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