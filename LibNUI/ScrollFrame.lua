local _, ns = ...
local ui = ns.ui
local Class = ns.lua.Class
local Frame = ui.Frame

local ScrollFrame = Class(Frame, function(self)
end, {
  type = "ScrollFrame",
  template = "UIPanelScrollFrameTemplate",
})
ui.ScrollFrame = ScrollFrame

function ScrollFrame:Child(child)
  if not child then
    return self._widget:GetScrollChild()
  end
  self._widget:SetScrollChild(child._widget or child)
  return self
end
