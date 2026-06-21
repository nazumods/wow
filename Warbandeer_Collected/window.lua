---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local min, max = math.min, math.max
local Class, TitleFrame, ScrollFrame, Label = ns.lua.Class, ui.TitleFrame, ui.ScrollFrame, ui.Label
local Frame, Button, Texture = ui.Frame, ui.Button, ui.Texture
local DataView = ns.DataView

-- Raid-order toggle border: muted when oldest-first, gold once newest-first.
local SORT_IDLE   = {0.28, 0.28, 0.32, 1}
local SORT_ACTIVE = {0.85, 0.65, 0.13, 1}

---Top-level Collected window: titled frame holding the DataView grid and a sets counter.
---@class CollectedWindow: TitleFrame
---@field data DataView the sets-by-class grid
---@field scroll ScrollFrame scroll container for the grid's row area
---@field counter Label "collected / total" sets counter
---@field wantedCount Label running "★ N" wanted-set count
---@field _sortBorder Texture raid-order toggle border (gold once newest-first)
---@field _sortLabel Label raid-order toggle caption (OLDEST/NEWEST FIRST)
---@field _wantedBorder Texture "wanted only" filter border (gold while active)
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
  -- Running wanted-set count, gold, to the right of the sets counter.
  self.wantedCount = Label:new{
    parent = self,
    position = {
      Left = {self.counter, ui.edge.Right, 16, 0},
    },
    fontObj = "GameFontNormalLarge",
    color = SORT_ACTIVE,
  }

  -- Title-bar toggles, right-to-left from the close button: raid-order, then a
  -- "wanted only" filter. A small framed button each; gold border when active.
  local function titleToggle(rightOf, text, active, onClick)
    local box = Frame:new{
      parent = self.titlebar,
      position = { Right = {rightOf, ui.edge.Left, -4, 0}, Width = 96, Height = 20 },
    }
    local border = Texture:new{
      parent = box, layer = ui.layer.Background,
      position = { All = true }, color = active and SORT_ACTIVE or SORT_IDLE,
    }
    Texture:new{
      parent = box, layer = ui.layer.Border, color = {0.05, 0.05, 0.06, 0.92},
      position = { TopLeft = {1, -1}, BottomRight = {-1, 1} },
    }
    local btn = Button:new{ parent = box, position = { All = true }, glow = false, OnClick = onClick }
    local label = Label:new{
      parent = btn, fontObj = "GameFontNormalSmall", justifyH = ui.justify.Center,
      position = { Left = {6, 0}, Right = {-6, 0} }, text = text,
    }
    return border, label, box
  end

  local sortBox
  self._sortBorder, self._sortLabel, sortBox = titleToggle(self.closeButton, "NEWEST FIRST", true, function()
    local rev = self.data:ToggleOrder()
    self._sortLabel:Text(rev and "NEWEST FIRST" or "OLDEST FIRST")
    self._sortBorder:Color(rev and SORT_ACTIVE or SORT_IDLE)
  end)

  self._wantedBorder = titleToggle(sortBox, "WANTED ONLY", false, function()
    local on = self.data:ToggleWantedOnly()
    self._wantedBorder:Color(on and SORT_ACTIVE or SORT_IDLE)
  end)

  self:RefreshWanted()
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

---Refresh the running wanted-set count in the header.
function MainWindow:RefreshWanted()
  self.wantedCount:Text("★ " .. ns:WantedCount())
end

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
