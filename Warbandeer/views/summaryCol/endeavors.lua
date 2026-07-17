---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Center = ui.justify.Center

-- Endeavors: per character, which neighborhood endeavor that character is actively feeding right
-- now — the faction crest of the house its endeavor XP currently flows to (it can change on
-- demand). The crest carries a gold border box (= actively feeding). Blank when the character isn't
-- in an endeavor / hasn't been seen since the capture landed. Rendered inline via a baked-colour
-- crest TGA (inline markup can't runtime-tint). The house-XP pools themselves are account-wide
-- (identical for every character), so they live in the Overview, not per Summary row. (issue #550)

local CREST = "Interface\\AddOns\\Warbandeer\\icons\\endeavor-"
local SZ = 14

table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    key = "endeavors", label = "Endeavors",
    iconPath = "Interface\\AddOns\\Warbandeer\\icons\\endeavors.tga",
    iconColor = ns.theme.colors.muted,  -- carpenter's-hammer glyph, muted like the sibling headers
    width = 30,
    justifyH = Center,
    tooltip = {
      "Endeavors",
      "Which neighborhood endeavor each character is actively feeding right now — the crest of the"
        .. " house its endeavor XP currently flows to. It can change on demand. House-XP totals are"
        .. " account-wide, shown in the Overview.",
    },
    getData = function(toon)
      local h = ns.api:GetHousing(toon.name)
      if not h then return "" end
      return {
        text = ("|T%s%s-sub:%d:%d|t"):format(CREST, h.active, SZ, SZ),
        justifyH = Center,
        onEnter = function(self)
          ns.AnchorTip(self)
          ui.tip:ClearLines()
          ui.tip:AddLine("Endeavors")
          if h.title then ui.tip:AddLine(h.title, 1, 1, 1) end
          ui.tip:AddLine(("Active: |cffffffff%s|r house"):format(h.active == "horde" and "Horde" or "Alliance"))
          ui.tip:Show()
        end,
        onLeave = function() ui.tip:Hide() end,
      }
    end,
  }
)
