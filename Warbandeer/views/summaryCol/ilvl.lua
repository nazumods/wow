---@class Warbandeer
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local insert = table.insert
local ITEM_STANDARD_COLOR = ITEM_STANDARD_COLOR -- luacheck: globals ITEM_STANDARD_COLOR

local trackColors = {
  Explorer   = ITEM_STANDARD_COLOR,
  Adventurer = ITEM_GOOD_COLOR,
  Veteran    = ITEM_SUPERIOR_COLOR,
  Champion   = ITEM_EPIC_COLOR,
  Hero       = ITEM_LEGENDARY_COLOR,
  Mythic     = ITEM_LEGENDARY_COLOR,
}

local getILvlString = function(toon)
  local lines = {}
  if toon.equipment then
    local orderedSlots = {"Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands", "Waist", "Legs", "Feet", "Finger1", "Finger2", "Trinket1", "Trinket2", "MainHand", "OffHand"}
    for _,value in ipairs(orderedSlots) do
      local slot = toon.equipment.slots and toon.equipment.slots[value]
      if slot then
        local suffix = ""
        if slot.track and slot.trackLevel and slot.trackLevel > 0 then
          local letter = slot.track:sub(1,1)
          local color  = trackColors[slot.track]
          suffix = " (" .. (color and color:WrapTextInColorCode(letter) or letter) .. slot.trackLevel .. ")"
        end
        insert(lines, value .. " " .. ns.IlvlColor(slot.ilvl) .. suffix)
      end
    end
  end
  return {
    text = toon.basic.level < ns.wow.maxLevel and ITEM_STANDARD_COLOR:WrapTextInColorCode(toon.equipment.ilvl) or ns.IlvlColor(toon.equipment.ilvl),
    justifyH = ui.justify.Right,
    onEnter = function(self)
      ns.AnchorTip(self)
      ui.tip:ClearLines()
      for _,l in ipairs(lines) do ui.tip:AddLine(l) end
      ui.tip:Show()
    end,
    onLeave = function(self) ui.tip:Hide() end,
    onClick = function() ns:view("gear") end,
  }
end

table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    name = "iLvl",
    width = 30,
    justifyH = ui.justify.Right,
    getData = getILvlString,
  }
)
