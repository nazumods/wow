local _, ns = ...
local ui = ns.ui

local Class, Frame = ns.lua.Class, ui.Frame
local TopLeft, BottomRight = ui.edge.TopLeft, ui.edge.BottomRight

local CleanFrame = Class(Frame, function(self)
  self.border = Frame:new{
    parent = self,
    name = "$parentBorder",
    template = "BackdropTemplate",
    position = {
      TopLeft = {self, TopLeft, -3, 3},
      BottomRight = {self, BottomRight, 3, -3},
    },
  }
  -- from BackdropTemplate
  self.border._widget:SetBackdrop({
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 16,
    insets = {left = 4, right = 4, top = 4, bottom = 4},
  })
  self.border._widget:SetBackdropBorderColor(0, 0, 0, .5)
end, {
  parent = UIParent,
  clamped = true,
  strata = "MEDIUM",
  background = {0.11372549019, 0.14117647058, 0.16470588235, 1},
})
ui.CleanFrame = CleanFrame
