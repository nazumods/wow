---@type Warbandeer_Characters
local ns = select(2, ...)
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
    midVariantID = 2906,
    spellID = 423321,
  },
  sl164 = {
    name = "Blacksmithing",
    skillLineID = 164,
    skillLineVariantID = 2872,
    midVariantID = 2907,
    spellID = 423332,
  },
  sl333 = {
    name = "Enchanting",
    skillLineID = 333,
    skillLineVariantID = 2874,
    midVariantID = 2909,
    spellID = 423334,
  },
  sl202 = {
    name = "Engineering",
    skillLineID = 202,
    skillLineVariantID = 2875,
    midVariantID = 2910,
    spellID = 423335,
  },
  sl182 = {
    name = "Herbalism",
    skillLineID = 182,
    skillLineVariantID = 2877,
    midVariantID = 2912,
    spellID = 441327,
  },
  sl773 = {
    name = "Inscription",
    skillLineID = 773,
    skillLineVariantID = 2878,
    midVariantID = 2913,
    spellID = 423338,
  },
  sl755 = {
    name = "Jewelcrafting",
    skillLineID = 755,
    skillLineVariantID = 2879,
    midVariantID = 2914,
    spellID = 423339,
  },
  sl165 = {
    name = "Leatherworking",
    skillLineID = 165,
    skillLineVariantID = 2880,
    midVariantID = 2915,
    spellID = 423340,
  },
  sl186 = {
    name = "Mining",
    skillLineID = 186,
    skillLineVariantID = 2881,
    midVariantID = 2916,
    spellID = 423341,
  },
  sl393 = {
    name = "Skinning",
    skillLineID = 393,
    skillLineVariantID = 2882,
    midVariantID = 2917,
    spellID = 423342,
  },
  sl197 = {
    name = "Tailoring",
    skillLineID = 197,
    skillLineVariantID = 2883,
    midVariantID = 2918,
    spellID = 423343,
  },
}

-- Expansion display name -> short bucket key for per-expansion recipe capture.
-- Only expansions listed here are captured; add more keys to track DF, etc.
local RECIPE_EXP_KEYS = {
  ["Midnight"]     = "midnight",
  ["Khaz Algar"]   = "tww",
  ["Dragon Isles"] = "df",
}

-- Profession display name of the current expansion.  A character that has trained
-- this expansion's skill line is expected to have recipe data captured; missing.lua
-- uses this to tell "never scanned / capture gap" apart from "just hasn't trained it".
ns.CURRENT_RECIPE_EXP = "Midnight"

---@class ProfRecipeBucket
---@field learned {id:integer, name:string}[]
---@field total integer

---@class ProfDetail
---@field expansions {name:string, skillLevel:integer, maxSkillLevel:integer}[]?
---@field specPoints integer?
---@field recipes table<string, ProfRecipeBucket>? -- keyed by expansion (midnight/tww/df)

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

ns.Professions = ns:RegisterBroker("professions")
ns.Professions.fields = {
  details = {
    -- On login/refresh, preserve whatever was cached from prior TRADE_SKILL_SHOW scans.
    get = function(self, toon, currentValue)
      return currentValue or {}
    end,

    -- Fired when the player opens a profession window.  Scans the active profession
    -- and merges its expansion skill levels and spec points into the stored table,
    -- keyed by skillLineID so each profession's data is updated independently.
    event = "TRADE_SKILL_SHOW",
    eventHandler = function(self, currentValue)
      -- Capture which profession was opened NOW, before any timer delay.
      -- Reading GetBaseProfessionInfo() inside the timer is unreliable: if the
      -- player switches professions before the timer fires, the wrong profession
      -- gets updated.
      if not C_TradeSkillUI or not C_TradeSkillUI.GetBaseProfessionInfo then return end
      local baseInfo = C_TradeSkillUI.GetBaseProfessionInfo()
      if not baseInfo or not baseInfo.professionID then return end
      local skillLineID = baseInfo.professionID

      -- Small delay ensures child profession info is fully populated before querying.
      C_Timer.After(0.5, function()
        local profData = {}

        -- Per-expansion skill levels.  Primary professions return one child per
        -- expansion; secondary professions (Fishing, Cooking) return no children.
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

        -- Total spec points spent across all spec trees for this profession.
        -- Returns nil for secondary professions that have no spec tree.
        if C_ProfSpecs and C_ProfSpecs.GetConfigIDForSkillLine then
          local configID = C_ProfSpecs.GetConfigIDForSkillLine(skillLineID)
          if configID and C_Traits and C_Traits.GetConfigInfo then
            local configInfo = C_Traits.GetConfigInfo(configID)
            if configInfo and configInfo.treeIDs then
              local points = 0
              for _, treeID in ipairs(configInfo.treeIDs) do
                if C_Traits.GetTreeInfo then
                  local treeInfo = C_Traits.GetTreeInfo(configID, treeID)
                  if treeInfo and treeInfo.pointsSpent then
                    points = points + treeInfo.pointsSpent
                  end
                end
              end
              profData.specPoints = points
            end
          end
        end

        -- Per-expansion learned recipes (ids + names).  Recipes are only queryable
        -- while the trade-skill window is open.  Every profession (including Fishing
        -- and Cooking) exposes per-expansion child skill lines; we bucket each recipe
        -- by the child it belongs to so future expansions can be added without reshape.
        if C_TradeSkillUI.GetChildProfessionInfos and C_TradeSkillUI.GetAllRecipeIDs then
          local children  = C_TradeSkillUI.GetChildProfessionInfos()
          local recipeIDs = C_TradeSkillUI.GetAllRecipeIDs()
          if children and recipeIDs and #recipeIDs > 0 then
            local recipes
            for _, child in ipairs(children) do
              local key = RECIPE_EXP_KEYS[child.expansionName]
              if key and child.professionID then
                local learned, total = {}, 0
                for _, id in ipairs(recipeIDs) do
                  if C_TradeSkillUI.IsRecipeInSkillLine(id, child.professionID) then
                    total = total + 1
                    local info = C_TradeSkillUI.GetRecipeInfo(id)
                    if info and info.learned then
                      insert(learned, { id = id, name = info.name })
                    end
                  end
                end
                recipes = recipes or {}
                recipes[key] = { learned = learned, total = total }
              end
            end
            profData.recipes = recipes
          end
        end

        -- Read the live value at timer-fire time rather than the value captured at
        -- event time; prevents a stale merge if another profession was opened and
        -- saved while this timer was pending.
        local data = {}
        local live = self.get_live and self.get_live() or currentValue
        if live then
          for k, v in pairs(live) do data[k] = v end
        end
        -- Per-field nil-guard: the trade-skill API often returns empty before its
        -- data finishes loading (e.g. GetChildProfessionInfos()/GetAllRecipeIDs()
        -- empty at login).  Since this overwrites the whole detail, any field the
        -- scan didn't populate this pass falls back to the previously-stored value
        -- rather than wiping good cached data.
        local prev = data[skillLineID]
        if prev then
          if not profData.expansions then profData.expansions = prev.expansions end
          if profData.specPoints == nil then profData.specPoints = prev.specPoints end
          if not profData.recipes then profData.recipes = prev.recipes end
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
    end,
  },
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
