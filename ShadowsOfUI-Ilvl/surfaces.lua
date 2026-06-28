---@type ShadowsOfUI_Ilvl
local ns = select(2, ...)

local UpdateButton = ns.UpdateButton
local CleanButton  = ns.CleanButton
local AddRefresher = ns.AddRefresher

local function db(key) return ns.db and ns.db[key] end

-- Clean a button, then (when the surface is enabled and the slot holds an item)
-- overlay the ilvl/track on top of the icon.
local function tagOverlay(button, item, enabled)
    CleanButton(button)
    if enabled and item then UpdateButton(button, item, false) end
end

-- Resolve an Item from any unit's equipment slot: the player uses the live
-- equipment-slot location; other units fall back to the inventory link/itemID.
local function itemFromUnitSlot(unit, slotID)
    if unit == "player" then
        return Item:CreateFromEquipmentSlot(slotID)
    end
    local link = GetInventoryItemLink(unit, slotID)
    if link then return Item:CreateFromItemLink(link) end
    local id = GetInventoryItemID(unit, slotID)
    if id then return Item:CreateFromItemID(id) end
end

-- Character / Inspect paperdoll — inset (or overlay) labels per gear slot ------

local function updateSlot(button, unit, show, inset)
    CleanButton(button)
    if not (show and ns.InsetPositions[button:GetName()]) then return end -- gear slots only
    UpdateButton(button, itemFromUnitSlot(unit, button:GetID()), inset, true) -- paperdoll: larger font
end

local function refreshPaperdoll(prefix, frame, unit, showKey, insetKey)
    if not (frame and frame:IsShown()) then return end
    for name in pairs(ns.InsetPositions) do
        if name:sub(1, #prefix) == prefix then
            local button = _G[name]
            if button then updateSlot(button, unit, db(showKey), db(insetKey)) end
        end
    end
end

hooksecurefunc("PaperDollItemSlotButton_Update", function(button)
    updateSlot(button, "player", db("character"), db("characterInset"))
end)
AddRefresher(function()
    refreshPaperdoll("Character", _G.CharacterFrame, "player", "character", "characterInset")
end)

EventUtil.ContinueOnAddOnLoaded("Blizzard_InspectUI", function()
    local function unit() return _G.InspectFrame and _G.InspectFrame.unit or "target" end
    hooksecurefunc("InspectPaperDollItemSlotButton_Update", function(button)
        updateSlot(button, unit(), db("inspect"), db("inspectInset"))
    end)

    -- Average ilvl at the top centre of the inspect model.
    local function updateAvg()
        local u = unit()
        local ilvl = db("inspectAvg") and u and C_PaperDollInfo.GetInspectItemLevel(u)
        ns.SetAvgIlvl(_G.InspectModelFrame, ilvl or nil)
    end
    -- Inspect data streams in asynchronously; refresh once it has landed.
    EventRegistry:RegisterFrameEventAndCallback("INSPECT_READY", updateAvg)

    AddRefresher(function()
        refreshPaperdoll("Inspect", _G.InspectFrame, unit(), "inspect", "inspectInset")
        if _G.InspectFrame and _G.InspectFrame:IsShown() then updateAvg() end
    end)
end)

-- Bags -----------------------------------------------------------------------

local function updateBags(frame)
    local on = db("bags")
    for _, itemButton in frame:EnumerateValidItems() do
        tagOverlay(itemButton, Item:CreateFromBagAndSlot(itemButton:GetBagID(), itemButton:GetID()), on)
    end
end

local function eachContainerFrame(fn)
    local combined = _G.ContainerFrameCombinedBags
    if combined then fn(combined) end
    for _, frame in ipairs((_G.ContainerFrameContainer or UIParent).ContainerFrames or {}) do
        fn(frame)
    end
end

eachContainerFrame(function(frame) hooksecurefunc(frame, "UpdateItems", updateBags) end)
AddRefresher(function()
    eachContainerFrame(function(frame) if frame:IsShown() then updateBags(frame) end end)
end)

-- Bank (11.2.0+ BankPanel) ---------------------------------------------------

do
    local panel = _G.BankPanel
    if panel then
        local function updateBank(frame)
            local on = db("bank") and C_Bank.CanUseBank(frame:GetActiveBankType())
            for itemButton in frame:EnumerateValidItems() do
                local item = on and Item:CreateFromBagAndSlot(itemButton:GetBankTabID(), itemButton:GetContainerSlotID())
                tagOverlay(itemButton, item or nil, on)
            end
        end
        hooksecurefunc(panel, "GenerateItemSlotsForSelectedTab", updateBank)
        hooksecurefunc(panel, "RefreshAllItemsForSelectedTab", updateBank)
        AddRefresher(function() if panel:IsShown() then updateBank(panel) end end)
    end
end

-- Loot window ----------------------------------------------------------------

if _G.LootFrame and _G.LootFrame.ScrollBox then
    local function handleSlot(frame)
        if not frame.Item then return end
        local on, link = db("loot"), nil
        if on then
            local data = frame:GetElementData()
            link = data and data.slotIndex and GetLootSlotLink(data.slotIndex)
        end
        tagOverlay(frame.Item, link and Item:CreateFromItemLink(link) or nil, on)
    end
    local function refreshLoot() _G.LootFrame.ScrollBox:ForEachFrame(handleSlot) end
    _G.LootFrame.ScrollBox:RegisterCallback("OnUpdate", refreshLoot)
    AddRefresher(function() if _G.LootFrame:IsShown() then refreshLoot() end end)
end

-- Guild bank -----------------------------------------------------------------

EventUtil.ContinueOnAddOnLoaded("Blizzard_GuildBankUI", function()
    local function updateGuild(self)
        if self.mode ~= "bank" then return end
        local on = db("guildbank")
        local tab = GetCurrentGuildBankTab()
        for _, column in ipairs(self.Columns) do
            for _, button in ipairs(column.Buttons) do
                local link = on and GetGuildBankItemLink(tab, button:GetID())
                tagOverlay(button, link and Item:CreateFromItemLink(link) or nil, on)
            end
        end
    end
    hooksecurefunc(_G.GuildBankFrame, "Update", updateGuild)
    AddRefresher(function() if _G.GuildBankFrame:IsShown() then updateGuild(_G.GuildBankFrame) end end)
end)
