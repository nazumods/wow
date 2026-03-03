local _, ns = ...
local _G, insert = _G, table.insert
local UISpecialFrames = UISpecialFrames

local ui = ns.ui
local Class = ns.lua.Class
local Frame = ui.Frame

-- dialog with title bar and close button, closable with escape
local Dialog = Class(Frame, function(self)
  local frame = self._widget
  frame:SetFrameStrata("DIALOG")
  frame:SetClampedToScreen(true)

  -- make it closable with Escape key
  _G[frame:GetName()] = frame -- put it in the global namespace
  insert(UISpecialFrames, frame:GetName()) -- make it a special frame

  -- set the title
  frame:SetTitle(self.title or frame:GetName())
  self.title = nil
  if self.titleColor then
    self._widget.TitleContainer.TitleText:SetTextColor(unpack(self.titleColor))
  end
end)
ui.Dialog = Dialog

function Dialog:makeTitlebarDraggable()
  self._widget.TitleContainer:SetScript("OnMouseDown", function()
    self._widget:StartMoving()
  end)
  self._widget.TitleContainer:SetScript("OnMouseUp", function()
    self._widget:StopMovingOrSizing()
  end)
  return self
end
