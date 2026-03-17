// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../libraries/CityErrors.sol";
import "../interfaces/IResourceToken.sol";
import "../interfaces/ICityWeapons.sol";
import "../interfaces/ICityComponents.sol";
import "../interfaces/ICityBlueprints.sol";
import "../core/CityConfig.sol";

contract CityCrafting is Ownable, ERC1155Holder, ReentrancyGuard {
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

        // spätere Erweiterungen / Zugangsvoraussetzungen
        uint256 requiredFaction;      // 0 = none, 1 = Inpinity, 2 = Inphinity, 3 = Neutral/Borderline
        uint256 requiredDistrictKind; // 0 = none
        uint256 requiredBuildingId;   // 0 = none
        uint256 requiredTechTier;     // 0 = none

        // für Weapon-Rezepte
        uint256 rarityTier;
        uint256 frameTier;

        bool requiresDiscovery;
        bool enabled;
    }

    CityConfig public immutable cityConfig;

    ICityWeapons public cityWeapons;
    ICityComponents public cityComponents;
    ICityBlueprints public cityBlueprints;

    uint256 public craftNonce;

    mapping(uint256 => Recipe) public recipeOf;
    mapping(address => bool) public authorizedCallers;

    // user => recipeId => discovered
    mapping(address => mapping(uint256 => bool)) public recipeDiscoveredBy;

    event AuthorizedCallerSet(address indexed caller, bool allowed);

    event CityWeaponsSet(address indexed weapons);
    event CityComponentsSet(address indexed components);
    event CityBlueprintsSet(address indexed blueprints);

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

    event WeaponCrafted(
        address indexed user,
        uint256 indexed recipeId,
        uint256 indexed tokenId,
        uint256 weaponDefinitionId,
        uint256 craftNonce
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

    function setCityWeapons(address cityWeaponsAddress) external onlyOwner {
        if (cityWeaponsAddress == address(0)) revert CityErrors.ZeroAddress();
        cityWeapons = ICityWeapons(cityWeaponsAddress);
        emit CityWeaponsSet(cityWeaponsAddress);
    }

    function setCityComponents(address cityComponentsAddress) external onlyOwner {
        if (cityComponentsAddress == address(0)) revert CityErrors.ZeroAddress();
        cityComponents = ICityComponents(cityComponentsAddress);
        emit CityComponentsSet(cityComponentsAddress);
    }

    function setCityBlueprints(address cityBlueprintsAddress) external onlyOwner {
        if (cityBlueprintsAddress == address(0)) revert CityErrors.ZeroAddress();
        cityBlueprints = ICityBlueprints(cityBlueprintsAddress);
        emit CityBlueprintsSet(cityBlueprintsAddress);
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
        uint256 rarityTier,
        uint256 frameTier,
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
            rarityTier: rarityTier,
            frameTier: frameTier,
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

    function craft(uint256 recipeId) external nonReentrant {
        Recipe memory recipe = recipeOf[recipeId];
        _validateRecipe(recipe, msg.sender);

        if (recipe.outputKind == RecipeOutputKind.WeaponPrototype) {
            revert CityErrors.InvalidValue();
        }

        _consumeResources(msg.sender, recipe.resourceCosts);
        _mintNonWeaponOutput(msg.sender, recipe);

        emit Crafted(msg.sender, recipeId, recipe.outputKind, recipe.outputId, recipe.outputAmount);
    }

    function craftWeapon(
        uint256 recipeId,
        uint256 originPlotId,
        uint256 originFaction,
        uint256 originDistrictKind,
        uint8 resonanceType,
        uint256 visualVariant,
        bool genesisEra,
        bool usedAether
    ) external nonReentrant returns (uint256 tokenId) {
        Recipe memory recipe = recipeOf[recipeId];
        _validateRecipe(recipe, msg.sender);

        if (recipe.outputKind != RecipeOutputKind.WeaponPrototype) {
            revert CityErrors.InvalidValue();
        }

        if (address(cityWeapons) == address(0)) revert CityErrors.InvalidConfig();

        _consumeResources(msg.sender, recipe.resourceCosts);

        unchecked {
            craftNonce += 1;
        }

        tokenId = cityWeapons.mintWeapon(
            msg.sender,
            recipe.outputId,
            recipe.rarityTier,
            recipe.frameTier,
            originPlotId,
            originFaction,
            originDistrictKind,
            resonanceType,
            visualVariant,
            genesisEra,
            usedAether,
            craftNonce
        );

        emit Crafted(msg.sender, recipeId, recipe.outputKind, recipe.outputId, 1);
        emit WeaponCrafted(msg.sender, recipeId, tokenId, recipe.outputId, craftNonce);
    }

    function getRecipeCosts(uint256 recipeId) external view returns (uint256[RESOURCE_COUNT] memory) {
        return recipeOf[recipeId].resourceCosts;
    }

    function _validateRecipe(Recipe memory recipe, address user) internal view {
        if (!recipe.enabled) revert CityErrors.InvalidValue();
        if (recipe.id == 0) revert CityErrors.InvalidValue();

        if (recipe.requiresDiscovery && !recipeDiscoveredBy[user][recipe.id]) {
            revert CityErrors.InvalidValue();
        }

        // Platzhalter für spätere Validierungen:
        // - requiredFaction
        // - requiredDistrictKind
        // - requiredBuildingId
        // - requiredTechTier
        //
        // Diese sollen später über injizierte Contracts geprüft werden:
        // - CityRegistry
        // - CityDistricts
        // - CityBuildings / PersonalBuildings / CommunityBuildings
        //
        // Für v1 bleiben sie bewusst vorbereitet, aber noch nicht aktiv ausgewertet.
    }

    function _consumeResources(address from, uint256[RESOURCE_COUNT] memory resourceCosts) internal {
        address resourceTokenAddr = cityConfig.getAddressConfig(cityConfig.KEY_RESOURCE_TOKEN());
        if (resourceTokenAddr == address(0)) revert CityErrors.InvalidConfig();

        address treasury = cityConfig.getAddressConfig(cityConfig.KEY_TREASURY());
        if (treasury == address(0)) revert CityErrors.InvalidConfig();

        IResourceToken resourceToken = IResourceToken(resourceTokenAddr);

        // Preflight checks zuerst, damit keine Teiltransfers passieren
        for (uint256 i = 0; i < RESOURCE_COUNT; i++) {
            uint256 cost = resourceCosts[i];
            if (cost > 0) {
                if (resourceToken.balanceOf(from, i) < cost) {
                    revert CityErrors.InvalidValue();
                }
            }
        }

        // Danach Transfers direkt an Treasury
        for (uint256 i = 0; i < RESOURCE_COUNT; i++) {
            uint256 cost = resourceCosts[i];
            if (cost > 0) {
                resourceToken.safeTransferFrom(from, treasury, i, cost, "");
            }
        }
    }

    function _mintNonWeaponOutput(address to, Recipe memory recipe) internal {
        if (recipe.outputKind == RecipeOutputKind.Component) {
            if (address(cityComponents) == address(0)) revert CityErrors.InvalidConfig();
            cityComponents.mintComponent(to, recipe.outputId, recipe.outputAmount);
            return;
        }

        if (recipe.outputKind == RecipeOutputKind.Blueprint) {
            if (address(cityBlueprints) == address(0)) revert CityErrors.InvalidConfig();
            cityBlueprints.mintBlueprint(to, recipe.outputId, recipe.outputAmount);
            return;
        }

        if (recipe.outputKind == RecipeOutputKind.Resource) {
            revert CityErrors.InvalidValue();
        }

        if (recipe.outputKind == RecipeOutputKind.Enchantment) {
            revert CityErrors.InvalidValue();
        }

        revert CityErrors.InvalidValue();
    }
}