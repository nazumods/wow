local _, ns = ...
local ui = ns.ui

local Class = ns.lua.Class
local Frame, Label = ui.Frame, ui.Label
local TopLeft, TopRight = ui.edge.TopLeft, ui.edge.TopRight
local BottomLeft, BottomRight = ui.edge.BottomLeft, ui.edge.BottomRight

---@class TabFrame: Frame
---@field tabBar        Frame                              tab button bar anchored across the top
---@field content       Frame                              content area below the tab bar
---@field tabs          string[]                           label strings passed at construction
---@field tabHeight     number                             height of the tab button bar
---@field tabWidth      number                             width of each tab button
---@field activeColor   number[]                           background color of the selected tab button
---@field inactiveColor number[]                           background color of unselected tab buttons
---@field onSelect      fun(self: TabFrame, index: number)?  called when the selected tab changes
---@field _tabs         Frame[]                            tab button frames (internal)
---@field _panels       Frame[]                            content panel frames (internal)
---@field _selected     number                             currently selected tab index (internal)
local TabFrame = Class(Frame, function(self)
  local tabHeight = self.tabHeight
  local tabWidth  = self.tabWidth
  local tabs      = self.tabs or {}

  -- tab button bar anchored to the top of the frame
  self.tabBar = Frame:new{
    parent   = self,
    position = {
      TopLeft  = {self, TopLeft},
      TopRight = {self, TopRight},
      Height   = tabHeight,
    },
    background = {0, 0, 0, 0.4},
  }

  -- content area fills everything below the tab bar
  self.content = Frame:new{
    parent   = self,
    position = {
      TopLeft     = {self.tabBar, BottomLeft},
      BottomRight = {self, BottomRight},
    },
  }

  self._tabs   = {}
  self._panels = {}

  local prev = nil
  for i, label in ipairs(tabs) do
    -- tab button
    local btn = Frame:new{
      type   = "Button",
      parent = self.tabBar,
      position = prev and {
        TopLeft = {prev, TopRight},
        Height  = tabHeight,
        Width   = tabWidth,
      } or {
        TopLeft = {self.tabBar, TopLeft},
        Height  = tabHeight,
        Width   = tabWidth,
      },
      background = self.inactiveColor,
    }
    btn.label = Label:new{
      parent   = btn,
      text     = label,
      position = { All = true },
      justifyH = "CENTER",
      justifyV = "MIDDLE",
    }
    local idx = i
    btn._widget:SetScript("OnClick", function() self:Select(idx) end)

    -- content panel — hidden until selected
    local panel = Frame:new{
      parent   = self.content,
      position = { All = true },
    }
    panel:Hide()

    self._tabs[i]   = btn
    self._panels[i] = panel
    prev = btn
  end

  if #tabs > 0 then self:Select(1) end
end, {
  tabHeight     = 24,
  tabWidth      = 80,
  activeColor   = {0.20, 0.40, 0.70, 0.90},
  inactiveColor = {0.08, 0.08, 0.08, 0.80},
})
ui.TabFrame = TabFrame

-- Switch to tab at index, hiding the previously visible panel.
---@param index number
---@return TabFrame
function TabFrame:Select(index)
  for i, btn in ipairs(self._tabs) do
    if i == index then
      btn.background:Color(self.activeColor)
      self._panels[i]:Show()
    else
      btn.background:Color(self.inactiveColor)
      self._panels[i]:Hide()
    end
  end
  self._selected = index
  if self.onSelect then self:onSelect(index) end
  return self
end

-- Returns the content Frame for tab at index.
---@param index number
---@return Frame
function TabFrame:Tab(index)
  return self._panels[index]
end

-- Returns the currently selected tab index.
---@return number
function TabFrame:Selected()
  return self._selected
end
