local _, ns = ...
local ui = ns.ui
local Class = ns.lua.Class
local Frame = ui.Frame

---@class EditBox: Frame
---@field multiline boolean? enable multiline mode (skips InputBoxTemplate)
---@field fontObj table? WoW font object to apply
---@field autoFocus boolean? whether to auto-focus when shown
---@field text string? initial text content
---@field cursorPosition number? initial cursor position
local EditBox = Class(Frame, function(self)
  if self.multiline then self._widget:SetMultiLine(true) end
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
  CreateWidget = function(self)
    local template = self.template ~= "" and self.template or nil
    return CreateFrame(self.type, self.name, self.parent and self.parent._widget or self.parent, template)
  end,
})
ui.EditBox = EditBox

---@class EditBox
---@field Text fun(text: string?): string|EditBox
function EditBox:Text(text)
  if not text then return self._widget:GetText() end
  self._widget:SetText(text)
  return self
end

---@class EditBox
---@field CursorPosition fun(pos: number?): number|EditBox self if pos was given, cursor position otherwise
function EditBox:CursorPosition(pos)
  if pos == nil then return self._widget:GetCursorPosition() end
  self._widget:SetCursorPosition(pos)
  return self
end

---@class EditBox
---@field HighlightText fun(startPos: number?, endPos: number?): EditBox
function EditBox:HighlightText(startPos, endPos)
  self._widget:HighlightText(startPos, endPos)
  return self
end
