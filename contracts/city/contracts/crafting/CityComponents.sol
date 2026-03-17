// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/CityErrors.sol";

contract CityComponents is ERC1155, Ownable {
    struct ComponentDefinition {
        uint256 id;
        string name;
        uint256 category;
        uint256 rarityTier;
        uint256 techTier;
        bool enabled;
    }

    string public baseMetadataURI;

    mapping(uint256 => ComponentDefinition) public componentDefinitionOf;
    mapping(address => bool) public authorizedMinters;
    mapping(address => bool) public authorizedConsumers;

    event AuthorizedMinterSet(address indexed minter, bool allowed);
    event AuthorizedConsumerSet(address indexed consumer, bool allowed);
    event BaseMetadataURISet(string newBaseMetadataURI);

    event ComponentDefinitionSet(
        uint256 indexed componentId,
        string name,
        uint256 category,
        uint256 rarityTier,
        uint256 techTier,
        bool enabled
    );

    event ComponentMinted(
        address indexed to,
        uint256 indexed componentId,
        uint256 amount
    );

    event ComponentBurned(
        address indexed from,
        uint256 indexed componentId,
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

    function uri(uint256 componentId) public view override returns (string memory) {
        return string(abi.encodePacked(baseMetadataURI, _toString(componentId), ".json"));
    }

    function setComponentDefinition(
        uint256 componentId,
        string calldata name,
        uint256 category,
        uint256 rarityTier,
        uint256 techTier,
        bool enabled
    ) external onlyOwner {
        if (componentId == 0) revert CityErrors.InvalidValue();
        if (bytes(name).length == 0) revert CityErrors.InvalidValue();

        componentDefinitionOf[componentId] = ComponentDefinition({
            id: componentId,
            name: name,
            category: category,
            rarityTier: rarityTier,
            techTier: techTier,
            enabled: enabled
        });

        emit ComponentDefinitionSet(
            componentId,
            name,
            category,
            rarityTier,
            techTier,
            enabled
        );
    }

    function mintComponent(
        address to,
        uint256 componentId,
        uint256 amount
    ) external onlyAuthorizedMinter {
        if (to == address(0)) revert CityErrors.ZeroAddress();
        if (amount == 0) revert CityErrors.InvalidValue();

        ComponentDefinition memory def = componentDefinitionOf[componentId];
        if (def.id == 0 || !def.enabled) revert CityErrors.InvalidValue();

        _mint(to, componentId, amount, "");
        emit ComponentMinted(to, componentId, amount);
    }

    function burnComponent(
        address from,
        uint256 componentId,
        uint256 amount
    ) external onlyAuthorizedConsumer {
        if (from == address(0)) revert CityErrors.ZeroAddress();
        if (amount == 0) revert CityErrors.InvalidValue();

        ComponentDefinition memory def = componentDefinitionOf[componentId];
        if (def.id == 0 || !def.enabled) revert CityErrors.InvalidValue();

        _burn(from, componentId, amount);
        emit ComponentBurned(from, componentId, amount);
    }

    function componentExists(uint256 componentId) external view returns (bool) {
        return componentDefinitionOf[componentId].id != 0;
    }

    function isComponentEnabled(uint256 componentId) external view returns (bool) {
        return componentDefinitionOf[componentId].enabled;
    }

    function getComponentMeta(
        uint256 componentId
    )
        external
        view
        returns (
            string memory name,
            uint256 category,
            uint256 rarityTier,
            uint256 techTier,
            bool enabled
        )
    {
        ComponentDefinition memory def = componentDefinitionOf[componentId];
        return (
            def.name,
            def.category,
            def.rarityTier,
            def.techTier,
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