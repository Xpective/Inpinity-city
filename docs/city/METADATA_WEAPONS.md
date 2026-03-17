# METADATA WEAPONS

## Ziel

Dieses Dokument definiert die Offchain-Metadatenstruktur für Waffen aus Inpinity City.

Die Waffen selbst sind als **ERC721** auf der Chain modelliert.  
Die JSON-Dateien dienen der Darstellung in:
- Wallets
- Frontends
- NFT-Marktplätzen
- Explorer-Ansichten
- Inpinity City UI
- spätere UE5-/3D-/Render-Ansichten

Die JSON-Dateien sind **nicht** die Quelle der Wahrheit für spielrelevante Werte.  
Die Quelle der Wahrheit für Kampf- und Identitätswerte bleibt **onchain**.

---

## Grundsatz

### Onchain
Onchain liegen:
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

### Offchain
Offchain liegen:
- Name
- Beschreibung
- Bild
- optionale Animation
- externe Links
- optische Attribute
- Lore
- UI-Attribute
- Frame-Darstellung
- Darstellungsvarianten

---

## Prinzipien für Weapon Metadata

1. **Die Onchain-Daten sind die Wahrheit.**
2. **Die JSON-Datei darf Darstellung verbessern, aber keine echten Werte verfälschen.**
3. **Die JSON-Datei soll mit dem Onchain-Status konsistent bleiben.**
4. **Revisions / Reveal / Bildupdates sollen möglich sein.**
5. **Das Schema muss skalieren für hunderte oder tausende Waffen.**

---

## Token URI Konzept

Der Weapon Contract soll `tokenURI(tokenId)` bereitstellen.

Diese URI zeigt auf eine JSON-Datei.

Beispiel:

```text
https://cdn.inpinity.online/weapons/metadata/123.json