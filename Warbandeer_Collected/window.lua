---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local min, max = math.min, math.max
local Class, TitleFrame, ScrollFrame, Label = ns.lua.Class, ui.TitleFrame, ui.ScrollFrame, ui.Label
local DataView = ns.DataView

---Top-level Collected window: titled frame holding the DataView grid and a sets counter.
---@class CollectedWindow: TitleFrame
---@field data DataView the sets-by-class grid
---@field scroll ScrollFrame scroll container for the grid's row area
---@field counter Label "collected / total" sets counter
local MainWindow = Class(TitleFrame, function(self)
  local w = 110

  self.data = DataView:new{
    parent = self,
    position = {
      TopLeft = {self.titlebar, ui.edge.BottomLeft, 2, -2},
      TopRight = {self.titlebar, ui.edge.BottomRight, -2, -2},
    },
  }
  w = max(w, self.data:Width() + 4)

  self.scroll = ScrollFrame:new{
    parent = self,
    position = {
      TopLeft = {self.titlebar, ui.edge.BottomLeft, 2, -6 - self.data.headerHeight},
      BottomRight = {self, ui.edge.BottomRight, -2, 2},
    },
  }
  self.scroll:Child(self.data.rowArea)

  local counterLabel = Label:new{
    parent = self,
    position = {
      TopLeft = {self.titlebar, ui.edge.BottomLeft, 15, -12},
    },
    text = "Sets:",
  }
  self.counter = Label:new{
    parent = self,
    position = {
      Left = {counterLabel, ui.edge.Right, 5, 0},
    },
    fontObj = "GameFontNormalLarge",
    color = WHITE_FONT_COLOR,
    text = ns.db.collected .. " / " .. ns.db.total,
  }

  self:Height(34 + min(500, self.data:Height()))
  self:Width(w)
end, {
  name = ns._NAME,
  title = ns._TITLE,
  position = {
    Center = {},
  },
  special = true,
  level = 580,
})

---@class Warbandeer_Collected
---@field window CollectedWindow? main window (nil until first opened)
ns.window = nil
---Open the main window, creating it on first use.
function ns:Open()
  if not ns.window then
    ns.window = MainWindow:new{}
  else
    ns.window:Show()
  end
end

---Addon-compartment click handler: right-click rescans, anything else opens the window.
---@param btn string "LeftButton"|"RightButton"|"MiddleButton"
function ns:CompartmentClick(btn) -- buttonName = (LeftButton | RightButton | MiddleButton)
  if btn == "RightButton" then
    ns:Scan()
  else
    self:Open()
  end
end
