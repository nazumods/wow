local _, ns = ...
local insert = table.insert
local ui = ns.ui
local Left = ui.justify.Left
local Colors, Icons = ns.Colors, ns.icons
local Class = ns.lua.Class
local GetServerTime = GetServerTime -- luacheck: globals GetServerTime

---@class Warbandeer
---@field SummaryColumn fun():SummaryColumn

---@class SummaryColumn
ns.SummaryColumn = Class(nil, function(self)
  local path, coords
  if self.currencyID then
    local info = C_CurrencyInfo.GetCurrencyInfo(self.currencyID)
    path = info.iconFileID
    coords = {0.1, 0.9, 0.1, 0.9}
  end
  local atlas = not path and self.icon or nil
  self.colInfo = {
    name = self.name,
    width = self.width,
    justifyH = self.justifyH,
    backdrop = {color = Colors.TransparentBlack},
    padLeft = self.padLeft,
    atlas = atlas,
    -- `X and false or nil` always evaluates to nil — assign explicitly so
    -- TableCol's "centered square" branch fires for atlas icons.
    path = path,
    coords = coords,
    tooltip = self.tooltip,
  }
  if atlas then self.colInfo.atlasSize = false end
end, {
  -- default options
  name = nil,
  width = 20,
  justifyH = Left,
  padLeft = nil,
  icon = nil,
  currencyID = nil,
  tooltip = nil,
  getData = function() return "" end, -- function to get data for this column
})
local SummaryColumn = ns.SummaryColumn

local GreenCheck = {
  atlas = ns.icons.CheckGreen,
  atlasSize = false,
  position = {
    Center = {},
    Size = {16, 16},
  },
}

---@class Warbandeer
---@field SummaryColumns SummaryColumn[]
ns.SummaryColumns = {}

-- faction
insert(
  ns.SummaryColumns,
  SummaryColumn:new{
    getData = function(toon) return toon.isAlliance and Icons.AllianceLight or Icons.HordeLight end,
  }
)

-- role
insert(
  ns.SummaryColumns,
  SummaryColumn:new{
    padLeft = 2,
    getData = function(toon) return toon.basic.specialization and Icons[toon.basic.specialization.role] or "" end,
  }
)

local function getNameString(toon)
  local current = ns.api.GetCurrentCharacter()
  local s = toon.name
  if s == current then
    s = s.." |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:14:14|t"
  end
  return {
    text = s,
    color = ns.Colors[toon.classKey or toon.className],
    onEnter = function(self)
      ui.ShowCharacterTooltip(toon, self, {
        TopLeft = {self, ui.edge.Bottom, 20, -10},
      })
    end,
    onLeave = function(self) ui.HideCharacterTooltip() end,
  }
end
insert(
  ns.SummaryColumns,
  SummaryColumn:new{
    padLeft = 2,
    name = "Character",
    width = 105,
    getData = getNameString,
  }
)

insert(
  ns.SummaryColumns,
  SummaryColumn:new{
    name = "Lvl",
    width = 20,
    getData = function(t) return t.basic.level end,
  }
)

local getILvlString = function(toon)
  local lines = {}
  if toon.equipment then
    local orderedSlots = {"Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands", "Waist", "Legs", "Feet", "Finger1", "Finger2", "Trinket1", "Trinket2", "MainHand", "OffHand"}
    for _,value in ipairs(orderedSlots) do
      if toon.equipment.slots and toon.equipment.slots[value] then
        insert(lines, value.." "..ns.IlvlColor(toon.equipment.slots[value].ilvl))
      end
    end
  end
  return {
    text = toon.basic.level < ns.wow.maxLevel and ITEM_STANDARD_COLOR:WrapTextInColorCode(toon.equipment.ilvl) or ns.IlvlColor(toon.equipment.ilvl),
    justifyH = ui.justify.Right,
    onEnter = function(self)
      ui.tip:AnchorTo(self, "ANCHOR_BOTTOMRIGHT", -10, 10)
      ui.tip:ClearLines()
      for _,l in ipairs(lines) do ui.tip:AddLine(l) end
      ui.tip:Show()
    end,
    onLeave = function(self) ui.tip:Hide() end,
    onClick = function(self) self.parent:view("gear") end,
  }
end

insert(
  ns.SummaryColumns,
  SummaryColumn:new{
    name = "iLvl",
    width = 30,
    justifyH = ui.justify.Right,
    getData = getILvlString,
  }
)

-- Profession gear % (current expansion).  Per slot, score = rarity (1-5) +
-- crafted tier (1-3), max 8.  3 slots * 2 primaries = 48 points total.
-- Only items whose expacID matches the current expansion contribute; old
-- expac or empty slots score 0.
local MAX_RARITY = 5
local MAX_TIER   = 3
local PER_SLOT_MAX = MAX_RARITY + MAX_TIER

local profInfoBySkill = nil
local function profNameBySkillID(skillID)
  if not profInfoBySkill then
    profInfoBySkill = {}
    for _, info in pairs(ns.api.professionInfo or {}) do
      if info.skillLineID then profInfoBySkill[info.skillLineID] = info.name end
    end
  end
  return profInfoBySkill[skillID]
end

-- Item rarity tint for the rarity number in the tooltip.
local RarityColors = {
  [5] = "|cffff8000", -- legendary
  [4] = "|cffa335ee", -- epic
  [3] = "|cff0070dd", -- rare
  [2] = "|cff1eff00", -- uncommon
  [1] = "|cffffffff", -- common
}

local function clamp(v, lo, hi)
  if not v then return 0 end
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function getProfGearScore(toon)
  if not (toon.basic and toon.basic.professions) then return "" end
  if not (toon.professions and toon.professions.gear) then return "" end
  local profs = toon.basic.professions
  local primaries = {}
  if profs.primary and profs.primary.skillID then insert(primaries, profs.primary.skillID) end
  if profs.secondary and profs.secondary.skillID then insert(primaries, profs.secondary.skillID) end
  if #primaries == 0 then return "" end

  local currentExpac = GetExpansionLevel() -- luacheck: globals GetExpansionLevel
  local score, maxScore = 0, 0
  local lines = {}

  for _, skillID in ipairs(primaries) do
    local profName = profNameBySkillID(skillID) or ("skill "..skillID)
    insert(lines, profName)
    local profGear = toon.professions.gear[skillID]
    local slotCount = 0
    if profGear and profGear.slots then
      for _, item in pairs(profGear.slots) do
        slotCount = slotCount + 1
        maxScore = maxScore + PER_SLOT_MAX
        local label = item.link or item.name or "item"
        if item.expacID == currentExpac then
          local r = clamp(item.rarity, 0, MAX_RARITY)
          local t = clamp(item.tier, 0, MAX_TIER)
          score = score + r + t
          local rc = RarityColors[r] or ""
          insert(lines, ("  %s %sR%d|r T%d   (%d/%d)"):format(label, rc, r, t, r + t, PER_SLOT_MAX))
        else
          insert(lines, "  "..label.." |cffff5555(old expac)|r")
        end
      end
    end
    -- Pad to 3 expected slots so missing equipment drags the score.
    for _ = slotCount + 1, 3 do
      maxScore = maxScore + PER_SLOT_MAX
      insert(lines, "  |cffff5555(empty slot)|r")
    end
  end

  if maxScore == 0 then return "" end
  local pct = math.floor((score / maxScore) * 100 + 0.5)
  local color
  if pct == 100 then color = {0, 1, 0, 1}
  elseif pct >= 80 then color = {1, 1, 1, 1}
  elseif pct >= 50 then color = {1, 0.82, 0, 1}
  else color = {1, 0.4, 0.4, 1} end

  return {
    text = pct.."%",
    justifyH = ui.justify.Right,
    color = color,
    onEnter = function(self)
      ui.tip:AnchorTo(self, "ANCHOR_BOTTOMRIGHT", -10, 10)
      ui.tip:ClearLines()
      ui.tip:AddLine(score.." / "..maxScore.." points")
      for _, l in ipairs(lines) do ui.tip:AddLine(l) end
      ui.tip:Show()
    end,
    onLeave = function(self) ui.tip:Hide() end,
  }
end

insert(
  ns.SummaryColumns,
  SummaryColumn:new{
    name = "Profs",
    width = 36,
    justifyH = ui.justify.Right,
    tooltip = {
      "Profession Gear",
      "% of max profession-gear score across both primaries (current expansion). Per slot: rarity (1-5) + crafted tier (1-3) = 8 max. 3 slots x 2 primaries = 48 points.",
    },
    getData = getProfGearScore,
  }
)

-- Bag Status
local NUM_BAG_SLOTS = NUM_BAG_SLOTS -- luacheck: globals NUM_BAG_SLOTS
local getBagStatus = function(toon)
  if not toon.items or not toon.items.bags then return "" end
  local n = NUM_BAG_SLOTS
  for i = 1, NUM_BAG_SLOTS do 
    if toon.items.bags[i].slots >= 38 then n = n - 1
    end 
    if toon.items.bags[i].id == 92748 then n = n -1 -- Portable Refrigerator
    end
  end
  local reagent = toon.items.reagentBag and toon.items.reagentBag.slots >= 40
  if n == 0 and reagent then return GreenCheck end
  return {
    text = (n == 0 and "" or n) .. (reagent and "" or "R"),
    justifyH = ui.justify.Center,
  }
end
insert(
  ns.SummaryColumns,
  SummaryColumn:new{
    icon = Icons.Bag,
    width = 30,
    tooltip = {
      "Bags",
      "Count of bags below 38 slots, plus R if the reagent bag is below 40.",
    },
    getData = getBagStatus,
  }
)

local function formatBestVaultRewardOption(o)
  if not o or o.best == 0 then return nil end
  local t
  if o.bestN > 1 then
    t = o.best.." x"..o.bestN
  else
    t = o.best
  end
  local lines = {}
  for i,n in pairs(o.counts) do
    insert(lines, i.." x"..n)
  end
  return {
    text = t,
    onEnter = function(self)
      self.label:Color(1, 1, 1, 0.8)
      if #lines > 1 then
        ui.tip:AnchorTo(self, "ANCHOR_BOTTOMRIGHT", -10, 10)
        ui.tip:ClearLines()
        for _,l in ipairs(lines) do ui.tip:AddLine(l) end
        ui.tip:Show()
      end
    end,
    onLeave = function(self)
      self.label:Color(1, 1, 1, 1)
      if #lines > 1 then
        ui.tip:Hide()
      end
    end,
  }
end
local UnclaimedVault = {
  atlas = Icons.Vault,
  atlasSize = false,
  position = {
    Center = {},
    Size = {16, 16},
  },
}
insert(
  ns.SummaryColumns,
  SummaryColumn:new{
    name = "Vault",
    width = 50,
    getData = function(t)
      if not t.weeklies then return nil end
      local prefix = t.weeklies.hasUnclaimedVault and ("|A:"..Icons.Vault..":14:14|a ") or ""
      if t.weeklies.vault then
        local r = formatBestVaultRewardOption(t.weeklies.vault)
        if r and prefix ~= "" then r.text = prefix..r.text end
        return r
      end
      if prefix ~= "" then return {text = prefix} end
      return nil
    end,
  }
)

-- M+ keystone level
insert(
  ns.SummaryColumns,
  SummaryColumn:new{
    name = "Key",
    width = 28,
    justifyH = ui.justify.Right,
    tooltip = {
      "Mythic+ Keystone",
      "Current keystone level held by this character.",
    },
    getData = function(t)
      local k = t.weeklies and t.weeklies.keystone
      if not k then return "" end
      return {text = "+"..k, justifyH = ui.justify.Right}
    end,
  }
)

local CappedColor = {1, 0.2, 0.2, 1}
local UncappedColor = {1, 1, 1, 1}
local function formatCrest(c)
  if not c then return "" end
  -- stale DB entries from before the table migration store a bare number
  if type(c) == "number" then
    return c > 0 and {text = c, justifyH = ui.justify.Center} or ""
  end
  if c.quantity == 0 then return "" end
  local lines = {c.quantity .. " held"}
  if c.max > 0 then
    lines[2] = c.earned .. " / " .. c.max .. " earned this week"
    if c.capped then lines[3] = "Weekly cap reached" end
  end
  return {
    text     = c.quantity,
    justifyH = ui.justify.Center,
    color    = c.capped and CappedColor or UncappedColor,
    onEnter  = function(self)
      ui.tip:AnchorTo(self, "ANCHOR_BOTTOMRIGHT", -10, 10)
      ui.tip:ClearLines()
      for _, l in ipairs(lines) do ui.tip:AddLine(l) end
      ui.tip:Show()
    end,
    onLeave = function(self) ui.tip:Hide() end,
  }
end

-- Hero Dawncrest
insert(
  ns.SummaryColumns,
  SummaryColumn:new{
    currencyID = 3345,
    width = 30,
    justifyH = ui.justify.Center,
    tooltip = {"Hero Dawncrest", "Hero Dawncrest held. Red when weekly cap reached."},
    getData = function(t)
      if not t.currency then return "" end
      return formatCrest(t.currency.HeroDawncrest)
    end,
  }
)

-- Myth Dawncrest
insert(
  ns.SummaryColumns,
  SummaryColumn:new{
    currencyID = 3347,
    width = 30,
    justifyH = ui.justify.Center,
    tooltip = {"Myth Dawncrest", "Myth Dawncrest held. Red when weekly cap reached."},
    getData = function(t)
      if not t.currency then return "" end
      return formatCrest(t.currency.MythDawncrest)
    end,
  }
)

local formatDelves = function(toon)
  if not (toon.quests and toon.quests.delves) then return "" end
  local d = toon.quests.delves
  local labels = {}
  for k in pairs(d) do
    if k ~= "complete" and k ~= "missing" then insert(labels, k) end
  end
  if #labels == 0 then return "" end
  if d.complete then return GreenCheck end
  return {
    text = d.missing,
    justifyH = ui.justify.Center,
    onEnter = function(self)
      ui.tip:AnchorTo(self, "ANCHOR_BOTTOMRIGHT", -10, 10)
      ui.tip:ClearLines()
      table.sort(labels)
      for _,label in ipairs(labels) do
        if d[label] then
          ui.tip:AddLine(label)
        else
          ui.tip:AddLine(label, 1, 0, 0)
        end
      end
      ui.tip:Show()
    end,
    onLeave = function(self) ui.tip:Hide() end,
  }
end
insert(
  ns.SummaryColumns,
  SummaryColumn:new{
    name = "D",
    justifyH = ui.justify.Center,
    tooltip = {
      "Delves",
      "Weekly bountiful delve quests remaining. Green check when all done.",
    },
    getData = formatDelves,
  }
)

-- lumber axe (quest 93647 "Lumber For You")
insert(
  ns.SummaryColumns,
  SummaryColumn:new{
    name = "L",
    justifyH = ui.justify.Center,
    tooltip = {
      "Lumber For You",
      "Make sure your alt has their lumber axe! Green check when complete.",
    },
    getData = function(t)
      return t.quests and t.quests.LumberAxe and GreenCheck or ""
    end,
  }
)

-- restored coffer keys (+ shards as fractional, 100 shards = 1 key)
insert(
  ns.SummaryColumns,
  SummaryColumn:new{
    currencyID = 3028, -- Restored Coffer Key
    width = 40,
    tooltip = {
      "Restored Coffer Keys",
      "Keys + shards/100 as a fractional total. Red when shards are capped.",
    },
    getData = function(t)
      if not t.currency then return "" end
      local keys = t.currency.RestoredCofferKey or 0
      local shards = t.currency.CofferKeyShard
      local shardQty = shards and shards.quantity or 0
      if keys == 0 and shardQty == 0 then return "" end
      return {
        text = ("%.2f"):format(keys + shardQty / 100),
        justifyH = ui.justify.Right,
        color = shards and shards.capped and CappedColor or UncappedColor,
      }
    end,
  }
)

-- caches
insert(
  ns.SummaryColumns,
  SummaryColumn:new{
    icon = Icons.Treasure,
    tooltip = {
      "Weekly cache quests completed",
      "Count of weekly activities completed that reward a cache.",
    },
    getData = function(t) return t.weeklies and t.weeklies.caches and t.weeklies.caches > 0 and {text = t.weeklies.caches, justifyH = ui.justify.Center} or "" end,
  }
)

local isDMF = function()
  local day = C_DateAndTime.GetCurrentCalendarTime().monthDay
  local numEvents = C_Calendar.GetNumDayEvents(0,day)
  for i = 1, numEvents do
    -- name, startTime, endTime, description, texture=235447
    local info = C_Calendar.GetHolidayInfo(0,day,i)
    if info and info.texture == 235447 then -- DMF texture
      return true
    end
  end
  return false
end

ns.SummaryColumnsDelayed = function(view)
  if ns._dmfChecked then return end
  ns._dmfChecked = true
  if isDMF() then
    insert(
      ns.SummaryColumns,
      SummaryColumn:new{
        name = "DMF",
        width = 30,
        getData = function(toon)
          return toon.weeklies.dmf and GreenCheck or ""
        end,
      }
    )
    view:addCol(ns.SummaryColumns[#ns.SummaryColumns].colInfo)
  end
end
