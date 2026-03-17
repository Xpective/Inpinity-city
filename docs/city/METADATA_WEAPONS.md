# METADATA WEAPONS

## Base URI
Aktuell ist für `CityWeapons` gesetzt:

`https://assets.inpinity.online/city/metadata/weapons/`

Die finale Token-URI ergibt sich aus:

`baseTokenURI + tokenId + ".json"`

Beispiel:
`https://assets.inpinity.online/city/metadata/weapons/1.json`

---

## Rolle der Offchain-Metadata
Onchain bleibt die Quelle für:
- Besitz
- Definition
- Combat-Werte
- Seed
- Provenance Hash
- Upgrade Level
- Herkunft

Offchain dient für:
- Name / Beschreibung
- Bild
- UI-Attribute
- Visual Variant Darstellung
- zusätzliche Explorer-/Frontend-Infos

---

## Spätere Struktur
Empfohlen ist eine Trennung von:
- Weapon Definitions
- Weapon Instances
- Component Metadata
- Blueprint Metadata
- Enchantment Item Metadata
- Materia Item Metadata

---

## Änderbarkeit
Die URI ist owner-änderbar.

Das ist bewusst so gewählt, damit:
- CDN-Wechsel möglich ist
- Asset-Repo später ergänzt werden kann
- Metadaten-Struktur verbessert werden kann
- kein kompletter Redeploy nötig wird

---

## Nächster Asset-Schritt
Nach Stabilisierung der Contracts:
- Metadata-Repo / Asset-Repo pflegen
- JSON-Schema definieren
- erste Weapon JSONs anlegen
- erste Bilder / Platzhalter vorbereiten