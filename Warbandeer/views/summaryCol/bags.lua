---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local NUM_BAG_SLOTS = NUM_BAG_SLOTS

-- Bag Status
local getBagStatus = function(toon)
  if not toon.items or not toon.items.bags then return "" end
  local n = NUM_BAG_SLOTS
  for i = 1, NUM_BAG_SLOTS do
    if toon.items.bags[i].slots >= 36 then n = n - 1
    end
    if toon.items.bags[i].id == 92748 then n = n -1 -- Portable Refrigerator
    end
  end
  local reagent = toon.items.reagentBag and toon.items.reagentBag.slots >= 38
  if n == 0 and reagent then return ns.GreenCheck end
  return {
    text = (n == 0 and "" or n) .. (reagent and "" or "R"),
    justifyH = ui.justify.Center,
  }
end

-- footer: warband-wide total of sub-par bags, split bags vs reagent bags
local getBagFooter = function(toons)
  local bags, reagent = 0, 0
  for _,t in ipairs(toons) do
    if t.items and t.items.bags then
      for i = 1, NUM_BAG_SLOTS do
        local b = t.items.bags[i]
        if b and b.id ~= 92748 and b.slots < 36 then bags = bags + 1 end
      end
    end
    if t.items and t.items.reagentBag and t.items.reagentBag.slots < 38 then
      reagent = reagent + 1
    end
  end
  local total = bags + reagent
  if total == 0 then return "" end
  return {
    text = total,
    justifyH = ui.justify.Center,
    color = {1, 1, 1, 0.6},
    onEnter = function(self)
      ui.tip:AnchorTo(self, "ANCHOR_BOTTOMRIGHT", -10, 10)
      ui.tip:ClearLines()
      ui.tip:AddLine(bags.." bags below 36 slots")
      ui.tip:AddLine(reagent.." reagent bags below 38 slots")
      ui.tip:Show()
    end,
    onLeave = function(self) ui.tip:Hide() end,
  }
end

table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    key = "bags", label = "Bag Space",
    iconPath = "Interface\\AddOns\\Warbandeer\\icons\\bag.tga",
    iconColor = ns.theme.colors.muted,
    width = 30,
    justifyH = ui.justify.Center,
    tooltip = {
      "Bags",
      "Count of bags below 36 slots, plus R if the reagent bag is below 38.",
    },
    getData = getBagStatus,
    getFooter = getBagFooter,
  }
)
