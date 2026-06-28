---@type Warbandeer_Characters
local ns = select(2, ...)
local insert = table.insert
local DoesItemExist     = C_Item.DoesItemExist
local RequestLoadItemData = C_Item.RequestLoadItemData
local GetItemID         = C_Item.GetItemID
local GetItemLink       = C_Item.GetItemLink
local GetItemInfo       = C_Item.GetItemInfo
local GetCurrentItemLevel = C_Item.GetCurrentItemLevel
local GetItemQuality    = C_Item.GetItemQuality

-- Profession-equipment field of the professions broker (defined in data/professions.lua,
-- loaded first). Split out so each file stays within the size convention.

-- A just-equipped profession tool/accessory's data isn't necessarily cached when
-- PLAYER_EQUIPMENT_CHANGED fires, so we RequestLoadItemData and re-Update once
-- ITEM_DATA_LOAD_RESULT drains the pending set.  But that event does NOT fire for
-- an item whose data is already cached (the common case: equipping straight from
-- your bags), which strands the pending set and leaves the gear cache showing the
-- pre-swap tool until the next /reload or refresh.  So we also schedule a bounded
-- fallback re-scan; whichever lands first refreshes the cache and a second Update is
-- idempotent.  The generation guard lets a newer equip event supersede an in-flight
-- fallback.  (Mirrors data/equipment.lua.)
local FALLBACK_DELAY = 800 -- ms; outlasts a typical item-data load
local MAX_FALLBACKS = 5
local fallbackGen = 0

-- True while any profession slot still holds an item whose data hasn't loaded (so a
-- fresh scan would preserve the stale value rather than read the real one).
local function anyUnloaded()
  if not C_TradeSkillUI or not C_TradeSkillUI.GetProfessionSlots then return false end
  for _, profEnum in pairs(Enum.Profession or {}) do
    local skillID = C_TradeSkillUI.GetProfessionSkillLineID
      and C_TradeSkillUI.GetProfessionSkillLineID(profEnum)
    if skillID and skillID > 0 then
      for _, invSlot in ipairs(C_TradeSkillUI.GetProfessionSlots(profEnum) or {}) do
        local loc = {equipmentSlotIndex = invSlot}
        if DoesItemExist(loc) then
          local link = GetItemLink and GetItemLink(loc)
          local id = GetItemID(loc)
          if not GetItemInfo(link or id) then return true end
        end
      end
    end
  end
  return false
end

local function scheduleFallback()
  fallbackGen = fallbackGen + 1
  local gen, attempt = fallbackGen, 0
  local function tick()
    if gen ~= fallbackGen then return end -- a newer equip event took over
    attempt = attempt + 1
    ns.Professions:Update(ns.currentData)
    if attempt < MAX_FALLBACKS and anyUnloaded() then
      ns:after(FALLBACK_DELAY, tick)
    end
  end
  ns:after(FALLBACK_DELAY, tick)
end

-- Profession equipment: 3 inventory slots per profession (tool + 2 accessories).
-- Keyed by parent skillLineID so it survives the per-expansion variant churn.
ns.Professions.fields.gear = {
  get = function(self, toon, currentValue)
    if not C_TradeSkillUI or not C_TradeSkillUI.GetProfessionSlots then
      return currentValue or {}
    end
    -- Start from the cached data and only overwrite fields that the API
    -- actually returns this pass.  The WoW item APIs frequently return nil
    -- for not-yet-loaded items, so blindly rebuilding would clobber good
    -- cached values with nil.
    local gear = currentValue or {}
    for _, profEnum in pairs(Enum.Profession or {}) do
      local skillID = C_TradeSkillUI.GetProfessionSkillLineID
        and C_TradeSkillUI.GetProfessionSkillLineID(profEnum)
      if skillID and skillID > 0 then
        local slots = C_TradeSkillUI.GetProfessionSlots(profEnum)
        if slots and #slots > 0 then
          local existingSlots = gear[skillID] and gear[skillID].slots or {}
          local slotData = {}
          for _, invSlot in ipairs(slots) do
            local loc = {equipmentSlotIndex = invSlot}
            if DoesItemExist(loc) then
              local id = GetItemID(loc)
              if id then
                local prev = existingSlots[invSlot] or {}
                -- Use the equipment-location link, not GetItemInfo(id) — the
                -- latter returns the base item link without bonus IDs, and
                -- crafted tier lives in those bonus IDs.
                local link = GetItemLink and GetItemLink(loc)
                local name, _l, _q, _ilvl, _r, _c, _sc, _stk, _eq, _tex,
                  _sell, _cid, _scid, _bind, expacID = GetItemInfo(link or id)
                local ilvl = GetCurrentItemLevel(loc)
                local tier = link and C_TradeSkillUI.GetItemCraftedQualityByItemInfo
                  and C_TradeSkillUI.GetItemCraftedQualityByItemInfo(link)
                local rarity = GetItemQuality and GetItemQuality(loc)
                -- Keep the previously-cached value whenever the API hands us nil.
                slotData[invSlot] = {
                  name    = name    ~= nil and name    or prev.name,
                  link    = link    ~= nil and link    or prev.link,
                  ilvl    = ilvl    ~= nil and ilvl    or prev.ilvl,
                  rarity  = rarity  ~= nil and rarity  or prev.rarity,
                  tier    = tier    ~= nil and tier    or prev.tier,
                  expacID = expacID ~= nil and expacID or prev.expacID,
                }
              else
                -- Item exists but its id isn't available yet; don't drop the slot.
                if existingSlots[invSlot] then
                  slotData[invSlot] = existingSlots[invSlot]
                end
              end
            end
          end
          gear[skillID] = { slots = slotData }
        end
      end
    end
    return gear
  end,

  event = "PLAYER_EQUIPMENT_CHANGED",
  eventDelay = 500,
  eventHandler = function(field, currentValue)
    -- Pre-load item info for all profession slots so the subsequent
    -- get() call sees populated names/links.  Mirrors equipment.lua's
    -- ITEM_DATA_LOAD_RESULT-driven refresh.
    if not C_TradeSkillUI or not C_TradeSkillUI.GetProfessionSlots then return end
    local toLoad = {}
    for _, profEnum in pairs(Enum.Profession or {}) do
      local skillID = C_TradeSkillUI.GetProfessionSkillLineID
        and C_TradeSkillUI.GetProfessionSkillLineID(profEnum)
      if skillID and skillID > 0 then
        local slots = C_TradeSkillUI.GetProfessionSlots(profEnum)
        for _, invSlot in ipairs(slots or {}) do
          if DoesItemExist({equipmentSlotIndex = invSlot}) then
            insert(toLoad, invSlot)
          end
        end
      end
    end
    if #toLoad == 0 then
      field:set(field:get(ns.currentData, currentValue))
      return
    end
    local pending = {}
    for _, invSlot in ipairs(toLoad) do
      local id = GetItemID({equipmentSlotIndex = invSlot})
      if id then pending[id] = (pending[id] or 0) + 1 end
      RequestLoadItemData({equipmentSlotIndex = invSlot})
    end
    ns.profGearPending = pending
    -- ITEM_DATA_LOAD_RESULT may never fire for already-cached items, which would
    -- strand `pending`; schedule a bounded fallback so the scan lands regardless.
    scheduleFallback()
  end,
}

-- Refresh gear once all profession-slot item data has loaded.
ns:registerEvent("ITEM_DATA_LOAD_RESULT", function(self, itemID)
  if not self.profGearPending then return end
  local n = self.profGearPending[itemID]
  if not n then return end
  if n > 1 then
    self.profGearPending[itemID] = n - 1
  else
    self.profGearPending[itemID] = nil
    if not next(self.profGearPending) then
      self.profGearPending = nil
      self.Professions:Update(self.currentData)
    end
  end
end)
