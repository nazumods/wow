---@type Warbandeer
local ns = select(2, ...)
local ui = ns.ui
local Class, Frame = ns.lua.Class, ui.Frame

-- Warbandeer's Collected view: a frame around the sibling Collected addon's own `CollectedPanel`,
-- and nothing else.
--
-- This file used to be ~550 lines that reproduced that panel — the Armor/Weapons toggle, both filter
-- strips, the counter and ★ tally with their hover frames, both scroll containers, `SetMode`,
-- `_ensureWeapons`, `_applyStripX`, `_chromeWidth`, `_fitToGrid`, the empty state, and three
-- cross-addon listeners. Only the grid CLASSES were shared, so every one of those existed twice and
-- the two copies drifted: the widths came apart, and the same bug had to be found and fixed in both
-- places. Collected is the source of truth and this view consumes it, so the panel is built there
-- and we host it.
--
-- All the per-call version guards this file used to carry are gone with it. Collected is an
-- OptionalDep on its own release cadence, so every reach across the boundary was individually
-- defended; now there is exactly one thing to check — does this Collected publish `CollectedPanel` —
-- and it gates registering the view at all (see the bottom of the file), the same way the old code
-- gated on `DataView`.

---@class CollectedView: Frame
---@field panel CollectedPanel  the grids + chrome, owned by Collected's controls/CollectedPanel.lua
local CollectedView = Class(Frame, function(self)
  -- Views are built lazily (MainWindow:getView), so reaching this constructor IS the first click on
  -- Collected in `/wb` — the wait the user actually feels. Later clicks only re-render (OnBeforeShow).
  WarbandeerCollectedApi.prof:Begin("wb-build")

  self.panel = WarbandeerCollectedApi.CollectedPanel:new{
    parent = self,
    position = { TopLeft = {0, 0} },
    -- No lock column and no lockout side-panel here — those stay in `/collected`'s own window.
    lockouts = false,
    -- Anchor the hover InfoTip on the configured side (shared with Overview's set cells).
    infoTipAnchor = ns.InfoTipPosition,
    -- Prefix the profiler's Armor/Weapons swap runs, so the same toggle is timed apart in the two
    -- hosts — a slow one beside a fast one is itself the finding.
    profPrefix = "wb-",
    onSized = function(p) self:_fit(p) end,
  }
  self:_fit(self.panel)
  WarbandeerCollectedApi.prof:Finish(self.panel.grid)
end, {})
CollectedView.name = "collected"
CollectedView._title = "Collected"

---Size the view to the panel, then let the main window refit around it — otherwise a widened view
---is just clipped one frame further out.
---@param panel CollectedPanel
function CollectedView:_fit(panel)
  self:Width(panel:Width())
  self:Height(panel:Height())
  if ns.MainWindow then ns.MainWindow:Fit() end
end

-- Refresh counts, grid data and the empty state each time the view shows, so a scan run after the
-- view was built is reflected on next open. Every click on Collected after the first lands here
-- rather than in the constructor, so this is the run that says whether re-entering is cheap.
function CollectedView:OnBeforeShow()
  local prof = WarbandeerCollectedApi.prof
  prof:Begin("wb-show")
  self.panel:Render()
  prof:Mark("render")
  prof:Finish(self.panel.active)
end

-- Only surface the view (nav icon, minimap menu, and slash command all derive from ns.views) when
-- the sibling Collected addon supplies the panel — the whole view is its data and now its chrome
-- too. OptionalDeps load before us, so the API global is already populated here when present.
if WarbandeerCollectedApi and WarbandeerCollectedApi.CollectedPanel then
  ns.views.CollectedView = CollectedView
end
