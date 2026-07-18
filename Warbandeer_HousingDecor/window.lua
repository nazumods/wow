---@type Warbandeer_HousingDecor
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local max = math.max
local Class, TitleFrame, Label = ns.lua.Class, ui.TitleFrame, ui.Label
local HousingDecorList = ns.List

-- This window must match Warbandeer's embedded decor view (size + coloring), so it
-- renders the same shared list grid + filter chrome in the same void-dark theme. That
-- theme lives in the main Warbandeer addon on LibNUI's shared `ui.themes`; when it isn't
-- loaded (Housing Decor running standalone) we fall back to the LibNUI default.
local function decorTheme()
  return ui.themes["void-dark"] or ui.themes.dark
end

---Top-level Housing Decor window: titled frame holding the decor list + a collected /
---wanted counter. The list (a windowed list) scrolls internally, so the window is a fixed
---size — no dynamic grid-fitting.
---@class DecorWindow: TitleFrame
---@field list HousingDecorList  the decor list grid
---@field filterStrip Frame  the shared filter chrome row
---@field counter Label  "N / N collected" counter (filter-scoped)
---@field wantedCount Label  running "star N" wanted tally
local MainWindow = Class(TitleFrame, function(self)
  local theme = self:Theme()
  local gold = theme.colors.gold or theme.colors.header
  local titleFont = theme.fonts.title
  local STRIP_H, HEADER_H, GAP = HousingDecorList.STRIP_H, 20, 4
  local TOP = STRIP_H + GAP + HEADER_H   -- filter strip + gap + counter band

  -- The grid fills the body below the strip + counter band, down to the window bottom.
  self.list = HousingDecorList:new{
    parent = self,
    position = {
      TopLeft = { self.titlebar, ui.edge.BottomLeft, 2, -2 - TOP },
      BottomRight = { self, ui.edge.BottomRight, -2, 2 },
    },
    -- Recompute the counter after any filter change (VisibleCounts is filter-scoped).
    onFilterChanged = function() self:RefreshCounter() end,
  }

  -- Shared filter strip just below the titlebar (BuildFilterStrip is a method on the grid).
  self.filterStrip = self.list:BuildFilterStrip(self)
  self.filterStrip:Position({ TopLeft = { self.titlebar, ui.edge.BottomLeft, 2, -2 } })

  -- Counter band between the strip and the grid header.
  self.counter = Label:new{
    parent = self, fontInfo = titleFont, color = theme.colors.text, text = "",
    position = { TopLeft = { self.filterStrip, ui.edge.BottomLeft, 2, -GAP } },
  }
  self.wantedCount = Label:new{
    parent = self, fontInfo = titleFont, color = gold, text = "",
    position = { Left = { self.counter, ui.edge.Right, 16, 0 } },
  }

  -- The gold wanted tally toggles WANTED ONLY on click (a FontString can't take mouse,
  -- so overlay a transparent frame on it).
  local wantedHover = ui.Frame:new{
    parent = self,
    position = {
      TopLeft = { self.wantedCount, ui.edge.TopLeft, -2, 2 },
      BottomRight = { self.wantedCount, ui.edge.BottomRight, 2, -2 },
    },
  }
  wantedHover:EnableMouse(true)
  wantedHover:SetScript("OnMouseUp", function() self.list:ToggleWantedOnly() end)

  self:RefreshCounter()
  self:RefreshWanted()
  self:Width(max(self.filterStrip:Width() + 8, 380))
  self:Height(520)
end, {
  name = ns._NAME,
  title = ns._TITLE,
  -- Match Warbandeer's main window surface (≈ the LibNUI dark window, slightly translucent).
  background = { 0.11372549019, 0.14117647058, 0.16470588235, 0.92 },
  position = { Center = {} },
  special = true,
  level = 580,
})

---Refresh the "N / N collected" counter (owned / shown for the current filter). Guarded
---so the grid's construction-time Render (which fires onFilterChanged before this Label
---exists) is a no-op until the window finishes building.
function MainWindow:RefreshCounter()
  if not self.counter then return end
  local shown, collected = self.list:VisibleCounts()
  self.counter:Text(("%d / %d collected"):format(collected, shown))
end

---Refresh the running wanted tally. The star is drawn from the shared WantedIcon atlas
---(the header font can't render a literal star glyph).
function MainWindow:RefreshWanted()
  self.wantedCount:Text(("|A:%s:14:14|a %d"):format(ns.WantedIcon, ns:WantedCount()))
end

---Re-render the grid + header after a scan rebuilds the snapshot (called by ns:Scan).
function MainWindow:Refresh()
  self.list:RefreshCategoryFilter()   -- rebuild the Category options if this scan first populated them
  self.list:Render()   -- fires onFilterChanged → RefreshCounter
  self:RefreshWanted()
end

-- Live-refresh the open window when a wanted flag changes anywhere (this grid, or a
-- second grid such as Warbandeer's embedded view). No-op until the window is opened.
ns:OnRatingsChanged(function()
  if not ns.window then return end
  ns.window.list:Render()
  ns.window:RefreshWanted()
end)

---@class Warbandeer_HousingDecor
---@field window DecorWindow?  main window (nil until first opened)
ns.window = nil

---Open the main window, creating it on first use.
function ns:Open()
  if not ns.window then
    ns.window = MainWindow:new{ theme = decorTheme() }
    ns.window:RememberPosition(ns.db.windowPos)   -- restore + persist the dragged position
  else
    ns.window:Show()
  end
end

---Addon-compartment click: right-click rescans, anything else opens the window.
---@param btn string "LeftButton"|"RightButton"|"MiddleButton"
function ns:CompartmentClick(btn)
  if btn == "RightButton" then
    ns:Scan()
  else
    self:Open()
  end
end
