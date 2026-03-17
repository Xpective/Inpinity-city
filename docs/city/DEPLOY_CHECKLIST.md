# DEPLOY CHECKLIST

## Status
Diese Checkliste beschreibt den jetzt erreichten Stand nach erfolgreichem Live-Deploy.

---

## Phase 1 — Core Contracts
- [x] CityConfig deployed
- [x] CityRegistry deployed
- [x] CityLand deployed
- [x] CityDistricts deployed
- [x] CityStatus deployed
- [x] CityHistory deployed
- [x] CityValidation deployed

## Phase 2 — Core Wiring
- [x] CityRegistry -> CityHistory gesetzt
- [x] CityHistory authorizes CityRegistry
- [x] CityStatus authorizes CityLand
- [x] CityDistricts authorizes CityRegistry
- [x] CityLand hooks gesetzt

## Phase 3 — Crafting Stack
- [x] CityComponents deployed
- [x] CityBlueprints deployed
- [x] CityEnchantments deployed
- [x] CityEnchantmentItems deployed
- [x] CityMateria deployed
- [x] CityMateriaItems deployed
- [x] CityWeapons deployed
- [x] CityWeaponSockets deployed
- [x] CityCrafting deployed
- [x] CityEnchanting deployed
- [x] CityMateriaSystem deployed

## Phase 4 — Crafting Wiring
- [x] CityWeapons -> sockets gesetzt
- [x] CityWeapons base URI gesetzt
- [x] CityWeapons authorizes CityCrafting
- [x] CityComponents authorizes CityCrafting
- [x] CityBlueprints authorizes CityCrafting
- [x] CityCrafting kennt Weapons
- [x] CityCrafting kennt Components
- [x] CityCrafting kennt Blueprints
- [x] CityWeaponSockets authorizes CityEnchanting
- [x] CityWeaponSockets authorizes CityMateriaSystem
- [x] CityEnchantmentItems authorizes CityEnchanting as consumer
- [x] CityMateriaItems authorizes CityMateriaSystem as consumer

## Phase 5 — Verification
- [x] Verify script erfolgreich
- [x] Owner checks erfolgreich
- [x] URI checks erfolgreich
- [x] Authorization checks erfolgreich
- [x] Contract link checks erfolgreich
- [x] Pause flags geprüft

---

## Next Phase — Content
- [ ] erste Weapon Definitions
- [ ] erste Component Definitions
- [ ] erste Blueprint Definitions
- [ ] erste Enchantment Definitions
- [ ] erste Materia Definitions
- [ ] erste Enchantment Item Definitions
- [ ] erste Materia Item Definitions
- [ ] erste Crafting Recipes
- [ ] erster Test-Craft