local _, ns = ...
local ui = ns.ui

local Class, TabFrame, TableFrame = ns.lua.Class, ui.TabFrame, ui.TableFrame
local insert = table.insert
local Armor = ns.wow.Armor

local colInfo = {
  -- faction
  { width = 20, justifyH = ui.justify.Left, backdrop = {color = {0, 0, 0, 0}} },
  -- role
  { width = 20, justifyH = ui.justify.Left, backdrop = {color = {0, 0, 0, 0}}, padLeft = 2 },
  { name = "Character", width = 105, justifyH = ui.justify.Left, backdrop = {color = {0, 0, 0, 0}}, padLeft = 2 },
  { name = "Lvl",  width = 30, justifyH = ui.justify.Left, backdrop = {color = {0, 0, 0, 0}} },
  { name = "iLvl", width = 35, justifyH = ui.justify.Left, backdrop = {color = {0, 0, 0, 0}} },
  --
  { name = "Head", width = 60, justifyH = ui.justify.Center, backdrop = {color = {0, 0, 0, 0}} },
  { name = "Neck", width = 60, justifyH = ui.justify.Center, backdrop = {color = {0, 0, 0, 0}} },
  { name = "Shdr", width = 60, justifyH = ui.justify.Center, backdrop = {color = {0, 0, 0, 0}} },
  { name = "Back", width = 60, justifyH = ui.justify.Center, backdrop = {color = {0, 0, 0, 0}} },
  { name = "Chst", width = 60, justifyH = ui.justify.Center, backdrop = {color = {0, 0, 0, 0}} },
  { name = "Wrst", width = 60, justifyH = ui.justify.Center, backdrop = {color = {0, 0, 0, 0}} },
  { name = "Hand", width = 60, justifyH = ui.justify.Center, backdrop = {color = {0, 0, 0, 0}} },
  { name = "Wast", width = 60, justifyH = ui.justify.Center, backdrop = {color = {0, 0, 0, 0}} },
  { name = "Legs", width = 60, justifyH = ui.justify.Center, backdrop = {color = {0, 0, 0, 0}} },
  { name = "Feet", width = 60, justifyH = ui.justify.Center, backdrop = {color = {0, 0, 0, 0}} },
  { name = "Fgr1", width = 60, justifyH = ui.justify.Center, backdrop = {color = {0, 0, 0, 0}} },
  { name = "Fgr2", width = 60, justifyH = ui.justify.Center, backdrop = {color = {0, 0, 0, 0}} },
  { name = "Tnk1", width = 60, justifyH = ui.justify.Center, backdrop = {color = {0, 0, 0, 0}} },
  { name = "Tnk2", width = 60, justifyH = ui.justify.Center, backdrop = {color = {0, 0, 0, 0}} },
  { name = "MH",   width = 60, justifyH = ui.justify.Center, backdrop = {color = {0, 0, 0, 0}} },
  { name = "OH",   width = 60, justifyH = ui.justify.Center, backdrop = {color = {0, 0, 0, 0}} },
}

local tableWidth = 0
for _, col in ipairs(colInfo) do tableWidth = tableWidth + col.width end

---@class GearView: TabFrame
local GearView = Class(TabFrame, function(self)
  self._tables = {}
  for i = 1, #Armor.types do
    self._tables[i] = TableFrame:new{
      parent   = self:Tab(i),
      colInfo  = colInfo,
      position = { TopLeft = {0, 0} },
    }
  end
  self:Width(tableWidth)
end, {
  name   = "gear",
  _title = "Gear",
  tabs   = Armor.types,
})
GearView.name = "gear"
ns.views.GearView = GearView

---@param armorType string
---@return table
function GearView:GetCharacters(armorType)
  local toons = ns.api.GetAllCharacters()
  local filtered = {}
  for _, t in ipairs(toons) do
    if Armor.byClass[t.classKey] == armorType then
      insert(filtered, t)
    end
  end
  table.sort(filtered, function(c1, c2)
    if c1.basic.level ~= c2.basic.level then return c1.basic.level > c2.basic.level end
    if c1.equipment.ilvl ~= c2.equipment.ilvl then return c1.equipment.ilvl > c2.equipment.ilvl end
    return c1.name < c2.name
  end)
  return filtered
end

local getNameString = function(toon)
  local current = ns.api.GetCurrentCharacter()
  local s = toon.name
  if s == current then
    s = s.." |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:14:14|t"
  end
  return {
    text = s,
    color = ns.Colors[toon.classKey or toon.className],
    onEnter = function(self)
      ui.tip:AnchorTo(self, "ANCHOR_BOTTOMRIGHT", -10, 10)
      ui.tip:ClearLines()
      ui.tip:AddLine(toon.realm)
      ui.tip:AddLine(toon.specializationActive)
      ui.tip:Show()
    end,
    onLeave = function(self) ui.tip:Hide() end,
  }
end

local function slotStr(slot)
  if not slot then return "" end
  local text = ns.IlvlColor(slot.ilvl)
  if slot.track and slot.trackLevel and slot.trackLevel > 0 then
    text = text .. "(" .. slot.track:sub(1,1) .. slot.trackLevel .. ")"
  end
  return { text = text, justifyH = ui.justify.Center }
end

local getILvlString = function(toon)
  local lines = {}
  if toon.equipment then
    for slot, item in pairs(toon.equipment.slots) do
      insert(lines, slot.." "..ns.IlvlColor(item.ilvl))
    end
  end
  return {
    text = toon.basic.level < ns.wow.maxLevel and (ITEM_STANDARD_COLOR:WrapTextInColorCode(toon.equipment.ilvl)) or ns.IlvlColor(toon.equipment.ilvl),
    onEnter = function(self)
      ui.tip:AnchorTo(self, "ANCHOR_BOTTOMRIGHT", -10, 10)
      ui.tip:ClearLines()
      for _,l in ipairs(lines) do ui.tip:AddLine(l) end
      ui.tip:Show()
    end,
    onLeave = function(self) ui.tip:Hide() end,
  }
end

---@param toon table
---@return table
function GearView:GetRowData(toon)
  return toon.equipment and toon.equipment.slots and {
    toon.isAlliance and ns.icons.AllianceLight or ns.icons.HordeLight,
    toon.basic.specialization and ns.icons[toon.basic.specialization.role] or "",
    getNameString(toon),
    toon.basic.level,
    getILvlString(toon),
    slotStr(toon.equipment.slots.Head),
    slotStr(toon.equipment.slots.Neck),
    slotStr(toon.equipment.slots.Shoulder),
    slotStr(toon.equipment.slots.Back),
    slotStr(toon.equipment.slots.Chest),
    slotStr(toon.equipment.slots.Wrist),
    slotStr(toon.equipment.slots.Hands),
    slotStr(toon.equipment.slots.Waist),
    slotStr(toon.equipment.slots.Legs),
    slotStr(toon.equipment.slots.Feet),
    slotStr(toon.equipment.slots.Finger1),
    slotStr(toon.equipment.slots.Finger2),
    slotStr(toon.equipment.slots.Trinket1),
    slotStr(toon.equipment.slots.Trinket2),
    slotStr(toon.equipment.slots.MainHand),
    slotStr(toon.equipment.slots.OffHand),
  } or {"", "", "", "", "", "", "", "", "", "", "", "", "", ""}
end

---@param armorType string
---@return table
function GearView:GetData(armorType)
  local data = {}
  for _, t in pairs(self:GetCharacters(armorType)) do
    insert(data, self:GetRowData(t))
  end
  return data
end

function GearView:OnBeforeShow()
  local maxHeight = 0
  for i, armorType in ipairs(Armor.types) do
    local tbl = self._tables[i]
    tbl.data = self:GetData(armorType)
    tbl:update()
    local h = tbl:Height()
    if h > maxHeight then maxHeight = h end
  end
  self:Height(self.tabHeight + maxHeight)
end
