local _, ns = ...
local API = ns.api
local insert = table.insert
-- luacheck: globals C_TradeSkillUI C_ProfSpecs C_Traits C_Timer C_Item Enum
local DoesItemExist     = C_Item.DoesItemExist
local RequestLoadItemData = C_Item.RequestLoadItemData
local GetItemID         = C_Item.GetItemID
local GetItemLink       = C_Item.GetItemLink
local GetItemInfo       = C_Item.GetItemInfo
local GetCurrentItemLevel = C_Item.GetCurrentItemLevel
local GetItemQuality    = C_Item.GetItemQuality

API.professionInfo = {
  sl171 = {
    name = "Alchemy",
    skillLineID = 171,
    skillLineVariantID = 2871,
    spellID = 423321,
  },
  sl164 = {
    name = "Blacksmithing",
    skillLineID = 164,
    skillLineVariantID = 2872,
    spellID = 423332,
  },
  sl333 = {
    name = "Enchanting",
    skillLineID = 333,
    skillLineVariantID = 2874,
    spellID = 423334,
  },
  sl202 = {
    name = "Engineering",
    skillLineID = 202,
    skillLineVariantID = 2875,
    spellID = 423335,
  },
  sl182 = {
    name = "Herbalism",
    skillLineID = 182,
    skillLineVariantID = 2877,
    spellID = 441327,
  },
  sl773 = {
    name = "Inscription",
    skillLineID = 773,
    skillLineVariantID = 2878,
    spellID = 423338,
  },
  sl755 = {
    name = "Jewelcrafting",
    skillLineID = 755,
    skillLineVariantID = 2879,
    spellID = 423339,
  },
  sl165 = {
    name = "Leatherworking",
    skillLineID = 165,
    skillLineVariantID = 2880,
    spellID = 423340,
  },
  sl186 = {
    name = "Mining",
    skillLineID = 186,
    skillLineVariantID = 2881,
    spellID = 423341,
  },
  sl393 = {
    name = "Skinning",
    skillLineID = 393,
    skillLineVariantID = 2882,
    spellID = 423342,
  },
  sl197 = {
    name = "Tailoring",
    skillLineID = 197,
    skillLineVariantID = 2883,
    spellID = 423343,
  },
}

---@class ProfDetail
---@field expansions {name:string, skillLevel:integer, maxSkillLevel:integer}[]?
---@field specPoints integer?
---@field knowledgeUnspent integer?

---@class ProfGearSlot
---@field name string?
---@field link string?
---@field ilvl integer?
---@field rarity integer? -- Enum.ItemQuality: 2=green, 3=blue, 4=purple
---@field tier integer? -- 1-5 crafted-tier stars (nil if item has no crafted tier)
---@field expacID integer? -- LE_EXPANSION_* of the item

---@class ProfGear
---@field slots table<integer, ProfGearSlot> keyed by inventory slot index

---@class Character
---@field professions ProfessionsBroker

---@class ProfessionsBroker: Broker
---@field details table<integer, ProfDetail>?
---@field gear table<integer, ProfGear>? keyed by parent skillLineID

-- Scans profession knowledge (spec points, knowledge level/max, unspent) for
-- skillLineID using C_ProfSpecs + C_Traits.  Works without the profession window
-- open.  Returns nil when the profession has no spec tree (Fishing, Cooking).
local function scanKnowledge(skillLineID)
  if not C_ProfSpecs or not C_ProfSpecs.GetConfigIDForSkillLine then return end
  local configID = C_ProfSpecs.GetConfigIDForSkillLine(skillLineID)
  if not configID or not C_Traits or not C_Traits.GetConfigInfo then return end
  local configInfo = C_Traits.GetConfigInfo(configID)
  if not configInfo or not configInfo.treeIDs then return end

  local points = 0
  for _, treeID in ipairs(configInfo.treeIDs) do
    if C_Traits.GetTreeInfo then
      local treeInfo = C_Traits.GetTreeInfo(configID, treeID)
      if treeInfo and treeInfo.pointsSpent then points = points + treeInfo.pointsSpent end
    end
  end

  local kc = C_ProfSpecs.GetCurrencyInfoForSkillLine and C_ProfSpecs.GetCurrencyInfoForSkillLine(skillLineID)
  return {
    specPoints       = points,
    knowledgeUnspent = kc and kc.numAvailable or 0,
  }
end

ns.Professions = ns:RegisterBroker("professions")
ns.Professions.fields = {
  details = {
    -- On login/refresh, scan knowledge for all of this character's professions.
    -- Preserves expansions/concentration from prior TRADE_SKILL_SHOW scans.
    get = function(self, toon, currentValue)
      local data = {}
      if currentValue then
        for k, v in pairs(currentValue) do data[k] = v end
      end

      local profs = toon and toon.basic and toon.basic.professions
      if not profs then return data end

      for _, slot in ipairs({ "primary", "secondary", "fishing", "cooking" }) do
        local prof = profs[slot]
        if prof and prof.skillID then
          local skillLineID = prof.skillID
          local entry = {}
          if data[skillLineID] then
            for k, v in pairs(data[skillLineID]) do entry[k] = v end
          end
          local know = scanKnowledge(skillLineID)
          if know then
            entry.specPoints       = know.specPoints
            entry.knowledgeUnspent = know.knowledgeUnspent
          end
          data[skillLineID] = entry
        end
      end

      return data
    end,

    -- Fired when the player opens a profession window.  Adds expansion skill levels
    -- and concentration (window-only APIs) and refreshes knowledge for that profession.
    event = "TRADE_SKILL_SHOW",
    eventHandler = function(self, currentValue)
      -- Capture which profession was opened NOW, before any timer delay.
      if not C_TradeSkillUI or not C_TradeSkillUI.GetBaseProfessionInfo then return end
      local baseInfo = C_TradeSkillUI.GetBaseProfessionInfo()
      if not baseInfo or not baseInfo.professionID then return end
      local skillLineID = baseInfo.professionID

      -- Small delay ensures child profession info is fully populated before querying.
      C_Timer.After(0.5, function()
        local profData = {}

        -- Per-expansion skill levels (requires profession window).
        if C_TradeSkillUI.GetChildProfessionInfos then
          local children = C_TradeSkillUI.GetChildProfessionInfos()
          if children and #children > 0 then
            local expansions = {}
            for _, child in ipairs(children) do
              insert(expansions, {
                name          = child.expansionName or child.professionName or "?",
                skillLevel    = child.skillLevel    or 0,
                maxSkillLevel = child.maxSkillLevel or 0,
              })
            end
            profData.expansions = expansions
          end
        end

        -- Knowledge (works offline; re-scanned here for freshness).
        local know = scanKnowledge(skillLineID)
        if know then
          profData.specPoints       = know.specPoints
          profData.knowledgeUnspent = know.knowledgeUnspent
        end

        -- Read the live value at timer-fire time to avoid stale merges.
        local data = {}
        local live = self.get_live and self.get_live() or currentValue
        if live then
          for k, v in pairs(live) do data[k] = v end
        end
        data[skillLineID] = profData
        self:set(data)
      end)
    end,
  },

  -- Profession equipment: 3 inventory slots per profession (tool + 2 accessories).
  -- Keyed by parent skillLineID so it survives the per-expansion variant churn.
  gear = {
    get = function(self, toon, currentValue)
      if not C_TradeSkillUI or not C_TradeSkillUI.GetProfessionSlots then
        return currentValue or {}
      end
      local gear = {}
      for _, profEnum in pairs(Enum.Profession or {}) do
        local skillID = C_TradeSkillUI.GetProfessionSkillLineID
          and C_TradeSkillUI.GetProfessionSkillLineID(profEnum)
        if skillID and skillID > 0 then
          local slots = C_TradeSkillUI.GetProfessionSlots(profEnum)
          if slots and #slots > 0 then
            local slotData = {}
            for _, invSlot in ipairs(slots) do
              local loc = {equipmentSlotIndex = invSlot}
              if DoesItemExist(loc) then
                local id = GetItemID(loc)
                if id then
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
                  slotData[invSlot] = {
                    name    = name,
                    link    = link,
                    ilvl    = ilvl,
                    rarity  = rarity,
                    tier    = tier,
                    expacID = expacID,
                  }
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
      ns.profGearRequests = #toLoad
      for _, invSlot in ipairs(toLoad) do
        RequestLoadItemData({equipmentSlotIndex = invSlot})
      end
    end,
  },
}

-- Refresh gear once all profession-slot item data has loaded.
ns:registerEvent("ITEM_DATA_LOAD_RESULT", function(self)
  if not self.profGearRequests then return end
  self.profGearRequests = self.profGearRequests - 1
  if self.profGearRequests == 0 then
    self.profGearRequests = nil
    self.Professions:Update(self.currentData)
  end
end)
