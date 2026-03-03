local _, ns = ...
local insert = table.insert
local ui = ns.ui
local Left = ui.justify.Left
local Colors, Icons = ns.Colors, ns.icons
local Class = ns.lua.Class

local SummaryColumn = Class(nil, function(self)
  self.colInfo = {
    name = self.name,
    width = self.width,
    justifyH = self.justifyH,
    backdrop = {color = Colors.TransparentBlack},
    padLeft = self.padLeft,
    atlas = self.icon,
    atlasSize = self.icon and false or nil,
  }
end, {
  -- default options
  name = nil,
  width = 20,
  justifyH = Left,
  padLeft = nil,
  icon = nil,
  getData = function() return "" end, -- function to get data for this column
})

local GreenCheck = {
  atlas = ns.icons.CheckGreen,
  atlasSize = false,
  position = {
    TopLeft = {3, -2},
    BottomRight = {-3, 2},
  },
}

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
    width = 30,
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
    width = 35,
    getData = getILvlString,
  }
)

-- Bag Status
local NUM_BAG_SLOTS = NUM_BAG_SLOTS -- luacheck: globals NUM_BAG_SLOTS
local getBagStatus = function(toon)
  if not toon.items or not toon.items.bags then return "" end
  local n = NUM_BAG_SLOTS
  for i = 1, NUM_BAG_SLOTS do 
    if toon.items.bags[i].slots >= 34 then n = n - 1 
    end 
    if toon.items.bags[i].id == 92748 then n = n -1
    end
  end
  local reagent = toon.items.reagentBag and toon.items.reagentBag.slots >= 36
  return n == 0 and reagent and GreenCheck or (
    (n == 0 and "" or n) .. (reagent and "" or "R")
  )
end
insert(
  ns.SummaryColumns,
  SummaryColumn:new{
    icon = Icons.Bag,
    getData = getBagStatus,
  }
)

local formatTaskWWIRep = function(toon)
  if not (toon.quests and toon.quests.WWIRep) then return "" end
  if (toon.basic.level < ns.wow.maxLevel) then return "" end
  if toon.quests.WWIRep.complete then
    return {
      atlas = ns.icons.CheckGreen,
      atlasSize = false,
      position = {
        TopLeft = {3, -2},
        BottomRight = {-3, 2},
      },
    }
  end
  if toon.quests.WWIRep.missing then
    return {
      text = toon.quests.WWIRep.missing,
      justifyH = ui.justify.Center,
      onEnter = function(self)
        ui.tip:AnchorTo(self, "ANCHOR_BOTTOMRIGHT", -10, 10)
        ui.tip:ClearLines()
        for _,zone in ipairs({"Dornogal", "Assembly", "Hallowfall", "Azjkahet", "Undermine", "Arathi", "Karesh"}) do
          ui.tip:AddLine(zone..' '..(toon.quests.WWIRep[zone] and 'true' or 'false'))
        end
        ui.tip:Show()
      end,
      onLeave = function(self) ui.tip:Hide() end,
    }
  end
  return ""
end
insert(
  ns.SummaryColumns,
  SummaryColumn:new{
    name = "R",
    justifyH = ui.justify.Center,
    getData = formatTaskWWIRep,
  }
)

-- insert(
--   ns.SummaryColumns,
--   SummaryColumn:new{
--     name = "U",
--     justifyH = ui.justify.Center,
--     getData = function(t) return t.quests and t.quests.UndermineStoryMode and GreenCheck or "" end,
--   }
-- )

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
insert(
  ns.SummaryColumns,
  SummaryColumn:new{
    name = "Vault",
    width = 50,
    getData = function(t)
      return t.weeklies.vault and {
        atlas = "greatVault-whole-normal",
        atlasSize = false,
        position = {
          TopLeft = {0, -2},
          BottomRight = {-34, 2},
        },
      } or formatBestVaultRewardOption(t.weeklies.vault)
    end,
  }
)

-- theater troupe
insert(
  ns.SummaryColumns,
  SummaryColumn:new{
    icon = Icons.Theatre,
    getData = function(t) return t.weeklies and t.weeklies.theater and GreenCheck or "" end,
  }
)

-- caches
insert(
  ns.SummaryColumns,
  SummaryColumn:new{
    icon = Icons.Treasure,
    getData = function(t) return t.weeklies and t.weeklies.caches and t.weeklies.caches > 0 and {text = t.weeklies.caches, justifyH = ui.justify.Center} or "" end,
  }
)

insert(
  ns.SummaryColumns,
  SummaryColumn:new{
    icon = Icons.Vault,
    getData = function(t) return t.currency and (t.currency.RestoredCofferKey or 0) > 0 and {text = t.currency.RestoredCofferKey, justifyH = ui.justify.Center} or "" end,
  }
)

 insert(
   ns.SummaryColumns,
   SummaryColumn:new{
     icon = Icons.preMidnight,
     getData = function(t) return t.weeklies and t.weeklies.preMidnight and (t.weeklies.preMidnight.three or t.weeklies.preMidnight.eight) and GreenCheck or "" end,
   }
 )

-- insert(
--   ns.SummaryColumns,
--   SummaryColumn:new{
--     icon = Icons.Nightfall,
--     getData = function(t)
--       return t.dailies and t.dailies.nightfall and t.dailies.nightfall > 0
--         and {text = t.dailies.nightfall, justifyH = ui.justify.Center} or ""
--     end,
--   }
-- )

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
