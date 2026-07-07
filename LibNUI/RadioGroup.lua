---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local Class = ns.lua.Class
local Frame, Label, CheckButton = ui.Frame, ui.Label, ui.CheckButton

-- A vertical stack of mutually-exclusive options — the single-select companion to
-- CheckButton. Each option renders as one CheckButton row; picking one checks it and
-- clears the rest. Picking fires onSelect(self, key); Select(key) re-points the group
-- without firing (mirrors FilterDropdown's key/label + Select/onSelect contract).
---@class RadioOption
---@field key any       value stored + reported for this option
---@field label string  row text

---@class RadioGroup: Frame
---@field options RadioOption[]  the options, laid out top to bottom
---@field selected any?          initial selected key
---@field header string?         optional heading label above the rows
---@field spacing number         vertical pitch between rows in px (default 32, = CheckButton height)
---@field width number           group width in px (default 180)
---@field onSelect fun(self: RadioGroup, key: any)?  fired when the user picks a different option
---@field _buttons CheckButton[]  per-option checkboxes, index-aligned to `options`
---@field _selected any?          current selected key
local RadioGroup = Class(Frame, function(self)
  self._buttons = {}
  self._selected = self.selected

  -- optional heading; when present, the rows start one pitch below it
  local top = 0
  if self.header then
    Label:new{
      parent   = self,
      text     = self.header,
      color    = "text",
      position = { TopLeft = {self, ui.edge.TopLeft, 0, 0} },
    }
    top = -self.spacing
  end

  for i, opt in ipairs(self.options) do
    local key = opt.key
    local cb = CheckButton:new{
      parent   = self,
      text     = opt.label,
      OnToggle = function() self:_pick(key) end,
    }
    cb:SetPoint("TOPLEFT", self, "TOPLEFT", 0, top - (i - 1) * self.spacing)
    self._buttons[i] = cb
  end

  self:_apply()
  self:Size(self.width, -top + #self.options * self.spacing)
end, {
  type    = "Frame",
  spacing = 32,
  width   = 180,
  options = {},
})
ui.RadioGroup = RadioGroup

-- Reflect the current selection onto the checkboxes — exactly one stays checked.
function RadioGroup:_apply()
  for i, opt in ipairs(self.options) do
    self._buttons[i]:Checked(self._selected == opt.key)
  end
end

-- User clicked a row. A radio can't be unchecked by re-clicking, so always re-select
-- (the checkbox template auto-toggled it — _apply corrects the visual), and fire
-- onSelect only when the selection actually changed.
---@param key any
function RadioGroup:_pick(key)
  local changed = self._selected ~= key
  self._selected = key
  self:_apply()
  if changed and self.onSelect then self:onSelect(key) end
end

-- Get the selected key, or set it programmatically (no onSelect fired).
---@param key any?
---@return any|RadioGroup
function RadioGroup:Select(key)
  if key == nil then return self._selected end
  self._selected = key
  self:_apply()
  return self
end
