// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "../libraries/CityErrors.sol";
import "../interfaces/IResourceToken.sol";
import "../core/CityConfig.sol";

contract CityCrafting is Ownable, ERC1155Holder {
    uint256 public constant RESOURCE_COUNT = 10;

    enum RecipeOutputKind {
        None,
        Resource,
        Component,
        Blueprint,
        WeaponPrototype,
        Enchantment
    }

    struct Recipe {
        uint256 id;
        RecipeOutputKind outputKind;
        uint256 outputId;
        uint256 outputAmount;

        // Kosten für ResourceToken IDs 0..9
        uint256[RESOURCE_COUNT] resourceCosts;

        // spätere Erweiterungen
        uint256 requiredFaction;      // 0 = none, 1 = Inpinity, 2 = Inphinity, 3 = Neutral/Borderline
        uint256 requiredDistrictKind; // 0 = none
        uint256 requiredBuildingId;   // 0 = none
        uint256 requiredTechTier;     // 0 = none
        bool requiresDiscovery;
        bool enabled;
    }

    CityConfig public immutable cityConfig;

    mapping(uint256 => Recipe) public recipeOf;
    mapping(address => bool) public authorizedCallers;

    // user => recipeId => discovered
    mapping(address => mapping(uint256 => bool)) public recipeDiscoveredBy;

    event AuthorizedCallerSet(address indexed caller, bool allowed);

    event RecipeSet(
        uint256 indexed recipeId,
        RecipeOutputKind outputKind,
        uint256 outputId,
        uint256 outputAmount,
        bool enabled
    );

    event RecipeDiscovered(address indexed user, uint256 indexed recipeId);

    event Crafted(
        address indexed user,
        uint256 indexed recipeId,
        RecipeOutputKind outputKind,
        uint256 outputId,
        uint256 outputAmount
    );

    constructor(address initialOwner, address cityConfigAddress) Ownable(initialOwner) {
        if (initialOwner == address(0) || cityConfigAddress == address(0)) {
            revert CityErrors.ZeroAddress();
        }

        cityConfig = CityConfig(cityConfigAddress);
    }

    modifier onlyAuthorized() {
        if (!(msg.sender == owner() || authorizedCallers[msg.sender])) {
            revert CityErrors.NotAuthorized();
        }
        _;
    }

    function setAuthorizedCaller(address caller, bool allowed) external onlyOwner {
        if (caller == address(0)) revert CityErrors.ZeroAddress();
        authorizedCallers[caller] = allowed;
        emit AuthorizedCallerSet(caller, allowed);
    }

    function setRecipe(
        uint256 recipeId,
        RecipeOutputKind outputKind,
        uint256 outputId,
        uint256 outputAmount,
        uint256[RESOURCE_COUNT] calldata resourceCosts,
        uint256 requiredFaction,
        uint256 requiredDistrictKind,
        uint256 requiredBuildingId,
        uint256 requiredTechTier,
        bool requiresDiscovery,
        bool enabled
    ) external onlyOwner {
        if (recipeId == 0) revert CityErrors.InvalidValue();
        if (outputKind == RecipeOutputKind.None) revert CityErrors.InvalidValue();
        if (outputAmount == 0) revert CityErrors.InvalidValue();

        recipeOf[recipeId] = Recipe({
            id: recipeId,
            outputKind: outputKind,
            outputId: outputId,
            outputAmount: outputAmount,
            resourceCosts: resourceCosts,
            requiredFaction: requiredFaction,
            requiredDistrictKind: requiredDistrictKind,
            requiredBuildingId: requiredBuildingId,
            requiredTechTier: requiredTechTier,
            requiresDiscovery: requiresDiscovery,
            enabled: enabled
        });

        emit RecipeSet(recipeId, outputKind, outputId, outputAmount, enabled);
    }

    function discoverRecipe(address user, uint256 recipeId) external onlyAuthorized {
        if (user == address(0)) revert CityErrors.ZeroAddress();
        if (recipeOf[recipeId].id == 0) revert CityErrors.InvalidValue();

        recipeDiscoveredBy[user][recipeId] = true;
        emit RecipeDiscovered(user, recipeId);
    }

    function craft(uint256 recipeId) external {
        Recipe memory recipe = recipeOf[recipeId];
        if (!recipe.enabled) revert CityErrors.InvalidValue();

        if (recipe.requiresDiscovery && !recipeDiscoveredBy[msg.sender][recipeId]) {
            revert CityErrors.InvalidValue();
        }

        address resourceTokenAddr = cityConfig.getAddressConfig(cityConfig.KEY_RESOURCE_TOKEN());
        if (resourceTokenAddr == address(0)) revert CityErrors.InvalidConfig();

        IResourceToken resourceToken = IResourceToken(resourceTokenAddr);

        for (uint256 i = 0; i < RESOURCE_COUNT; i++) {
            uint256 cost = recipe.resourceCosts[i];
            if (cost > 0) {
                resourceToken.safeTransferFrom(msg.sender, address(this), i, cost, "");
            }
        }

        // v1:
        // Ausgabe wird noch nicht on-chain gemintet, sondern architektonisch vorbereitet
        emit Crafted(msg.sender, recipeId, recipe.outputKind, recipe.outputId, recipe.outputAmount);
    }

    function getRecipeCosts(uint256 recipeId) external view returns (uint256[RESOURCE_COUNT] memory) {
        return recipeOf[recipeId].resourceCosts;
    }
}