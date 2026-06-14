---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local insert = table.insert

-- "Catch-up" count column: how many of the four cheapest-to-upgrade slots
-- (Head, Neck, Hands, Waist) are below item level 180. These are the slots a
-- fresh max-level alt fills first, so the count flags characters still short on
-- the baseline gear. Only reported for level 81+ characters (the catch-up band);
-- below that the cell reads a muted em-dash. A green check means all four are >= 180.
local SLOTS = {"Head", "Neck", "Hands", "Waist"}
local MIN_ILVL = 180
local MIN_LEVEL = 81

local getData = function(toon)
  if (toon.basic.level or 0) < MIN_LEVEL then return ns.ZeroDashC end

  local below = {}
  for _, name in ipairs(SLOTS) do
    local slot = toon.equipment and toon.equipment.slots and toon.equipment.slots[name]
    local ilvl = slot and slot.ilvl or 0
    if ilvl < MIN_ILVL then
      insert(below, ("%s  %s"):format(name, ns.IlvlColor(ilvl)))
    end
  end

  local n = #below
  if n == 0 then return ns.GreenCheck end

  return {
    text = tostring(n),
    color = ns.CappedColor,
    justifyH = ui.justify.Center,
    fontInfo = ns.theme.fonts.number,
    onEnter = function(self)
      ns.AnchorTip(self)
      ui.tip:ClearLines()
      ui.tip:AddLine(("%d slot%s below item level %d"):format(n, n == 1 and "" or "s", MIN_ILVL))
      for _, l in ipairs(below) do ui.tip:AddLine(l) end
      ui.tip:Show()
    end,
    onLeave = function() ui.tip:Hide() end,
    onClick = function() ns:view("gear") end,
  }
end

insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    name = "<180",
    width = 30,
    padLeft = 7,
    justifyH = ui.justify.Center,
    tooltip = "Midnight reputation Items needed",
    getData = getData,
  }
)
