---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local insert = table.insert

local formatDelves = function(toon)
  if not (toon.quests and toon.quests.delves) then return "" end
  local d = toon.quests.delves
  local labels = {}
  for k in pairs(d) do
    if k ~= "complete" and k ~= "missing" then insert(labels, k) end
  end
  if #labels == 0 then return "" end
  if d.complete then return ns.GreenCheck end
  return {
    text = d.missing,
    justifyH = ui.justify.Center,
    onEnter = function(self)
      ns.AnchorTip(self)
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

table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    key = "delves", label = "Delves",
    iconPath = "Interface\\AddOns\\Warbandeer\\icons\\delve.tga",
    iconColor = ns.theme.colors.muted,
    width = 30,
    justifyH = ui.justify.Center,
    tooltip = {
      "Delves",
      "Weekly bountiful delve quests remaining. Green check when all done.",
    },
    getData = formatDelves,
  }
)
