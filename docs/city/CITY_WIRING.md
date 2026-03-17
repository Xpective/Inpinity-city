# CITY WIRING

Dieses Dokument beschreibt die aktuelle Live-Verdrahtung zwischen den City-Contracts.

## Core Wiring

### CityRegistry
- `cityHistory` gesetzt auf `CityHistory`

### CityHistory
- `authorizedCallers[CityRegistry] = true`

### CityStatus
- `authorizedCallers[CityLand] = true`

### CityDistricts
- `authorizedCallers[CityRegistry] = true`

### CityLand
- `cityStatus` gesetzt
- `cityHistory` gesetzt

---

## Crafting Wiring

### CityWeapons
- `cityWeaponSockets` gesetzt auf `CityWeaponSockets`
- `baseTokenURI` gesetzt auf:
  - `https://assets.inpinity.online/city/metadata/weapons/`
- `authorizedMinters[CityCrafting] = true`

### CityComponents
- `authorizedMinters[CityCrafting] = true`
- `baseMetadataURI` gesetzt auf:
  - `https://assets.inpinity.online/city/metadata/components/`

### CityBlueprints
- `authorizedMinters[CityCrafting] = true`
- `baseMetadataURI` gesetzt auf:
  - `https://assets.inpinity.online/city/metadata/blueprints/`

### CityCrafting
- `cityWeapons` gesetzt
- `cityComponents` gesetzt
- `cityBlueprints` gesetzt

### CityWeaponSockets
- `authorizedCallers[CityEnchanting] = true`
- `authorizedCallers[CityMateriaSystem] = true`

### CityEnchantmentItems
- `baseMetadataURI` gesetzt auf:
  - `https://assets.inpinity.online/city/metadata/enchantment-items/`
- `authorizedConsumers[CityEnchanting] = true`

### CityMateriaItems
- `baseMetadataURI` gesetzt auf:
  - `https://assets.inpinity.online/city/metadata/materia-items/`
- `authorizedConsumers[CityMateriaSystem] = true`

---

## Pause Status
Aktuell:
- `CityWeapons.weaponsPaused = false`
- `CityCrafting.craftingPaused = false`

---

## Design Intention
Das System ist so verdrahtet, dass:

- `CityCrafting` Waffen, Komponenten und Blueprints minten darf
- `CityEnchanting` Enchantment-Items verbrennen und Sockel belegen darf
- `CityMateriaSystem` Materia-Items verbrennen und Sockel belegen darf
- `CityWeaponSockets` die aggregierten Bonuswerte für `CityWeapons` bereitstellt

---

## Upgrade Path
Diese Verdrahtung ist bewusst modular aufgebaut. Spätere Erweiterungen sollen möglichst ohne Komplett-Neudeploy des gesamten Systems möglich sein.

Beispiele:
- neue Definitions-Sets
- neue Rezepte
- neue Materia- und Enchantment-Items
- neue Frontend-/Metadata-Layer