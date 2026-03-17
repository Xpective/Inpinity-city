# CRAFTING VISION

## Ziel
Das City-Crafting-System soll nicht nur ein einfacher Item-Minter sein, sondern ein modularer Produktions- und Fortschrittslayer innerhalb von Inpinity City.

Es verbindet:
- Ressourcen aus dem bestehenden Ökosystem
- City-Komponenten
- Blueprints
- Waffen
- Enchantments
- Materia
- Fraktions- und Distriktlogik
- spätere PvE-/PvP-Kampfwerte

---

## Grundstruktur

### 1. Components (ERC1155)
Stapelbare Bauteile und Crafting-Elemente.

Beispiele:
- Iron Blade
- Reinforced Hilt
- Crystal Core
- Plasma Chamber
- Energy Coil
- Stabilizer
- Resonance Grip

### 2. Blueprints (ERC1155)
Baupläne / Herstellungswissen.

Beispiele:
- Iron Sword Blueprint
- Crystal Bow Blueprint
- Plasma Rifle Blueprint

### 3. Weapons (ERC721)
Einzigartige Waffen mit individueller Herkunft, Seed, Hash und Kampfdaten.

Jede Waffe trägt:
- Definition
- Rarity
- Frame
- Seed
- Provenance Hash
- Herkunft
- Upgrade Level
- Resonance Type
- Slots
- Combat Profile

### 4. Enchantments
Definitionsebene für Verzauberungen und ihre Boni.

### 5. Enchantment Items (ERC1155)
Verbrauchbare oder benutzbare Verzauberungsgegenstände, die auf Waffen angewendet werden.

### 6. Materia
Definitionsebene für Materia und ihre Boni.

### 7. Materia Items (ERC1155)
Sockelbare Materia-Items für Waffen.

---

## Designprinzipien

### Modularität
Jeder Bereich ist als eigenes Modul gebaut, damit spätere Erweiterungen keinen Komplett-Neustart erzwingen.

### Migrationsfähigkeit
Neue Inhalte sollen bevorzugt als:
- neue Definitionen
- neue Items
- neue Rezepte
- neue Metadaten
ergänzt werden, ohne alte Systeme unbrauchbar zu machen.

### Trennung Onchain / Offchain
Onchain:
- Kernwerte
- Besitz
- Regeln
- Seeds / Hashes / Herkunft
- autorisierte Interaktionen

Offchain:
- Bilder
- Texte
- Darstellungen
- UI-Metadaten
- Vorschau-Assets

### Zukunftssicherheit
Das System ist vorbereitet für:
- weitere Waffentypen
- neue Materia
- neue Enchantments
- Rezepte mit Distrikt-/Fraktionsbedingungen
- Upgrade-/Reparatur-Systeme
- spätere PvE-/PvP-Logik

---

## Aktuelle erste Content-Phase

### Erste Waffen
- Iron Sword
- Crystal Bow
- Plasma Rifle

### Erste Komponenten
- Iron Blade
- Reinforced Hilt
- Crystal Core
- Bow Limb
- Bow String
- Plasma Chamber
- Energy Coil
- Stabilizer
- Resonance Grip

### Erste Blueprints
- Iron Sword Blueprint
- Crystal Bow Blueprint
- Plasma Rifle Blueprint

### Erste Enchantments
- Fire Edge
- Precision Sight
- Durability Seal

### Erste Materia
- Fire Materia
- Resonance Materia
- Stability Materia

### Erste Rezepte
5–10 erste Rezepte als funktionierender Startsatz.

---

## Ziel der nächsten Phase
Nicht mehr nur Infrastruktur, sondern ein erster spielbarer, craftbarer Satz an Items und Waffen.