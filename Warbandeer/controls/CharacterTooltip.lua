local _, ns = ...
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

  self.specialization = Label:new{
    parent = self,
    position = {
      TopLeft = {self.name, ui.edge.BottomLeft, 0, -5},
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
ui.CharacterTooltip = Tooltip

function Tooltip:SetToon(toon)
  self.toon = toon

  self.name:Text(toon.name):Color(Colors[toon.classKey])
  self.specialization:Text(toon.basic.specialization.active or "")
  self.class:Text(toon.className):Color(Colors[toon.classKey])
  self.realm:Text(toon.realm)
end

local _tooltip = nil
ui.ShowCharacterTooltip = function(toon, parent, position)
  if not _tooltip then _tooltip = Tooltip:new{} end
  _tooltip:SetToon(toon)
  _tooltip:Position(position)
  _tooltip:Show()
  _tooltip:Level(parent:Level() + 1)
end

ui.HideCharacterTooltip = function()
  if _tooltip then
    _tooltip:Hide()
  end
end
