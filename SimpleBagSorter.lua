local frame = CreateFrame("Frame")
local isSorting = false
local currentStep = 1
local targetLayout = {}
local activeBags = {0, 1, 2, 3, 4}
local isGuildBankMode = false

-- ============================================================================
-- TASCHEN- UND NORMAL-BANK-LOGIK
-- ============================================================================
local function GetBagSlots(bagList)
    local slots = {}
    for _, bag in ipairs(bagList) do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots and numSlots > 0 then
            for slot = 1, numSlots do
                table.insert(slots, { bag = bag, slot = slot })
            end
        end
    end
    return slots
end

local function PlanSortContainer()
    local allSlots = GetBagSlots(activeBags)
    local items = {}

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

    table.sort(items, function(a, b)
        if a.quality ~= b.quality then return a.quality > b.quality end
        if a.itemType ~= b.itemType then return a.itemType < b.itemType end
        if a.itemSubType ~= b.itemSubType then return a.itemSubType < b.itemSubType end
        return a.name < b.name
    end)

    targetLayout = {}
    for i, item in ipairs(items) do
        targetLayout[i] = {
            bag = allSlots[i].bag,
            slot = allSlots[i].slot,
            link = item.link
        }
    end
end

-- ============================================================================
-- GILDENBANK / PERSONAL BANK LOGIK (VERWENDET BLIZZARD GUILDBANK API)
-- ============================================================================
local function PlanSortGuildBank(currentTab)
    local items = {}
    local numSlots = 98 -- Max. Slots pro Gildenbank-Tab

    for slot = 1, numSlots do
        local link = GetGuildBankItemLink(currentTab, slot)
        if link then
            local itemName, _, itemQuality, _, _, itemType, itemSubType = GetItemInfo(link)
            table.insert(items, {
                slot = slot,
                link = link,
                quality = itemQuality or 0,
                itemType = itemType or "",
                itemSubType = itemSubType or "",
                name = itemName or ""
            })
        end
    end

    table.sort(items, function(a, b)
        if a.quality ~= b.quality then return a.quality > b.quality end
        if a.itemType ~= b.itemType then return a.itemType < b.itemType end
        if a.itemSubType ~= b.itemSubType then return a.itemSubType < b.itemSubType end
        return a.name < b.name
    end)

    targetLayout = {}
    for i, item in ipairs(items) do
        targetLayout[i] = {
            tab = currentTab,
            slot = i,
            link = item.link
        }
    end
end

-- ============================================================================
-- ABLAUF-STEUERUNG
-- ============================================================================
local function StartSorting(bagsToSort, isGuildBank)
    if isSorting then
        print("|cffff0000[BagSorter]|r Sortierung läuft bereits...")
        return
    end

    isGuildBankMode = isGuildBank or false

    if isGuildBankMode then
        local currentTab = GetCurrentGuildBankTab()
        if not currentTab or currentTab == 0 then
            print("|cffff0000[BagSorter]|r Bitte wähle zuerst einen Bank-Tab aus!")
            return
        end
        PlanSortGuildBank(currentTab)
    else
        activeBags = bagsToSort or {0, 1, 2, 3, 4}
        PlanSortContainer()
    end

    if #targetLayout == 0 then
        print("|cff00ff00[BagSorter]|r Keine Gegenstände zum Sortieren gefunden.")
        return
    end

    currentStep = 1
    isSorting = true
    print("|cff00ff00[BagSorter]|r Sortierung gestartet...")
end

-- Ticker-Schleife für Schritt-für-Schritt Verarbeitung
local timer = 0
frame:SetScript("OnUpdate", function(self, elapsed)
    if not isSorting then return end

    timer = timer + elapsed
    
    -- Gildenbank benötigt etwas mehr Zeit (0.2s) wegen Server-Sync
    local delay = isGuildBankMode and 0.20 or 0.05
    if timer < 0.05 then return end
    timer = 0

    if currentStep > #targetLayout then
        print("|cff00ff00[BagSorter]|r Sortierung erfolgreich abgeschlossen!")
        isSorting = false
        return
    end

    local target = targetLayout[currentStep]

    if isGuildBankMode then
        local _, _, lockedTarget = GetGuildBankItemInfo(target.tab, target.slot)
        local currentLink = GetGuildBankItemLink(target.tab, target.slot)

        if lockedTarget then return end

        if currentLink == target.link then
            currentStep = currentStep + 1
            return
        end

        -- Quell-Slot suchen
        local sourceSlot = nil
        for slot = currentStep + 1, 98 do
            local _, _, lockedSource = GetGuildBankItemInfo(target.tab, slot)
            local l = GetGuildBankItemLink(target.tab, slot)
            if l == target.link then
                if lockedSource then return end
                sourceSlot = slot
                break
            end
        end

        if sourceSlot then
            PickupGuildBankItem(target.tab, sourceSlot)
            PickupGuildBankItem(target.tab, target.slot)
        else
            currentStep = currentStep + 1
        end
    else
        -- Normale Taschen-Logik
        local _, _, lockedTarget, _, _, _, currentLink = GetContainerItemInfo(target.bag, target.slot)
        if lockedTarget then return end

        if currentLink == target.link then
            currentStep = currentStep + 1
            return
        end

        local sourceBag, sourceSlot = nil, nil
        local allSlots = GetBagSlots(activeBags)
        
        for i = currentStep + 1, #allSlots do
            local s = allSlots[i]
            local _, _, locked, _, _, _, l = GetContainerItemInfo(s.bag, s.slot)
            if l == target.link then
                if locked then return end
                sourceBag = s.bag
                sourceSlot = s.slot
                break
            end
        end

        if sourceBag and sourceSlot then
            PickupContainerItem(sourceBag, sourceSlot)
            PickupContainerItem(target.bag, target.slot)
        else
            currentStep = currentStep + 1
        end
    end
end)

-- ============================================================================
-- UI BUTTON ATTACHMENT
-- ============================================================================
local function AttachSortButton(name, parent, xOffset, yOffset, onClickFunc)
    if not parent or _G[name] then return end

    local btn = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    btn:SetSize(40, 18)
    btn:SetText("Sort")
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", xOffset, yOffset)
    btn:SetFrameStrata("HIGH")
    btn:SetFrameLevel(parent:GetFrameLevel() + 10)
    btn:SetScript("OnClick", onClickFunc)
    return btn
end

-- Taschen
AttachSortButton("SimpleBagSorterBtn_Bags", ContainerFrame1, -10, -28, function()
    StartSorting({0, 1, 2, 3, 4}, false)
end)

-- Standard Bank
AttachSortButton("SimpleBagSorterBtn_Bank", BankFrame, -40, -30, function()
    StartSorting({-1, 5, 6, 7, 8, 9, 10, 11, 12}, false)
end)

-- Gildenbank / Personal Bank / Realm Bank Frame
local function InitGuildBankButton()
    if GuildBankFrame then
        AttachSortButton("SimpleBagSorterBtn_Guild", GuildBankFrame, -35, -36, function()
            StartSorting(nil, true)
        end)
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("GUILDBANKFRAME_OPENED")
eventFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "Blizzard_GuildBankUI" then
        InitGuildBankButton()
    elseif event == "GUILDBANKFRAME_OPENED" then
        InitGuildBankButton()
    end
end)
