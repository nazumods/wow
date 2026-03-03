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
  local options = {}

  for _, c in pairs(ns.views) do
    local v = c:new{
      parent = self,
      position = {
        TopLeft = {3, -30},
        Hide = true,
      },
    }
    self.views[v.name] = v

    table.insert(options, {
        text = v._title,
        background = {0, 0, 0, 0},
        onEnter = function(line) line.background:Color(1, 1, 1, 0.2) end,
        onLeave = function(line) line.background:Color(1, 1, 1, 0) end,
        onClick = function() self:view(v.name); self.viewSelector:Hide() end,
    })
  end

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
  if self._view then self._view:Hide() end
  self._view = self.views[name]
  if self._view._title then
    self:Title(ADDON_NAME.." | "..self._view._title)
  else
    self:Title(ADDON_NAME)
  end
  self._view:Show()
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
  self:Open()
  self.MainWindow:view(name)
end

function ns:CompartmentClick() -- buttonName = (LeftButton | RightButton | MiddleButton)
  self:Open()
end
