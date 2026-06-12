local ADDON_NAME = ...
---@type Warbandeer
local ns = select(2, ...)
local ui = ns.ui

-- set up the main addon window
local Class, TitleFrame = ns.lua.Class, ui.TitleFrame
local IconStrip = ns.IconStrip

local MainWindow = Class(TitleFrame, function(self)
  -- Views are constructed lazily on first navigation (see getView), both to keep
  -- the first open cheap and because building every view's widget tree in the
  -- same tick left some FontStrings unrendered on the first UI load of a client
  -- session. Only class metadata (name/_title/_iconRotation) is read up front.
  self.views = {}
  self._viewClasses = {}
  for _, c in pairs(ns.views) do
    self._viewClasses[c.name] = c
  end

  -- Navigation-rail order: ns.viewOrder first, any unlisted view appended (sorted
  -- by title) so the rail order is always deterministic.
  local navViews = {}
  local seen = {}
  local function addNav(c)
    if not c or seen[c.name] then return end
    seen[c.name] = true
    table.insert(navViews, { name = c.name, title = c._title or c.name, iconRotation = c._iconRotation })
  end
  for _, name in ipairs(ns.viewOrder) do addNav(self._viewClasses[name]) end
  local leftovers = {}
  for name, c in pairs(self._viewClasses) do
    if not seen[name] then table.insert(leftovers, c) end
  end
  table.sort(leftovers, function(a, b) return (a._title or a.name) < (b._title or b.name) end)
  for _, c in ipairs(leftovers) do addNav(c) end

  -- Floating icon rail docked just left of the window (replaces the old
  -- titlebar-icon dropdown selector). Clicking a glyph switches view.
  self.iconStrip = IconStrip:new{
    parent = self,
    views = navViews,
    -- direct navigation: let the view reset itself (e.g. Detail re-resolves the
    -- logged-in character) before it is shown
    onSelect = function(name)
      local v = self:getView(name)
      if v.OnNavigate then v:OnNavigate() end
      self:view(name)
    end,
    position = { TopRight = {self, ui.edge.TopLeft, -8, 0} },
  }

  local defaultView = ns.db.settings.defaultView
  if defaultView and ns.viewKeys[defaultView] then
    self:view(ns.viewKeys[defaultView])
  end

  -- Persist position when the user finishes dragging the titlebar. The base
  -- TitleFrame wires the titlebar OnMouseUp to StopMovingOrSizing; wrap it so we
  -- also normalize to a TOPLEFT anchor and save.
  self.titlebar:SetScript("OnMouseUp", function()
    self._widget:StopMovingOrSizing()
    self:SavePosition()
  end)

  -- Anchor by top-left (from the DB, or the computed center on first run) so view
  -- changes grow the window down/right instead of re-centering it.
  self:RestorePosition()
end, {
  name = ADDON_NAME,
  title = ADDON_NAME,
  theme = ns.theme, -- inherited by every widget in the window (views, tables, tooltips)
  position = {
    Center = {},
  },
  special = true,
  level = 600,
  background = {0.11372549019, 0.14117647058, 0.16470588235, 0.92},
})

-- Construct (once) and return the named view. Lazy so opening the window only
-- builds the view actually shown; the rest are built on first navigation.
---@param name string
---@return Frame
function MainWindow:getView(name)
  local v = self.views[name]
  if not v then
    v = self._viewClasses[name]:new{
      parent = self,
      position = {
        TopLeft = {3, -30},
        Hide = true,
      },
    }
    self.views[name] = v
    if v.BuildFilter then
      v._filter = v:BuildFilter(self.titlebar)
      v._filter:ClearAllPoints()
      v._filter:Right(self.closeButton, ui.edge.Left, -4, 0)
      v._filter:Hide()
    end
  end
  return v
end

function MainWindow:view(name)
  if self._view then
    self._view:Hide()
    if self._view._filter then self._view._filter:Hide() end
  end
  self._view = self:getView(name)
  if self._view._title then
    self:Title(ADDON_NAME.." | "..self._view._title)
  else
    self:Title(ADDON_NAME)
  end
  self._view:Show()
  if self._view._filter then self._view._filter:Show() end
  if self.iconStrip then self.iconStrip:SetActive(name) end
  self:Fit()
end

function MainWindow:Fit()
  if not self._view then return end
  -- Capture the top-left corner *before* resizing so the window grows down/right
  -- from a fixed corner. Resizing a center-anchored frame would otherwise expand
  -- symmetrically and appear to re-center on every view switch.
  local w = self._widget
  local left, top = w:GetLeft(), w:GetTop()
  self:Width(self._view:Width()  + 6)
  self:Height(self._view:Height() + 30)
  if left and top then
    w:ClearAllPoints()
    self:TopLeft(UIParent, ui.edge.TopLeft, left - UIParent:GetLeft(), top - UIParent:GetTop())
  end
end

-- Normalize the window to a single TOPLEFT anchor (relative to UIParent) at its
-- current screen position, and persist that offset. Called after a drag and to
-- "freeze" the computed-center position on first run, so subsequent Fit() calls
-- grow the window down/right instead of moving its top-left corner.
function MainWindow:SavePosition()
  local w = self._widget
  local x = w:GetLeft() - UIParent:GetLeft()
  local y = w:GetTop()  - UIParent:GetTop()
  w:ClearAllPoints()
  self:TopLeft(UIParent, ui.edge.TopLeft, x, y)
  ns.db.settings.windowPos = { x = x, y = y }
end

-- Apply the stored top-left anchor. With no stored position, the window is still
-- centered (the construction-time anchor); SavePosition then freezes that center
-- into a TOPLEFT anchor and records it.
function MainWindow:RestorePosition()
  local pos = ns.db.settings.windowPos
  if pos then
    self._widget:ClearAllPoints()
    self:TopLeft(UIParent, ui.edge.TopLeft, pos.x, pos.y)
  else
    self:SavePosition()
  end
end

function ns:Open()
  if not self.MainWindow then
    self.MainWindow = MainWindow:new{}
  end

  self.MainWindow:Show()
  self.MainWindow._view:Show()
end

function ns:view(name)
  local w = self.MainWindow
  if w and w._widget:IsShown() and w._view == w.views[name] then
    w:Hide()
    return
  end
  self:Open()
  -- slash commands are direct navigation too — same view reset as the icon rail
  local v = self.MainWindow:getView(name)
  if v.OnNavigate then v:OnNavigate() end
  self.MainWindow:view(name)
end

function ns:CompartmentClick() -- buttonName = (LeftButton | RightButton | MiddleButton)
  self:Open()
end
