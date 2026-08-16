local frame = CreateFrame("Frame")
local isSorting = false
local currentStep = 1
local targetLayout = {}

-- Hilfsfunktion: Alle verfügbaren Taschen-Slots in einer linearen Liste erfassen
local function GetBagSlots()
    local slots = {}
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            table.insert(slots, { bag = bag, slot = slot })
        end
    end
    return slots
end

-- STRATEGIE-SCHRITT 1: Inventar einlesen, Lücken filtern & Sortier-Ziel planen
local function PlanSort()
    local allSlots = GetBagSlots()
    local items = {}

    -- 1. Nur besetzte Slots erfassen (Lücken ignorieren)
    for _, s in ipairs(allSlots) do
        local texture, count, locked, quality, _, _, link = GetContainerItemInfo(s.bag, s.slot)
        if link then
            local itemName, _, itemQuality, _, _, itemType, itemSubType = GetItemInfo(link)
            table.insert(items, {
                link = link,
                quality = itemQuality or quality or 0,
                itemType = itemType or "",
                itemSubType = itemSubType or "",
                name = itemName or ""
            })
        end
    end

    -- 2. Mehrstufige Sortierung (Qualität -> Typ -> Subtyp -> Name)
    table.sort(items, function(a, b)
        -- 1. Priorität: Qualität (Lila -> Blau -> Grün -> Weiß -> Grau)
        if a.quality ~= b.quality then
            return a.quality > b.quality
        end

        -- 2. Priorität: Haupt-Kategorie (z.B. Rüstung, Verbrauchsgut)
        if a.itemType ~= b.itemType then
            return a.itemType < b.itemType
        end

        -- 3. Priorität: Unter-Kategorie (z.B. Tränke, Elixiere)
        if a.itemSubType ~= b.itemSubType then
            return a.itemSubType < b.itemSubType
        end

        -- 4. Priorität: Name (A-Z) für deterministisches Verhalten
        return a.name < b.name
    end)

    -- 3. Soll-Layout erstellen: Jedes sortierte Item bekommt exakt einen Slot zugewiesen
    targetLayout = {}
    for i, item in ipairs(items) do
        targetLayout[i] = {
            bag = allSlots[i].bag,
            slot = allSlots[i].slot,
            link = item.link
        }
    end
end

-- Prüft, ob das aktuelle Inventar bereits exakt dem Ziel-Layout entspricht
local function IsAlreadySorted()
    for i, target in ipairs(targetLayout) do
        local _, _, _, _, _, _, currentLink = GetContainerItemInfo(target.bag, target.slot)
        if currentLink ~= target.link then
            return false
        end
    end
    return true
end

-- STRATEGIE-SCHRITT 2: Schrittweise Ausführung im Spiel
local timer = 0
frame:SetScript("OnUpdate", function(self, elapsed)
    if not isSorting then return end

    timer = timer + elapsed
    if timer < 0.08 then return end -- Kurze Pause für Sync mit dem Server
    timer = 0

    -- Prüfen, ob alle sortierten Plätze verarbeitet wurden
    if currentStep > #targetLayout then
        print("|cff00ff00[BagSorter]|r Taschen erfolgreich sortiert und Lücken geschlossen!")
        isSorting = false
        return
    end

    local target = targetLayout[currentStep]
    local _, _, lockedTarget, _, _, _, currentLink = GetContainerItemInfo(target.bag, target.slot)

    -- Warten, falls der Ziel-Slot aktuell gesperrt ist
    if lockedTarget then return end

    -- Liegt auf dem Zielslot bereits das richtige Item? -> Weiter zum nächsten Slot
    if currentLink == target.link then
        currentStep = currentStep + 1
        return
    end

    -- Suche das gesuchte Item irgendwo im restlichen Inventar
    local sourceBag, sourceSlot = nil, nil
    local allSlots = GetBagSlots()
    
    for i = currentStep + 1, #allSlots do
        local s = allSlots[i]
        local _, _, locked, _, _, _, l = GetContainerItemInfo(s.bag, s.slot)
        if l == target.link then
            if locked then return end -- Warten, falls die Quelle noch gesperrt ist
            sourceBag = s.bag
            sourceSlot = s.slot
            break
        end
    end

    -- Tausch ausführen, sobald Quelle und Ziel frei sind
    if sourceBag and sourceSlot then
        PickupContainerItem(sourceBag, sourceSlot)
        PickupContainerItem(target.bag, target.slot)
    else
        -- Falls das Item nicht gefunden wurde (z.B. gelöscht/bewegt), Schritt überspringen
        currentStep = currentStep + 1
    end
end)

-- Erweiterter Slash-Befehl (/sortbags & /sortbags stop)
SLASH_SORTBAGS1 = "/sortbags"
SlashCmdList["SORTBAGS"] = function(msg)
    msg = string.lower(string.match(msg or "", "^%s*(.-)%s*$") or "")
    
    -- Abbruchfunktion
    if msg == "stop" then
        if isSorting then
            isSorting = false
            print("|cffff0000[BagSorter]|r Sortierung wurde abgebrochen.")
        else
            print("|cffff0000[BagSorter]|r Es läuft derzeit keine Sortierung.")
        end
        return
    end

    -- Hauptfunktion: Sortierung starten
    if isSorting then
        print("|cffff0000[BagSorter]|r Sortierung läuft bereits... (Zum Abbrechen: /sortbags stop)")
        return
    end
    
    PlanSort()
    if #targetLayout == 0 then
        print("|cff00ff00[BagSorter]|r Keine Gegenstände zum Sortieren gefunden.")
        return
    end
    
    -- Prüfen, ob bereits perfekt sortiert ist
    if IsAlreadySorted() then
        print("|cff00ff00[BagSorter]|r Die Taschen sind bereits perfekt sortiert! Keine Aktion nötig.")
        return
    end
    
    currentStep = 1
    isSorting = true
    print("|cff00ff00[BagSorter]|r Sortierung gestartet...")
end
