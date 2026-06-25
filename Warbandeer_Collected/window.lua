---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local min, max = math.min, math.max
local Class, TitleFrame, ScrollFrame, Label = ns.lua.Class, ui.TitleFrame, ui.ScrollFrame, ui.Label
local Frame, Button, Texture = ui.Frame, ui.Button, ui.Texture
local DataView = ns.DataView

-- This window must match Warbandeer's embedded collected view 1:1 (size + coloring),
-- so it renders the same shared DataView grid and counter/toggle chrome in the same
-- void-dark theme. That theme lives in the main Warbandeer addon and is published on
-- LibNUI's shared `ui.themes` registry; when it isn't loaded (Collected running on
-- its own) we fall back to the LibNUI default and the chrome degrades gracefully.
local function collectedTheme()
  return ui.themes["void-dark"] or ui.themes.dark
end

---Top-level Collected window: titled frame holding the DataView grid and a sets counter.
---@class CollectedWindow: TitleFrame
---@field data DataView the sets-by-class grid
---@field scroll ScrollFrame scroll container for the grid's row area
---@field counter Label "Sets: collected / total" counter (shrunk in PTR mode)
---@field wantedCount Label running "★ N" wanted-set count
---@field _sortBorder Texture raid-order toggle border (gold once newest-first)
---@field _sortLabel Label raid-order toggle caption (OLDEST/NEWEST FIRST)
---@field _wantedBorder Texture "wanted only" filter border (gold while active)
---@field _ptrBorder Texture live/PTR toggle border (gold while in PTR mode)
local MainWindow = Class(TitleFrame, function(self)
  -- The window is themed in `ns:Open` (so the titlebar inherits it too); read it back
  -- here for the chrome. Dark's `header` token is the same gold, so the toggles still
  -- read as on/off when the void-dark theme isn't loaded.
  local theme = self:Theme()
  local gold, divider = theme.colors.gold or theme.colors.header, theme.colors.divider
  local titleFont, caps = theme.fonts.title, theme.fonts.caps
  local w = 110

  self.data = DataView:new{
    parent = self,                           -- inherits the window's theme
    position = {
      TopLeft = {self.titlebar, ui.edge.BottomLeft, 2, -2},
      TopRight = {self.titlebar, ui.edge.BottomRight, -2, -2},
    },
    colInfo = DataView.BuildColInfo(false),  -- windowed: includes the lock column
    -- Refresh this window's wanted tally after a Shift-click toggle in the grid.
    onWantedToggle = function() self:RefreshWanted() end,
  }
  w = max(w, self.data:Width() + 4)

  self.scroll = ScrollFrame:new{
    parent = self,
    position = {
      TopLeft = {self.titlebar, ui.edge.BottomLeft, 2, -2 - self.data.headerHeight},
      BottomRight = {self, ui.edge.BottomRight, -2, 2},
    },
  }
  self.scroll:Child(self.data.rowArea)

  -- Counter rides the grid's header row, over the group-name column and in line with
  -- the class icons (matches the embedded view); gold wanted tally to its right.
  local hdrPad = (self.data.headerHeight - (titleFont and titleFont[2] or 14)) / 2
  self.counter = Label:new{
    parent = self, fontInfo = titleFont, color = theme.colors.text,
    position = { TopLeft = {self.data, ui.edge.TopLeft, 2, -hdrPad} },
    text = "",
  }
  self.wantedCount = Label:new{
    parent = self, fontInfo = titleFont, color = gold,
    position = { Left = {self.counter, ui.edge.Right, 16, 0} },
    text = "",
  }

  -- Title-bar toggles, right-to-left from the close button: raid-order, "wanted only",
  -- PTR preview. Same framed-button styling as the embedded view's BuildFilter. `gap`
  -- is the spacing to the frame on its right (defaults to the inter-button gap); the
  -- first toggle uses a wider gap to leave a draggable strip beside the close button,
  -- so the window can still be grabbed when its left side is covered.
  local function titleToggle(rightOf, text, active, onClick, gap)
    local box = Frame:new{
      parent = self.titlebar,
      position = { Right = {rightOf, ui.edge.Left, gap or -6, 0}, Width = 96, Height = 20 },
    }
    local border = Texture:new{
      parent = box, layer = ui.layer.Background,
      position = { All = true }, color = active and gold or divider,
    }
    Texture:new{
      parent = box, layer = ui.layer.Border, color = {0.05, 0.05, 0.06, 0.92},
      position = { TopLeft = {1, -1}, BottomRight = {-1, 1} },
    }
    local btn = Button:new{ parent = box, position = { All = true }, glow = false, OnClick = onClick }
    local label = Label:new{
      parent = btn, fontInfo = caps and {caps[1], 10} or nil, justifyH = ui.justify.Center,
      position = { Left = {8, 0}, Right = {-8, 0} }, text = text,
    }
    return border, label, box
  end

  local sortBox
  self._sortBorder, self._sortLabel, sortBox = titleToggle(self.closeButton, "NEWEST FIRST", true, function()
    local rev = self.data:ToggleOrder()
    self._sortLabel:Text(rev and "NEWEST FIRST" or "OLDEST FIRST")
    self._sortBorder:Color(rev and gold or divider)
  end, -28)  -- wider gap from the close button → a draggable strip on the right

  local wantedBox, _
  self._wantedBorder, _, wantedBox = titleToggle(sortBox, "WANTED ONLY", false, function()
    local on = self.data:ToggleWantedOnly()
    self._wantedBorder:Color(on and gold or divider)
  end)

  -- Live ⇆ PTR toggle: in PTR mode the grid shows only the upcoming (PTR-only) sets.
  self._ptrBorder = titleToggle(wantedBox, "PTR PREVIEW", false, function()
    local on = self.data:SetPtr(not self.data._ptr)
    self._ptrBorder:Color(on and gold or divider)
    self:RefreshCounter()
  end)

  self:RefreshCounter()
  self:RefreshWanted()
  -- Cap the visible grid at the shared `DataView.MAX_HEIGHT` and size the window with
  -- the same header + cap + margin math as the embedded view, so the two are the same
  -- height (the standalone just adds its titlebar on top).
  local capH = min(self.data.MAX_HEIGHT, self.data.rowArea:Height())
  self:Height(self.titlebar:Height() + self.data.headerHeight + capH + 4)
  self:Width(w)
end, {
  name = ns._NAME,
  title = ns._TITLE,
  -- Match Warbandeer's main window surface (≈ the LibNUI dark window, slightly translucent).
  background = {0.11372549019, 0.14117647058, 0.16470588235, 0.92},
  position = {
    Center = {},
  },
  special = true,
  level = 580,
})

---Refresh the running wanted-set count in the header. The star is drawn from the
---shared WantedIcon atlas (not a literal glyph, which the header font can't render).
function MainWindow:RefreshWanted()
  self.wantedCount:Text(("|A:%s:14:14|a %d"):format(ns.WantedIcon, ns:WantedCount()))
end

---Refresh the counter: "Sets: collected / total" in live mode; in PTR PREVIEW mode the
---grid is only the upcoming sets, so the counter becomes a "+N sets upcoming" tally.
function MainWindow:RefreshCounter()
  if self.data._ptr then
    local seen, n = {}, 0
    for _, grp in ipairs(ns.PtrSets) do
      for _, set in ipairs(grp.sets) do
        if set.id and not seen[set.id] then seen[set.id] = true; n = n + 1 end
      end
    end
    self.counter:Text(("+%d sets upcoming%s"):format(n, ns.PtrBuild and (" · PTR " .. ns.PtrBuild.ptr) or ""))
  else
    self.counter:Text("Sets: " .. ns.db.collected .. " / " .. ns.db.total)
  end
  -- The PTR line (with the build) is longer than the live count, so shrink the counter
  -- font in PTR mode to keep it clear of the class icons (matches the embedded view).
  local titleFont = collectedTheme().fonts.title
  if titleFont then
    self.counter:Font(self.data._ptr and {titleFont[1], 12} or titleFont)
  end
end

-- Live-refresh this window's grid + wanted counter when a rating changes anywhere
-- (e.g. via the shared dressing room). No-op until the window has been opened.
ns:OnRatingsChanged(function()
  if not ns.window then return end
  local grid = ns.window.data
  if grid._wantedOnly then grid.data = grid:GetData(); grid:update()   -- re-filter
  else grid:_refreshMarks() end
  ns.window:RefreshWanted()
end)

---@class Warbandeer_Collected
---@field window CollectedWindow? main window (nil until first opened)
ns.window = nil
---Open the main window, creating it on first use.
function ns:Open()
  if not ns.window then
    -- Theme the whole window (titlebar included) to match Warbandeer's collected view;
    -- the explicit opaque `background` (in defaults) overrides the theme's alpha-0
    -- `window` token so the surface stays solid. Resolved here, not in the class
    -- defaults, since the void-dark theme registers only once Warbandeer has loaded.
    ns.window = MainWindow:new{ theme = collectedTheme() }
    ns.window:RememberPosition(ns.db.windowPos)   -- restore + persist the user's dragged position
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
