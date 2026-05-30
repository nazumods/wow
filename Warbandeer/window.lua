local ADDON_NAME, ns = ...
local ui = ns.ui
local views = ns.views

-- set up the main addon window
local Class, TitleFrame, Tooltip = ns.lua.Class, ui.TitleFrame, ui.Tooltip
local RaceView, SummaryView, GearView, DetailView = views.RaceView, views.SummaryView, views.GearView, views.DetailView
local RoleView, Overview = views.RoleView, views.Overview

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
end, {
  name = ADDON_NAME,
  title = ADDON_NAME,
  position = {
    Center = {},
  },
  special = true,
  level = 600,
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
