---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local unpack = unpack
local Class = ns.lua.Class
local Frame = ui.Frame

---@class EditBox: Frame
---@field multiline boolean? enable multiline mode (skips InputBoxTemplate)
---@field fontObj table? WoW font object to apply
---@field autoFocus boolean? whether to auto-focus when shown
---@field text string? initial text content
---@field cursorPosition number? initial cursor position
---@field placeholder string? muted prompt shown while the box is empty
---@field placeholderColor string|number[]? theme token or rgba for it (default "muted")
---@field placeholderInset number[]? {left, right} px insets (default {6, -4}) — align it with the typed text
---@field _placeholder Label? the prompt's label, nil unless `placeholder` was given
local EditBox = Class(Frame, function(self)
  if self.multiline then self._widget:SetMultiLine(true) end
  if self.fontObj then self._widget:SetFontObject(self.fontObj) end
  self._widget:SetAutoFocus(self.autoFocus or false)
  if self.placeholder then self:_buildPlaceholder() end
  if self.text then self:Text(self.text) end
  if self.cursorPosition then self._widget:SetCursorPosition(self.cursorPosition) end
  -- Keep the prompt in step with typing WITHOUT taking OnTextChanged away from the caller: the
  -- Frame dispatcher calls `self.OnTextChanged`, so wrap whatever was supplied rather than replace
  -- it. A caller that reaches past the class to `_widget:SetScript("OnTextChanged", …)` clobbers
  -- this — but that already breaks every other dispatched script, and the library's own rule is
  -- not to touch `_widget` from outside.
  local supplied = self.OnTextChanged
  self.OnTextChanged = function(box, ...)
    box:_syncPlaceholder()
    if supplied then supplied(box, ...) end
  end
end, {
  type = "EditBox",
  template = "InputBoxTemplate",
  scripts = {
    "OnEditFocusLost",
    "OnEnterPressed",
    "OnEscapePressed",
    "OnTextChanged",
  },
  CreateWidget = function(self)
    local template = self.template ~= "" and self.template or nil
    return CreateFrame(self.type, self.name, self.parent and self.parent._widget or self.parent, template)
  end,
})
ui.EditBox = EditBox

-- The placeholder is parented to the EditBox itself, not to whatever framing box surrounds it, so
-- it sits on exactly the baseline and left edge the typed text will land on. Two-point anchored so
-- it truncates rather than overflowing a narrow box.
function EditBox:_buildPlaceholder()
  local inset = self.placeholderInset or {6, -4}
  self._placeholder = ui.Label:new{
    parent = self, color = self.placeholderColor or "muted", wordWrap = false,
    position = { Left = {inset[1], 0}, Right = {inset[2], 0} }, text = self.placeholder,
  }
  self:_syncPlaceholder()
end

-- Shown whenever the box is empty — including while focused, so an empty box always says what it
-- wants. Cheap enough to call unconditionally; a box with no placeholder just returns.
function EditBox:_syncPlaceholder()
  if not self._placeholder then return end
  self._placeholder:SetShown((self._widget:GetText() or "") == "")
end

---The placeholder text. Setting it builds the label on first use, so a box can gain a prompt after
---construction; setting nil or "" removes the prompt without destroying the label.
---@param text string?
---@return string|EditBox
function EditBox:Placeholder(text)
  if text == nil then return self._placeholder and self._placeholder:Text() end
  self.placeholder = text
  if not self._placeholder then self:_buildPlaceholder() else self._placeholder:Text(text) end
  self:_syncPlaceholder()
  return self
end

---@class EditBox
---@field Text fun(self: EditBox, text: string?): string|EditBox
function EditBox:Text(text)
  if not text then return self._widget:GetText() end
  self._widget:SetText(text)
  -- SetText fires OnTextChanged in game, but syncing here too means the prompt is right even when
  -- the caller has taken the script over, and at construction before any script can have run.
  self:_syncPlaceholder()
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
---@field HighlightText fun(self: EditBox, startPos: number?, endPos: number?): EditBox
function EditBox:HighlightText(startPos, endPos)
  self._widget:HighlightText(startPos, endPos)
  return self
end

-- {path, size[, flags]} tuple. Getter returns the current font as the same
-- tuple. Lets callers resize the text without touching `_widget` directly.
---@param fontInfo table?
---@return table|EditBox
function EditBox:Font(fontInfo)
  if not fontInfo then return {self._widget:GetFont()} end
  self._widget:SetFont(unpack(fontInfo))
  return self
end
