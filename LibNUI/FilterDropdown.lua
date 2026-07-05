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
---@field bordered  boolean? draw a framed background + 1px border (matches toggle buttons)
---@field button    Button
---@field label     Label
---@field chevron   Texture  down arrow on the button's right edge; flipped while the menu is open
---@field menu      Frame    the option panel
---@field _rows     Frame[]  option row frames (each carries a `.label` and hover `.background`)
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
  options   = {},
  width     = 96,
  menuWidth = 0,
  bordered  = false,
})
ui.FilterDropdown = FilterDropdown

-- Build the option panel: bordered like a bordered button, hanging flush under
-- the button's left edge, sized to the wider of the button and its options.
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
  local widest = 0
  for i, opt in ipairs(self.options) do
    local row = Frame:new{
      parent     = menu,
      background = {1, 1, 1, 0},
      position   = {
        TopLeft = i == 1 and {1, -1} or {self._rows[i - 1], ui.edge.BottomLeft},
        Right   = {menu, ui.edge.Right, -1, 0},
        Height  = ROW_H,
      },
    }
    row.label = Label:new{
      parent   = row,
      text     = opt.label,
      justifyH = ui.edge.Left,
      wordWrap = false,
      position = { Left = {PAD_X - 1, 0}, Right = {-PAD_X, 0} },
    }
    if opt.enabled ~= false then
      row:SetScript("OnEnter", function() row.background:Color(1, 1, 1, 0.15) end)
      row:SetScript("OnLeave", function() row.background:Color(1, 1, 1, 0) end)
      row:SetScript("OnMouseUp", function()
        self:_closeMenu()
        if self.selected == opt.key then return end
        self:Select(opt.key)
        if self.onSelect then self:onSelect(opt.key) end
      end)
    end
    widest = max(widest, row.label:UnboundedWidth())
    insert(self._rows, row)
  end
  menu:Width(max(self.width, self.menuWidth, widest + 2 * PAD_X + 2))
  menu:Height(#self.options * ROW_H + 2)

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
