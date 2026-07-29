---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Class, TitleFrame = ns.lua.Class, ui.TitleFrame

-- The standalone `/collected` window: a titled, draggable, position-remembering frame around
-- `ns.CollectedPanel`, and nothing else.
--
-- Everything that used to live here — both grids, both filter strips, the Armor/Weapons toggle, the
-- counter and wanted tally, the scroll containers, `SetMode`, `_ensureWeapons`, `_applyStripX` and
-- the sizing — belongs to the panel now, because Warbandeer's embedded collected view carried a
-- second copy of all of it and the two drifted apart independently. `/collected` is the source of
-- truth and `/wb` consumes it, so the panel lives here and both hosts merely build it. That is what
-- makes the two the same width by construction, rather than by two implementations agreeing.
--
-- What is genuinely ours is host-shaped and nothing more: the titlebar, Escape-closes / `_G`
-- registration (`special`), the remembered position, the theme, and sizing the window around
-- whatever the panel reports through `onSized`.

-- This window must match Warbandeer's embedded collected view 1:1 (size + coloring), so it renders
-- the same shared panel in the same void-dark theme. That theme lives in the main Warbandeer addon
-- and is published on LibNUI's shared `ui.themes` registry; when it isn't loaded (Collected running
-- on its own) we fall back to the LibNUI default and the chrome degrades gracefully.
local function collectedTheme()
  return ui.themes["void-dark"] or ui.themes.dark
end

-- Inset of the panel from the window's edges.
--
-- **3, to match Warbandeer's window, not 2.** `MainWindow:Fit()` there sizes its window to
-- `view:Width() + 6`, so the embedded host puts 6px of slack around the identical panel; at PAD 2
-- this window put 4, and the two came out 853.1 and 855.1 against the same 849.1 panel. Two pixels,
-- but the two windows are meant to be interchangeable and a 2px step is visible on their edges.
-- Changed here rather than in Warbandeer's `Fit`, which all eighteen views share.
local PAD = 3

---Top-level Collected window: a titled frame holding the shared collection panel.
---@class CollectedWindow: TitleFrame
---@field panel CollectedPanel  the grids + chrome, owned by controls/CollectedPanel.lua
local MainWindow = Class(TitleFrame, function(self)
  self.panel = ns.CollectedPanel:new{
    parent = self,   -- inherits the window's theme
    position = { TopLeft = {self.titlebar, ui.edge.BottomLeft, PAD, -PAD} },
    -- This host keeps the armour grid's lock column and the lockout side-panel its name-click
    -- opens; Warbandeer's view doesn't, so lockouts stay a `/collected` feature.
    lockouts = true,
    onSized = function(p) self:_fit(p) end,
  }
  self:_fit(self.panel)
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

---Size the window around the panel.
---
---The panel is anchored **top-left only**, so it sizes itself from its own content and the window
---follows. That is the inverse of what this file used to do: the grids were anchored on both sides,
---so reading a grid's width back just handed the window its own width again — armor's `+ 4` cancelled
---the inset and held still by luck, weapons' `+ 20` left a net +16 and the window crept wider on
---every refit until its columns sat well clear of the right edge.
---@param panel CollectedPanel
function MainWindow:_fit(panel)
  self:Width(panel:Width() + PAD * 2)
  self:Height(self.titlebar:Height() + panel:Height() + PAD * 2)
end

---@class Warbandeer_Collected
---@field window CollectedWindow? main window (nil until first opened)
ns.window = nil

---Open the main window, creating it on first use.
function ns:Open()
  if not ns.window then
    -- The one measurement that can only be taken once per session (`/collected profile` arms it and
    -- opens in the same step for exactly that reason). Begins here rather than inside the class so
    -- the theme resolution and RememberPosition below are inside the run too.
    ns.prof:Begin("open")
    -- Theme the whole window (titlebar included) to match Warbandeer's collected view; the explicit
    -- opaque `background` (in defaults) overrides the theme's alpha-0 `window` token so the surface
    -- stays solid. Resolved here, not in the class defaults, since the void-dark theme registers
    -- only once Warbandeer has loaded.
    ns.window = MainWindow:new{ theme = collectedTheme() }
    ns.window:RememberPosition(ns.db.windowPos)   -- restore + persist the user's dragged position
    ns.prof:Mark("position")
    ns.prof:Finish(ns.window.panel.grid)
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
