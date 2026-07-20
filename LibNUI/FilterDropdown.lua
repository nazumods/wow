---@type LibNUI_AddOn
local ns = select(2, ...)
local ui = ns.ui
local insert, max = table.insert, math.max
local UIParent = UIParent
local Class = ns.lua.Class
local Frame, Label, Texture, Button = ui.Frame, ui.Label, ui.Texture, ui.Button

-- A compact select control: a labelled button that drops an attached panel of
-- options. The panel hangs flush under the button's left edge and is never
-- narrower than it (widening to fit a long option label), and the option text
-- shares the button label's x-inset, so button and menu read as one control.
-- On open, the current selection renders gold; disabled options render grey and
-- are inert. Picking a new option updates the button label and fires
-- `onSelect(self, key)`. The menu closes on Esc (consumed, so a parent window
-- stays open), on any click outside the control, and when the dropdown itself
-- hides; at most one menu is open at a time.

-- Shared x-inset for the button label and the option labels, so the menu text
-- sits exactly under the button text.
local PAD_X = 8
local ROW_H = 20
local GREY = {0.53, 0.53, 0.53, 1}    -- disabled option text
local FILL = {0.05, 0.05, 0.06, 0.95} -- panel fill inside the 1px divider border
-- Minimal scrollbar arrow: already points down and is a neutral grey.
local CHEVRON = "UI-HUD-ActionBar-PageDownArrow-Disabled"

-- At most one dropdown menu is open at a time; opening one closes any other.
local openOne

---@class FilterDropdown: Frame
---@field options   table[]  list of `{ key, label, enabled? }` option specs (enabled defaults true)
---@field selected  any?     key of the initially selected option
---@field onSelect  fun(self: FilterDropdown, key: any)?  fired when the selection changes
---@field width     number   button width
---@field menuWidth number   minimum menu width (the menu is never narrower than the button and widens to fit its longest option)
---@field maxMenuHeight number  cap (px) beyond which the option panel scrolls instead of growing (default 400)
---@field bordered  boolean? draw a framed background + 1px border (matches toggle buttons)
---@field button    Button
---@field label     Label
---@field chevron   Texture  down arrow on the button's right edge; flipped while the menu is open
---@field menu      Frame    the option panel (built once; rows are pooled + relaid by _layoutMenu)
---@field _rows     Frame[]  pooled option row frames (each carries a `.label` and hover `.background`); reused across SetOptions, surplus hidden
---@field _scroll   ScrollFrame?  lazily built viewport, present only once an option count exceeds `maxMenuHeight` (the flat layout has none)
---@field _menuContent Frame?  the scroll viewport's row host (paired with `_scroll`)
local FilterDropdown = Class(Frame, function(self)
  if self.bordered then
    Texture:new{ parent = self, layer = ui.layer.Background, position = { All = true }, color = "divider" }
    Texture:new{
      parent = self, layer = ui.layer.Border, color = FILL,
      position = { TopLeft = {1, -1}, BottomRight = {-1, 1} },
    }
  end
  self.button = Button:new{
    parent   = self,
    position = { All = true },
    glow     = false,
    OnClick  = function() self:_toggleMenu() end,
  }
  self.chevron = Texture:new{
    parent   = self.button,
    layer    = ui.layer.Artwork,
    atlas    = CHEVRON,
    position = { Right = {-6, 0}, Width = 12, Height = 12 },
  }
  self.label = Label:new{
    parent   = self.button,
    text     = self:labelFor(self.selected),
    justifyH = ui.edge.Left,
    wordWrap = false,
    position = { Left = {PAD_X, 0}, Right = {self.chevron, ui.edge.Left, -2, 0} },
  }
  self:_buildMenu()
  -- The menu is parented to UIParent (a clipping ancestor, e.g. a ScrollFrame,
  -- must not cut it off), so when the dropdown or one of its ancestors hides,
  -- the menu must be taken down explicitly or it would outlive the view.
  self:SetScript("OnHide", function() self:_closeMenu() end)

  self:Width(self.width)
  self:Height(ROW_H)
end, {
  options       = {},
  width         = 96,
  menuWidth     = 0,
  maxMenuHeight = 400,
  bordered      = false,
})
ui.FilterDropdown = FilterDropdown

-- Build the option panel ONCE: a bordered frame hanging flush under the button's left edge,
-- with its Esc / click-away handling. The option ROWS + panel size are (re)built by _layoutMenu,
-- which pools the rows — so SetOptions can swap the whole option list without recreating the
-- panel or leaking row frames.
function FilterDropdown:_buildMenu()
  local menu = Frame:new{
    parent   = UIParent,
    theme    = self.theme,
    strata   = "DIALOG",
    position = { TopLeft = {self, ui.edge.BottomLeft, 0, -2} },
  }
  menu:Hide()
  -- Swallow clicks anywhere on the panel (e.g. on a disabled option) so they
  -- can't fall through to whatever sits underneath.
  menu:EnableMouse(true)
  Texture:new{ parent = menu, layer = ui.layer.Background, position = { All = true }, color = "divider" }
  Texture:new{
    parent = menu, layer = ui.layer.Border, color = FILL,
    position = { TopLeft = {1, -1}, BottomRight = {-1, 1} },
  }
  self.menu = menu
  self._rows = {}

  -- Esc closes (only) the open menu: consuming the key stops it from also closing a
  -- parent window. Other keys propagate so bindings still work while the menu is up.
  menu:SetScript("OnKeyDown", function(_, key)
    if key == "ESCAPE" then
      menu:SetPropagateKeyboardInput(false)
      self:_closeMenu()
    else
      menu:SetPropagateKeyboardInput(true)
    end
  end)
  -- Any mouse-down outside the control closes the menu (GLOBAL_MOUSE_DOWN is only
  -- registered while open). A down on the button itself is left alone: the button's
  -- own click toggles the menu closed on release.
  menu:SetScript("OnEvent", function()
    if not (menu:IsMouseOver() or self:IsMouseOver()) then self:_closeMenu() end
  end)

  self:_layoutMenu()
end

-- Acquire (reuse-or-create) pooled row `i` and point it at `opt`: re-parent + re-anchor it under
-- `rowParent`, set its label, reset the hover fill, show it, and (re)wire its click. Rewiring
-- every layout is required — a pooled row still carries the PREVIOUS option's closures, so a
-- SetOptions swap must recapture the current `opt`. A disabled option gets an inert row (no
-- hover/click scripts). New rows append sequentially, so `self._rows[i]` and the pool grow in step.
---@param i integer
---@param opt table
---@param rowParent Frame
---@param firstY number
---@param needsScroll boolean
---@return Frame
function FilterDropdown:_row(i, opt, rowParent, firstY, needsScroll)
  local row = self._rows[i]
  if not row then
    row = Frame:new{ parent = rowParent, background = {1, 1, 1, 0} }
    row.label = Label:new{
      parent = row, justifyH = ui.edge.Left, wordWrap = false,
      position = { Left = {PAD_X - 1, 0}, Right = {-PAD_X, 0} },
    }
    insert(self._rows, row)
  end
  row:Parent(rowParent)
  row:ClearAllPoints()
  row:Position{
    TopLeft = i == 1 and {needsScroll and 0 or 1, firstY} or {self._rows[i - 1], ui.edge.BottomLeft},
    Right   = {rowParent, ui.edge.Right, needsScroll and 0 or -1, 0},
    Height  = ROW_H,
  }
  row.label:Text(opt.label)
  row.background:Color(1, 1, 1, 0)
  local enabled = opt.enabled ~= false
  row:SetScript("OnEnter", enabled and function() row.background:Color(1, 1, 1, 0.15) end or nil)
  row:SetScript("OnLeave", enabled and function() row.background:Color(1, 1, 1, 0) end or nil)
  row:SetScript("OnMouseUp", enabled and function()
    self:_closeMenu()
    if self.selected == opt.key then return end
    self:Select(opt.key)
    if self.onSelect then self:onSelect(opt.key) end
  end or nil)
  row:Show()
  return row
end

-- (Re)build the option rows and size the panel for the current `self.options`, reusing pooled
-- rows (a SetOptions swap reuses frames instead of leaking them) and hiding the surplus. A list
-- taller than `maxMenuHeight` (e.g. a full category taxonomy) caps the panel height and scrolls
-- (rows parent to a lazily built ScrollFrame content, a gutter reserved for the scrollbar);
-- shorter lists keep the flat, direct-child layout so existing consumers render pixel-identically.
-- The scroll container is built once on first need and shown/hidden as the count crosses the cap;
-- rows re-parent between the flat panel and the scroll content across that transition.
function FilterDropdown:_layoutMenu()
  local fullH = #self.options * ROW_H
  local needsScroll = fullH > self.maxMenuHeight
  if needsScroll and not self._scroll then
    self._scroll = ui.ScrollFrame:new{
      parent = self.menu, scrollbar = true,
      position = { TopLeft = {1, -1}, BottomRight = {-1, 1} },
    }
    self._menuContent = Frame:new{ parent = self._scroll, position = { Size = {1, 1} } }
    self._scroll:Child(self._menuContent)
  end
  local rowParent, firstY, gutter
  if needsScroll then
    self._scroll:Show()
    rowParent, firstY, gutter = self._menuContent, 0, self._scroll.scrollbarWidth or 16
  else
    if self._scroll then self._scroll:Hide() end
    rowParent, firstY, gutter = self.menu, -1, 0
  end

  local widest = 0
  for i, opt in ipairs(self.options) do
    local row = self:_row(i, opt, rowParent, firstY, needsScroll)
    widest = max(widest, row.label:UnboundedWidth())
  end
  -- Hide the pooled rows this option set didn't use (a shorter list than a prior one).
  for i = #self.options + 1, #self._rows do self._rows[i]:Hide() end

  local menuW = max(self.width, self.menuWidth, widest + 2 * PAD_X + 2) + gutter
  self.menu:Width(menuW)
  if needsScroll then
    self._menuContent:Width(menuW - 2 - gutter)
    self._menuContent:Height(fullH)
    self.menu:Height(self.maxMenuHeight + 2)
    self._scroll:Refresh()
  else
    self.menu:Height(fullH + 2)
  end
end

-- Open this menu, first closing any other dropdown's menu (only one open at a
-- time), recolor the rows for the current selection, and capture the keyboard
-- so Esc can close it.
function FilterDropdown:_openMenu()
  if openOne and openOne ~= self then openOne:_closeMenu() end
  openOne = self
  for i, opt in ipairs(self.options) do
    self._rows[i].label:Color(
      opt.enabled == false and GREY or (opt.key == self.selected and "header" or "text"))
  end
  self.chevron:Rotation(math.pi)
  if self._scroll then self._scroll:VerticalScroll(0) end   -- a scrolling menu re-opens at the top
  self.menu:EnableKeyboard(true)
  self.menu:SetPropagateKeyboardInput(true)
  self.menu:registerEvent("GLOBAL_MOUSE_DOWN")
  self.menu:Show()
end

-- Close this menu and release the keyboard and mouse watch.
function FilterDropdown:_closeMenu()
  self.chevron:Rotation(0)
  self.menu:EnableKeyboard(false)
  self.menu:unregisterEvent("GLOBAL_MOUSE_DOWN")
  self.menu:Hide()
  if openOne == self then openOne = nil end
end

function FilterDropdown:_toggleMenu()
  if openOne == self then self:_closeMenu() else self:_openMenu() end
end

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
  self.label:Text(self:labelFor(key))
  return self
end

-- Replace the option list and re-lay-out the drop menu. The panel is built once at construction
-- and its rows are pooled, so changing what a live dropdown offers goes through here: it closes
-- any open menu, swaps `options`, and re-runs the layout (reusing row frames, recomputing the
-- flat/scrolling layout for the new count). The selection resolves to `selected` when it's a
-- valid key of the new list, else the current key if it survives, else the first option — and
-- the button label refreshes to match (without firing `onSelect`, like Select). Used when a
-- dropdown is repointed at a subject with a different option set (e.g. the weapon look-builder
-- re-scoping to another class's weapon types).
---@param options table[]  new `{ key, label, enabled? }` specs
---@param selected any?  preferred key to select; ignored if absent from `options`
---@return FilterDropdown
function FilterDropdown:SetOptions(options, selected)
  self:_closeMenu()
  self.options = options
  self:_layoutMenu()
  if selected == nil or self:labelFor(selected) == "" then
    selected = self:labelFor(self.selected) ~= "" and self.selected or (options[1] and options[1].key)
  end
  return self:Select(selected)
end
