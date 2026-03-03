local ADDON_NAME, ns = ...
local TITLE = C_AddOns.GetAddOnMetadata(ADDON_NAME,"Title")
local min, max = math.min, math.max
local ui = ns.ui
local Class, TitleFrame, ScrollFrame, Label = ns.lua.Class, ui.TitleFrame, ui.ScrollFrame, ui.Label
local DataView = ns.DataView

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
  name = ADDON_NAME,
  title = TITLE,
  position = {
    Center = {},
  },
  special = true,
  level = 580,
})

ns.window = nil
function ns:Open()
  if not ns.window then
    ns.window = MainWindow:new{}
  else
    ns.window:Show()
  end
end

function ns:CompartmentClick(btn) -- buttonName = (LeftButton | RightButton | MiddleButton)
  if btn == "RightButton" then
    ns:Scan()
  else
    self:Open()
  end
end
