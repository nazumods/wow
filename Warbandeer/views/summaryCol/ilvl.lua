---@class Warbandeer
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local insert = table.insert
local ITEM_STANDARD_COLOR = ITEM_STANDARD_COLOR -- luacheck: globals ITEM_STANDARD_COLOR

local getILvlString = function(toon)
  local lines = {}
  if toon.equipment then
    local orderedSlots = {"Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands", "Waist", "Legs", "Feet", "Finger1", "Finger2", "Trinket1", "Trinket2", "MainHand", "OffHand"}
    for _,value in ipairs(orderedSlots) do
      local slot = toon.equipment.slots and toon.equipment.slots[value]
      if slot then
        local suffix = ""
        if slot.track and slot.trackLevel and slot.trackLevel > 0 then
          suffix = " (" .. slot.track:sub(1,1) .. slot.trackLevel .. ")"
        end
        insert(lines, value .. " " .. ns.IlvlColor(slot.ilvl) .. suffix)
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
