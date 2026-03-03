local _, ns = ...
local ui = ns.ui
local Class, Frame, Label = ns.lua.Class, ui.Frame, ui.Label

local DetailView = Class(Frame, function(self)
  local data = ns.api:GetCharacterData()
  self.r = Label:new{
    parent = self,
    text = data.basic.level.." "..data.race.." "..data.className.." on "..data.realm,
    position = {TopLeft = {2, -2}},
  }
  self.r2 = Label:new{
    parent = self,
    font = ns.ui.fonts.GameFontHighlightSmall,
    text = "ilvl "..data.equipment.ilvl,
    position = {TopLeft = {2, -22}},
  }
  self._title = data.name
end, {
  position = {
    Width = 500,
    Height = 500,
    Hide = true,
  },
  name = "detail",
  _title = "Detail",
})
DetailView.name = "detail"
ns.views.DetailView = DetailView

function DetailView:update()
end
