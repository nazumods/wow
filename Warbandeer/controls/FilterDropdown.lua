---@type Warbandeer
local ns = select(2, ...)
local ui = ns.ui
local insert = table.insert
local Class, Frame, Label = ns.lua.Class, ui.Frame, ui.Label
local Button, Tooltip = ui.Button, ui.Tooltip
local ColorS = ns.Colors.Strings
local C_GREY, C_END = ColorS.GREY, ColorS.END

-- A compact titlebar filter: a labelled button that drops a menu of options.
-- Disabled options render greyed and are not selectable. Picking a new option
-- updates the button label and fires `onSelect(self, key)`. Used by views that
-- expose a `BuildFilter` (Crafting expansion picker, Overview expansion picker).

-- Inline down-arrow (atlas markup: |A:atlasName:height:width|a). The minimal
-- scrollbar arrow already points down and is a neutral grey, so no rotation/tint.
local CHEVRON = "  |A:UI-HUD-ActionBar-PageDownArrow-Disabled:12:12|a"

---@class FilterDropdown: Frame
---@field options   table[]  list of `{ key, label, enabled? }` option specs (enabled defaults true)
---@field selected  any?     key of the initially selected option
---@field onSelect  fun(self: FilterDropdown, key: any)?  fired when the selection changes
---@field width     number   button width
---@field menuWidth number   dropdown menu width
---@field button    Button
---@field label     Label
---@field menu      Tooltip
local FilterDropdown = Class(Frame, function(self)
  self.button = Button:new{
    parent   = self,
    position = { All = true },
    glow     = false,
    OnClick  = function() self.menu:Toggle() end,
  }
  self.label = Label:new{
    parent   = self.button,
    position = { Center = {} },
    text     = self:labelFor(self.selected) .. CHEVRON,
  }

  local lines = {}
  for _, opt in ipairs(self.options) do
    local enabled = opt.enabled ~= false
    insert(lines, {
      text       = enabled and opt.label or (C_GREY .. opt.label .. C_END),
      background = { 0, 0, 0, 0 },
      onEnter    = function(line) line.background:Color(1, 1, 1, 0.2) end,
      onLeave    = function(line) line.background:Color(1, 1, 1, 0) end,
      onClick    = function()
        if not enabled then return end
        self.menu:Hide()
        if self.selected == opt.key then return end
        self.selected = opt.key
        self.label:Text(opt.label .. CHEVRON)
        if self.onSelect then self:onSelect(opt.key) end
      end,
    })
  end
  self.menu = Tooltip:new{
    position = {
      TopRight = { self, ui.edge.BottomRight, 0, 2 },
      Width    = self.menuWidth,
    },
    lines = lines,
  }

  self:Width(self.width)
  self:Height(20)
end, {
  options   = {},
  width     = 96,
  menuWidth = 120,
})
ns.FilterDropdown = FilterDropdown

-- Display label for an option key (empty string if not found).
---@param key any
---@return string
function FilterDropdown:labelFor(key)
  for _, opt in ipairs(self.options) do
    if opt.key == key then return opt.label end
  end
  return ""
end

-- Point the dropdown at `key` (updates the button label) without firing
-- `onSelect`. Used when a pooled dropdown is reassigned to a new subject.
---@param key any
---@return FilterDropdown
function FilterDropdown:Select(key)
  self.selected = key
  self.label:Text(self:labelFor(key) .. CHEVRON)
  return self
end
