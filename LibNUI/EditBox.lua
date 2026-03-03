local _, ns = ...
local ui = ns.ui
local Class = ns.lua.Class
local Frame = ui.Frame

local EditBox = Class(Frame, function(self)
  if self.fontObj then self._widget:SetFontObject(self.fontObj) end
  self._widget:SetAutoFocus(self.autoFocus or false)
  if self.text then self:Text(self.text) end
  if self.cursorPosition then self._widget:SetCursorPosition(self.cursorPosition) end
end, {
  type = "EditBox",
  template = "InputBoxTemplate",
  scripts = {
    "OnEditFocusLost",
    "OnEnterPressed",
    "OnEscapePressed",
  },
})
ui.EditBox = EditBox

function EditBox:Text(text)
  if not text then return self._widget:GetText() end
  self._widget:SetText(text)
  return self
end
