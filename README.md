# Simple Bag Sorter

**Simple Bag Sorter** ist ein leichtgewichtiges World of Warcraft Addon (optimiert für Classic / Wrath of the Lich King - Client 3.3.5a), das dein Inventar automatisch sortiert, Lücken schließt und Gegenstände logisch anordnet.

---

## Features

- **Mehrstufige Sortierung:** 
  Sortiert deine Gegenstände automatisch nach einer festen Priorität:
  1. **Qualität / Seltenheit:** Legendär $\rightarrow$ Episch $\rightarrow$ Selten $\rightarrow$ Ungewöhnlich $\rightarrow$ Gewöhnlich $\rightarrow$ Schlecht (Grau).
  2. **Kategorie:** Haupttyp (z. B. Rüstung, Verbrauchsgut, Handwerk).
  3. **Unterkategorie:** Subtyp (z. B. Tränke, Elixiere, Leder).
  4. **Alphabetisch:** Name von A bis Z für konsistente Ergebnisse.
- **Lückenschluss:** Schiebt alle Gegenstände nahtlos zusammen und entfernt leere Plätze zwischen deinen Items.
- **Client-Schonende Ausführung:** Verhindert Desync-Gefahren durch serverseitige Intervall-Tausche (`OnUpdate`-Queue mit Zeitverzögerung).
- **Integrierter UI-Button:** Fügt dem Standard-Taschenfenster (`ContainerFrame1`) oben rechts einen direkten **"Sort"**-Button hinzu.

---

## Installation

1. Lade den Quellcode oder das Release-ZIP herunter.
2. Navigiere in deinen World of Warcraft Ordner:
   `World of Warcraft\_retail_\Interface\AddOns\` *(bzw. `_classic_` oder WotLK-Clientpfad)*.
3. Erstelle einen Ordner namens `SimpleBagSorter`.
4. Kopiere die Dateien `SimpleBagSorter.toc` und `SimpleBagSorter.lua` in diesen Ordner.

Ordnerstruktur:
```text
World of Warcraft/
└── Interface/
    └── AddOns/
        └── SimpleBagSorter/
            ├── SimpleBagSorter.toc
            └── SimpleBagSorter.lua

```

---

## Benutzung

### 1. Über den UI-Button

Öffne deine Haupttasche (Standard-Taste `B`). Oben rechts am Fenster findest du einen kleinen Button mit der Aufschrift **"Sort"**. Ein Klick darauf startet den Sortiervorgang.

### 2. Über Slash-Befehle

| Befehl | Beschreibung |
| --- | --- |
| `/sortbags` | Startet den automatischen Sortiervorgang. |
| `/sortbags stop` | Bricht einen laufenden Sortiervorgang sofort ab. |

---

## Funktionsweise im Detail

Das Addon arbeitet nach einem deterministischen 2-Schritt-System:

1. **Planung (`PlanSort`):**
Das Inventar (Taschen 0 bis 4) wird gescannt, Lücken werden ignoriert und alle Vorhandenen Items in einem virtuellen Ziel-Layout neu geordnet.
2. **Ausführung (`OnUpdate`):**
Gegenstände werden schrittweise per `PickupContainerItem` getauscht. Zwischen den Tauschvorgängen wartet das Addon jeweils ca. `0.08` Sekunden, um das Server-Locking von Items sauber abzuwarten.

