---@type ShadowsOfUI_HousingVendor
local ns = select(2, ...)

local CleanOverlay = ns.CleanOverlay
local ApplyOverlay = ns.ApplyOverlay
local AddRefresher = ns.AddRefresher

local function db(key) return ns.db and ns.db[key] end

local GetContainerItemLink = C_Container.GetContainerItemLink

-- Clean a button, then (when the surface is enabled and the slot holds decor)
-- paint the count/star overlay. The decor lookup is fully synchronous — the
-- container link, the class gate, and the catalog query all resolve at once — so
-- unlike ShadowsOfUI-Ilvl there's no ContinueOnItemLoad / stale-callback token.
local function tag(button, link, enabled)
  CleanOverlay(button)
  if enabled and link then
    local d = ns.DecorEntryFor(link)
    if d then ApplyOverlay(button, d) end
  end
end

-- Bags (Blizzard ContainerFrame) --------------------------------------------

local function updateBags(frame)
  local on = db("bags")
  for _, itemButton in frame:EnumerateValidItems() do
    tag(itemButton, GetContainerItemLink(itemButton:GetBagID(), itemButton:GetID()), on)
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
        tag(itemButton, GetContainerItemLink(itemButton:GetBankTabID(), itemButton:GetContainerSlotID()), on)
      end
    end
    hooksecurefunc(panel, "GenerateItemSlotsForSelectedTab", updateBank)
    hooksecurefunc(panel, "RefreshAllItemsForSelectedTab", updateBank)
    AddRefresher(function() if panel:IsShown() then updateBank(panel) end end)
  end
end
