local ADDON_NAME, ns = ...
local ui = ns.ui

-- set up the main addon window
local Class, TitleFrame, Tooltip = ns.lua.Class, ui.TitleFrame, ui.Tooltip

local viewIdx = {"overview", "races", "summary", "gear", "detail", "roles"}

local MainWindow = Class(TitleFrame, function(self)
  -- add the contents
  self.views = {}

  for _, c in pairs(ns.views) do
    local v = c:new{
      parent = self,
      position = {
        TopLeft = {3, -30},
        Hide = true,
      },
    }
    self.views[v.name] = v
    if v.BuildFilter then
      v._filter = v:BuildFilter(self.titlebar)
      v._filter:ClearAllPoints()
      v._filter:Right(self.closeButton, ui.edge.Left, -4, 0)
      v._filter:Hide()
    end
  end

  -- Build selector options in ns.viewOrder; any unlisted view falls to the end
  -- (sorted by title) so the dropdown order is always deterministic.
  local options = {}
  local seen = {}
  local function addOption(v)
    if not v or seen[v.name] then return end
    seen[v.name] = true
    table.insert(options, {
        text = v._title,
        background = {0, 0, 0, 0},
        onEnter = function(line) line.background:Color(1, 1, 1, 0.2) end,
        onLeave = function(line) line.background:Color(1, 1, 1, 0) end,
        onClick = function() self:view(v.name); self.viewSelector:Hide() end,
    })
  end
  for _, name in ipairs(ns.viewOrder) do addOption(self.views[name]) end
  local leftovers = {}
  for name, v in pairs(self.views) do
    if not seen[name] then table.insert(leftovers, v) end
  end
  table.sort(leftovers, function(a, b) return (a._title or a.name) < (b._title or b.name) end)
  for _, v in ipairs(leftovers) do addOption(v) end

  local defaultView = ns.db.settings.defaultView
  if defaultView and viewIdx[defaultView] then
    self:view(viewIdx[defaultView])
  end

  -- view control toolip
  self.viewSelector = Tooltip:new{
    position = {
      TopLeft = {self.titlebar, ui.edge.BottomLeft, 6, 3},
      Width = 60,
    },
    lines = options,
  }
  self.titlebar.icon:SetScript("OnMouseUp", function()
    self.viewSelector:Toggle()
  end)

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
  position = {
    Center = {},
  },
  special = true,
  level = 600,
  background = {0.11372549019, 0.14117647058, 0.16470588235, 0.92},
})

function MainWindow:view(name)
  if self._view then
    self._view:Hide()
    if self._view._filter then self._view._filter:Hide() end
  end
  self._view = self.views[name]
  if self._view._title then
    self:Title(ADDON_NAME.." | "..self._view._title)
  else
    self:Title(ADDON_NAME)
  end
  self._view:Show()
  if self._view._filter then self._view._filter:Show() end
  self:Fit()
end

function MainWindow:Fit()
  if not self._view then return end
  self:Width(self._view:Width()  + 6)
  self:Height(self._view:Height() + 30)
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
  self.MainWindow:view(name)
end

function ns:CompartmentClick() -- buttonName = (LeftButton | RightButton | MiddleButton)
  self:Open()
end
