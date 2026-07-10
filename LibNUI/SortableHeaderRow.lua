---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local Class = ns.lua.Class
local Frame, Label, Texture = ui.Frame, ui.Label, ui.Texture

local ARROW_UP, ARROW_DOWN = "Interface/Buttons/Arrow-Up-Up", "Interface/Buttons/Arrow-Down-Up"

-- A standalone clickable column-header strip for custom lists that aren't built on
-- TableFrame — e.g. a header row above a VirtualList. (TableFrame has its own opt-in
-- sortable columns via colInfo `sortable`; this is its counterpart for grid-less lists.)
-- Clicking a column selects it ascending (or `descFirst`), clicking again flips the
-- direction; the active column shows an arrow and renders in the accent colour.
-- Consumers sort their own data in onSort and re-render.
---@class HeaderColumn
---@field key any        stable identity reported to onSort
---@field label string   header text
---@field width number   column width in px
---@field justifyH string?  label justification (default Left)
---@field descFirst boolean?  first click sorts descending (numeric "biggest first" columns)

---@class SortableHeaderRow: Frame
---@field columns HeaderColumn[]  the columns, laid out left to right
---@field sortKey any?       initially active column key
---@field sortDesc boolean?  initial direction
---@field height number      strip height (default 20, intrinsic)
---@field gap number         px between columns (default 2)
---@field onSort fun(self: SortableHeaderRow, key: any, descending: boolean)?  fired on a user click
---@field _cols table[]  per-column {btn, label, arrow, key}
local SortableHeaderRow = Class(Frame, function(self)
  self:Height(self.height)
  self._cols = {}

  local x = 0
  for _, col in ipairs(self.columns) do
    local key = col.key
    local btn = Frame:new{
      type       = "Button",
      parent     = self,
      background = {1, 1, 1, 0},
      position   = { TopLeft = {self, ui.edge.TopLeft, x, 0}, Size = {col.width, self.height} },
    }
    local label = Label:new{
      parent   = btn,
      text     = col.label,
      color    = "muted",
      justifyH = col.justifyH or ui.justify.Left,
      wordWrap = false,
      position = { Left = {btn, 2, 0}, Right = {btn, -14, 0} },
    }
    local arrow = Texture:new{
      parent   = btn,
      layer    = ui.layer.Artwork,
      path     = ARROW_UP,
      position = { Right = {btn, -1, 0}, Size = {10, 10}, Hide = true },
    }
    btn:SetScript("OnClick", function() self:_click(key, col.descFirst) end)
    btn:SetScript("OnEnter", function() btn.background:Color(1, 1, 1, 0.06) end)
    btn:SetScript("OnLeave", function() btn.background:Color(1, 1, 1, 0) end)
    self._cols[#self._cols + 1] = { btn = btn, label = label, arrow = arrow, key = key }
    x = x + col.width + self.gap
  end

  self:_refresh()
end, {
  type   = "Frame",
  height = 20,
  gap    = 2,
})
ui.SortableHeaderRow = SortableHeaderRow

-- Restyle every column for the current sort state: active = accent + arrow.
function SortableHeaderRow:_refresh()
  for _, c in ipairs(self._cols) do
    local active = c.key == self.sortKey
    c.label:Color(active and "header" or "muted")
    c.arrow:SetShown(active)
    if active then c.arrow:Texture(self.sortDesc and ARROW_DOWN or ARROW_UP) end
  end
end

-- A user clicked a column: same column flips direction, a new column starts at its
-- natural direction (descFirst or ascending). Fires onSort.
---@param key any
---@param descFirst boolean?
function SortableHeaderRow:_click(key, descFirst)
  if self.sortKey == key then
    self.sortDesc = not self.sortDesc
  else
    self.sortKey, self.sortDesc = key, descFirst or false
  end
  self:_refresh()
  if self.onSort then self:onSort(self.sortKey, self.sortDesc) end
end

-- Get the current sort as (key, descending), or set it programmatically (no onSort).
---@param key any?
---@param descending boolean?
---@return any, boolean|SortableHeaderRow
function SortableHeaderRow:Sort(key, descending)
  if key == nil then return self.sortKey, self.sortDesc or false end
  self.sortKey, self.sortDesc = key, descending or false
  self:_refresh()
  return self
end
