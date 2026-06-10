---@type Warbandeer
local ns = select(2, ...)
local ui = ns.ui
local Colors = ns.Colors
local Class, CleanFrame = ns.lua.Class, ui.CleanFrame
local Label = ui.Label

local Tooltip = Class(CleanFrame, function(self)
  local h, w = 0, 0

  self.name = Label:new{
    parent = self,
    position = {
      TopLeft = {2, -2},
    },
    color = Colors.Warrior,
    text = "Name",
  }
  h = h + self.name:Height() + 2

  self.race = Label:new{
    parent = self,
    position = {
      TopLeft = {self.name, ui.edge.BottomLeft, 0, -5},
    },
    color = NORMAL_FONT_COLOR,
    text = "Race",
  }
  h = h + self.race:Height() + 5
  w = w + self.race:Width()

  self.specialization = Label:new{
    parent = self,
    position = {
      TopLeft = {self.race, ui.edge.BottomLeft, 0, -5},
    },
    color = NORMAL_FONT_COLOR,
    text = "Specialization",
  }
  h = h + self.specialization:Height() + 5
  w = w + self.specialization:Width()
  self.class = Label:new{
    parent = self,
    position = {
      BottomLeft = {self.specialization, ui.edge.BottomRight, 5, 0},
    },
    color = Colors.Warrior,
    text = "Warrior",
  }
  w = w + self.class:Width()

  self.realm = Label:new{
    parent = self,
    position = {
      TopLeft = {self.specialization, ui.edge.BottomLeft, 0, -5},
    },
    color = NORMAL_FONT_COLOR,
    text = "Realm",
  }
  h = h + self.realm:Height() + 5

  self.level = Label:new{
    parent = self,
    position = {
      TopLeft = {self.realm, ui.edge.BottomLeft, 0, -10},
    },
    color = WHITE_FONT_COLOR,
    text = "Level",
  }
  h = h + self.level:Height() + 10
  self.levelNum = Label:new{
    parent = self,
    position = {
      BottomLeft = {self.level, ui.edge.BottomRight, 5, 0},
    },
    color = WHITE_FONT_COLOR,
    text = "80",
  }

  -- needs bag
  -- druid needs Deamwalk

  self:Height(h)
  self:Width(w)
  self:Hide()
end, {
  -- defaults for inherited settings
  parent = UIParent,
  strata = "DIALOG",
  background = {0, 0, 0, 0.7},
  inset = 3,
  position = {
    TopLeft = {20, -20},
    Width = 400,
  },
  -- required settings
  toon = nil,
  -- defaults for optional settings
})
ns.CharacterTooltip = Tooltip

function Tooltip:SetToon(toon)
  self.toon = toon

  self.name:Text(toon.name):Color(Colors[toon.classKey])
  self.specialization:Text(toon.basic.specialization.active or "")
  local raceList = toon.isAlliance and ns.api.ALLIANCE_RACES or ns.api.HORDE_RACES
  self.race:Text(raceList[toon.raceIdx] or toon.race or "")
  self.class:Text(toon.className):Color(Colors[toon.classKey])
  self.realm:Text(toon.realm)
end

-- Configured tooltip side (index into ns.TOOLTIP_SIDES): 1=Left, 2=Right.
function ns.TooltipSide()
  return ns.db.settings.tooltipSide or 1
end

-- Anchor the tooltip below the hovered cell on the configured side. Left anchors
-- the tooltip's top-right so it extends leftward, keeping it clear of the cursor;
-- Right keeps the original behaviour of extending rightward.
local function sidePosition(parent)
  if ns.TooltipSide() == 2 then
    return { TopLeft = {parent, ui.edge.Bottom, 20, -10} }
  end
  return { TopRight = {parent, ui.edge.Bottom, -20, -10} }
end

-- Side-aware anchor for the shared LibNUI tooltip (`ui.tip`), used by the summary
-- column cell tooltips. Mirrors sidePosition via ui.tip's GameTooltip-style
-- anchors: Left extends the tooltip leftward (clear of the cursor), Right keeps
-- the original down-right placement.
function ns.AnchorTip(frame)
  if ns.TooltipSide() == 2 then
    ui.tip:AnchorTo(frame, "ANCHOR_BOTTOMRIGHT", -10, 10)
  else
    ui.tip:AnchorTo(frame, "ANCHOR_BOTTOMLEFT", 10, 10)
  end
end

local _tooltip = nil
-- `position` overrides the side setting when supplied (LibNUI position table).
ns.ShowCharacterTooltip = function(toon, parent, position)
  if not _tooltip then _tooltip = Tooltip:new{} end
  _tooltip:SetToon(toon)
  _tooltip:ClearAllPoints()
  _tooltip:Position(position or sidePosition(parent))
  _tooltip:Show()
  _tooltip:Level(parent:Level() + 1)
end

ns.HideCharacterTooltip = function()
  if _tooltip then
    _tooltip:Hide()
  end
end
