# WEAPON SYSTEM SPEC

## Ziel

Das Waffensystem von Inpinity City soll ein vollständiges MORPG/RPG-System bilden, bei dem Waffen als **einzigartige ERC721-Items** existieren.

Die Waffe ist nicht nur ein Bild oder ein Sammlerstück, sondern ein spielrelevantes On-Chain-Objekt mit:
- deterministischem Craft-Seed
- nachvollziehbarer Provenance
- klaren Kampfwerten
- Herkunft aus Plot / District / Faction
- späteren Erweiterungen für Enchanting, Materia, Resonance, PvE und PvP

---

## Grundsatzentscheidung

### ERC721
Waffen werden als **ERC721** modelliert.

Jede Waffe ist einzigartig und besitzt:
- eigene `tokenId`
- eigene Instanzdaten
- eigene Herkunft
- eigene Rarity / Frame / Resonance / Visual Variant
- eigene spätere Upgrade- und Modifikationshistorie

### ERC1155
Nicht-Waffen-Items werden separat betrachtet:
- Komponenten
- Materia
- Crafting-Materialien
- Verzauberungssteine
- Verbrauchsgüter
- City-Craft-Items

Diese sollen überwiegend als **ERC1155** modelliert werden.

---

## Drei Ebenen des Systems

### 1. Weapon Definition
Die Definition beschreibt einen Grundtyp der Waffe.

Beispiele:
- Iron Sword
- Crystal Bow
- Plasma Rifle
- Railgun
- Laser Blade

Die Definition enthält:
- Klasse
- Basiswerte
- Tech Tier
- Basisslots
- Standard-Kampfparameter
- Standard-Progression

### 2. Weapon Instance
Die Weapon Instance ist das einzelne ERC721-Objekt.

Sie enthält:
- `tokenId`
- `weaponDefinitionId`
- `rarityTier`
- `frameTier`
- `craftSeed`
- `provenanceHash`
- `resonanceType`
- `visualVariant`
- `originPlotId`
- `originFaction`
- `originDistrictKind`
- `upgradeLevel`
- weitere Instanzdaten

### 3. Metadata JSON
Die JSON-Datei dient der Darstellung im Frontend, Wallets und Marktplätzen.

Sie enthält:
- Name
- Bild
- Beschreibung
- Attribute
- ggf. Animation / UE5-Preview / Render-Link

Die JSON-Datei ist **nicht** die Quelle der Wahrheit für spielrelevante Werte.
Die Quelle der Wahrheit für Kampfwerte bleibt **onchain**.

---

## Trennung von On-Chain und Off-Chain

### On-Chain
Onchain gespeichert werden ausschließlich stabile und spielrelevante Daten:
- weaponDefinitionId
- rarityTier
- frameTier
- techTier
- minDamage
- maxDamage
- attackSpeed
- critChanceBps
- critMultiplierBps
- accuracyBps
- range
- durability
- maxDurability
- armorPenBps
- lifeStealBps
- energyCost
- heatGeneration
- stability
- cooldownMs
- projectileSpeed
- aoeRadius
- enchantmentSlots
- materiaSlots
- visualVariant
- upgradeLevel
- maxUpgradeLevel
- resonanceType
- familySetId
- originPlotId
- originFaction
- originDistrictKind
- craftedAt
- craftSeed
- provenanceHash
- metadataRevision
- genesisEra
- usedAether

### Off-Chain
Offchain gespeichert werden Darstellungs- und UI-Daten:
- Name
- Beschreibung
- Bild
- Alternativbilder
- Frame-Grafik
- Flavour Text
- Lore
- Animation-Links
- 3D-/UE5-Render-Links
- optische Effektbeschreibungen

---

## Verbindliche Waffendaten für v1

Folgende Felder gelten als offizieller v1-Umfang:

- `weaponDefinitionId`
- `name`
- `class`
- `damageType`
- `rarityTier`
- `frameTier`
- `techTier`
- `minDamage`
- `maxDamage`
- `attackSpeed`
- `baseDps`
- `critChanceBps`
- `critMultiplierBps`
- `accuracyBps`
- `range`
- `durability`
- `maxDurability`
- `armorPenBps`
- `lifeStealBps`
- `energyCost`
- `heatGeneration`
- `stability`
- `cooldownMs`
- `projectileSpeed`
- `aoeRadius`
- `enchantmentSlots`
- `materiaSlots`
- `visualVariant`
- `upgradeLevel`
- `maxUpgradeLevel`
- `resonanceType`
- `familySetId`
- `originPlotId`
- `originFaction`
- `originDistrictKind`
- `craftedAt`
- `craftSeed`
- `provenanceHash`
- `metadataRevision`
- `genesisEra`
- `usedAether`

---

## Kampfwerte

### Pflichtwerte
Diese Werte sind Kernbestandteil jeder Waffe:
- `minDamage`
- `maxDamage`
- `attackSpeed`
- `critChanceBps`
- `critMultiplierBps`
- `accuracyBps`
- `range`
- `durability`
- `maxDurability`

### Erweiterte Werte
Diese Werte sind ebenfalls für das System vorbereitet:
- `armorPenBps`
- `blockChanceBps`
- `lifeStealBps`
- `energyCost`
- `heatGeneration`
- `stability`
- `cooldownMs`
- `projectileSpeed`
- `aoeRadius`

---

## Berechnete Werte

### Regel
Berechnete Werte sollen **nicht unnötig doppelt gespeichert** werden.

### Basisformeln

#### Durchschnittsschaden
`avgDamage = (minDamage + maxDamage) / 2`

#### Base DPS
`baseDps = avgDamage * attackSpeed`

#### Kritisch angepasster DPS
`critAdjustedDps ≈ baseDps * (1 + critChance * (critMultiplier - 1))`

### Konsequenz
- `baseDps` kann gespeichert oder als View-Funktion berechnet werden
- `effectiveDps` soll später aus Instanz + Upgrades + Enchants + Materia + Resonance berechnet werden

---

## Definition vs. Instanz

### Weapon Definition enthält
- Basiswerte
- Waffentyp
- Tech Tier
- Standardslots
- Standard-VisualVariant
- Standard-MaxUpgradeLevel

### Weapon Instance enthält
- konkrete Rarity
- konkreten Frame
- Craft Seed
- Provenance Hash
- Herkunft
- Instanzspezifische Abweichungen
- Upgrade-Zustand
- spätere Modifikationen

---

## Klassen

Das System soll sowohl klassische als auch futuristische Waffen unterstützen.

Beispiele:
- Sword
- Axe
- Spear
- Bow
- Pistol
- Rifle
- LaserPistol
- LaserRifle
- PlasmaRifle
- LaserBlade
- Railgun
- EnergyStaff
- CrystalBow
- Relic

---

## Damage Types

Vorbereitete Schadensarten:
- Physical
- Fire
- Water
- Ice
- Lightning
- Earth
- Crystal
- Shadow
- Light
- Aether
- Plasma
- Energy

---

## Resonance System

### Grundidee
Der Craft-Ort und die Fraktions-/District-Herkunft beeinflussen die Waffe dauerhaft.

### Resonance Types
- Pi Resonance
- Phi Resonance
- Borderline Resonance
- Neutral / None

### Verwendung
Die Resonanz beeinflusst später:
- Schadensprofile
- Präzision
- Krit-Werte
- Energieeffizienz
- Instabilität
- Materia-Synergien

### Onchain
Gespeichert wird zunächst nur `resonanceType`.
Die konkrete Berechnung soll später in einer eigenen Logik / Library erfolgen.

---

## Provenance und Memory Weapons

Waffen sollen später eine Herkunftsgeschichte besitzen.

Dafür relevant:
- Ursprung aus einem bestimmten Plot
- Genesis-/Early-City-Herkunft
- Aether-Beteiligung
- Borderline-Coop-Herkunft
- bestimmte Districts
- Resonance

Diese Daten erhöhen später die Sammler- und Handelsrelevanz.

---

## Seed-System

### Craft Seed
Der Craft Seed muss deterministisch und nachvollziehbar erzeugt werden.

Mögliche Inputs:
- crafter address
- blueprintId
- coreId
- frameId
- gripId
- barrelOrBladeId
- plotId
- faction
- district
- nonce
- block timestamp

Beispiel logisch:
`keccak256(crafter, blueprintId, coreId, frameId, gripId, barrelId, plotId, faction, district, nonce)`

### Ziel
- eindeutige Waffeninstanz
- deterministische Ableitung
- spätere Visual-/Metadata-Konsistenz

---

## Provenance Hash

### Zweck
Der Provenance Hash beschreibt die endgültige onchain Identität der Waffeninstanz.

### Inputs
Mindestens:
- definitionId
- rarityTier
- frameTier
- resonanceType
- visualVariant
- craftSeed
- originPlotId
- upgradeLevel

### Ziel
- Nachweis, dass JSON/Bild zur Waffe passt
- Manipulationsschutz
- Grundlage für Provenance / History

---

## Upgrade-System

### v1
Es wird nur vorbereitet:
- `upgradeLevel`
- `maxUpgradeLevel`

### spätere Erweiterung
Mögliche Modelle:
- linearer Schadensbonus
- prozentuale Skalierung
- unterschiedliche Upgrade-Pfade
- Freischaltung zusätzlicher Materia-/Enchant-Slots

Für v1 soll das Contract-System so entworfen werden, dass Upgrades später ohne komplette Neustrukturierung ergänzt werden können.

---

## Enchanting und Materia

### v1
Es werden zunächst nur Slots vorbereitet:
- `enchantmentSlots`
- `materiaSlots`

### später
Daraus entstehen:
- Verzauberungssystem
- Materia-System
- Slot-Belegung
- Synergien
- Spezialeffekte

---

## Set-Boni und Komponentenfamilien

### familySetId
Das Feld `familySetId` soll später ermöglichen:
- Komponentenfamilien zu verknüpfen
- Set-Boni abzuleiten
- besondere Craft-Synergien sichtbar zu machen

### Ziel
Belohnung vollständiger und thematisch passender Build-Kombinationen.

---

## Instabile High-Tech-Waffen

Futuristische Waffen sollen nicht automatisch immer besser sein.

Dafür relevante Werte:
- `heatGeneration`
- `energyCost`
- `stability`
- `cooldownMs`

Diese Werte schaffen Tradeoffs:
- hoher Schaden
- aber mehr Überhitzung
- mehr Wartungsbedarf
- höhere Instabilität

---

## Fraktions- und District-Requirements

Waffen und Blueprints sollen später Anforderungen besitzen:
- nur Inpinity
- nur Inphinity
- nur Borderline-Coop
- nur bestimmte Districts
- nur Research-Freischaltung

Diese Logik wird teilweise in Blueprints / Crafting vorbereitet, soll aber auf Waffenebene mitgedacht werden.

---

## ERC721-Verhalten

### Wichtige Funktionen
- `mintWeapon`
- `tokenURI`
- `setBaseURI`
- `computeCraftSeed`
- `computeProvenanceHash`
- `getWeaponStats`
- `getCombatProfile`

### Zugriff
Mints und spätere sensible Änderungen sollen nur über autorisierte Contracts erfolgen:
- CityCrafting
- spätere Enchanting-/Materia-/Upgrade-Contracts

---

## Metadata Revision

### Zweck
Mit `metadataRevision` kann später unterschieden werden:
- unrevealed
- revealed
- neue Bildfassung
- neue UI-Fassung
- spezielle Event-Metadaten

So kann die Darstellung verbessert werden, ohne die Kernwerte zu verfälschen.

---

## Visual Variant und Frame

### visualVariant
Steuert Darstellung, Material-Look und Variante.

### frameTier
Steuert Seltenheitsrahmen.

Beispiele:
- Common = Weiß
- Rare = Blau
- Epic = Lila
- Legendary = Gold
- Mythic = Rot

---

## Verbindung zu City und Pyramid

Waffen dürfen nicht losgelöst vom restlichen System entstehen.

Sie sollen später aus einer Kombination stammen von:
- Pyramid-Ressourcen
- City-Ressourcen
- City-Crafts
- City-Komponenten
- Blueprints
- District-/Faction-Boni

Das Waffensystem ist also Teil des gesamten Inpinity-Ökosystems.

---

## Reihenfolge für die Umsetzung

### Zuerst
1. `WEAPON_SYSTEM_SPEC.md`
2. `METADATA_WEAPONS.md`
3. `CityWeapons.sol` als ERC721

### Danach
4. Metadata- und Assets-Struktur im separaten Repo `inpinity-weapons`
5. Anpassung von `CityCrafting.sol`
6. Anpassung weiterer Mint-/Blueprint-Verknüpfungen
7. Deploy-Skripte

---

## Fazit

Waffen in Inpinity City sind:
- einzigartige ERC721-Assets
- spielrelevante On-Chain-Objekte
- mit sauberem Seed- und Provenance-System
- mit vollständiger MORPG/RPG-Stat-Basis
- vorbereitet für spätere Erweiterungen wie:
  - Enchanting
  - Materia
  - Upgrades
  - PvE
  - PvP
  - Resonance
  - Provenance
  - Borderline-/Faction-Specials