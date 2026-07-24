---@type Warbandeer_Collected
local ns = select(2, ...)

-- Docks the outfit library and the dressing room onto the collection window a set was opened from
-- (#708) — the standalone /collected window, or the embedded collected view's host (Warbandeer's
-- main window), whichever the click came from. Each panel is made a child of that host and anchored
-- to its edge, so it follows when the host is dragged (the proven look-builder relationship; see the
-- anchor-vs-parentage gotcha in CONTEXT.md, #706). The three lock into one rigid cluster: a panel's
-- own body drag is off and its titlebar is retargeted to drag the HOST, so grabbing any window moves
-- all three together and none can be pulled out of position. Each host persists its own position via
-- its own RememberPosition, so nothing here needs to save a point.

---@class Warbandeer_Collected
---@field DockHost TitleFrame?  the collection window the workspace currently docks onto

local GAP = 6

ns.DockHost = nil

---The top-level window a grid lives in: walk up the wrapper chain to the first TitleFrame (the only
---frames here that carry a `.titlebar`). Standalone → the grid's parent IS the window; embedded →
---the window sits above the host view. Returns nil if the grid isn't inside a window.
---@param grid Frame
---@return TitleFrame?
function ns.GridHost(grid)
  local f = grid.parent
  while f and not f.titlebar do f = f.parent end
  return f
end

---Resolve the effective dock host: remember `preferred` when given, reuse the last host while it's
---still shown, else fall back to the standalone /collected window (opened on demand). Always returns
---a shown TitleFrame.
---@param preferred TitleFrame?
---@return TitleFrame
function ns.ResolveDockHost(preferred)
  if preferred then ns.DockHost = preferred end
  local h = ns.DockHost
  if h and h._widget:IsShown() then return h end
  ns:Open()
  ns.DockHost = ns.window
  return ns.window
end

---Dock a panel onto the host as one locked cluster: reparent it under the host, anchor it to the
---host edge (the library spans the host's width; the room sits to its right), turn off the panel's
---own body drag, and retarget its titlebar to drag the HOST — so grabbing any window moves all three
---together and no panel can be pulled out of position. Re-runnable, so a later open can re-dock onto
---a different host.
---@param panel TitleFrame
---@param kind string  "library" | "room"
---@param host TitleFrame
function ns.DockPanel(panel, kind, host)
  panel._widget:SetParent(host._widget)
  panel._widget:SetClampedToScreen(false)     -- stay welded to the host even off-screen (else it detaches at the edge)
  panel._widget:RegisterForDrag()             -- no independent body drag
  panel.titlebar:setDragTarget(host._widget)  -- the titlebar drags the host → the cluster moves together
  panel._docked = true                        -- the look-builder pane strip reads this to stay locked
  panel._widget:ClearAllPoints()
  if kind == "library" then
    -- Beneath the host, matching its width — share both the left and right edges.
    panel._widget:SetPoint("TOPLEFT",  host._widget, "BOTTOMLEFT",  0, -GAP)
    panel._widget:SetPoint("TOPRIGHT", host._widget, "BOTTOMRIGHT", 0, -GAP)
  else
    -- To the right of the host, sharing the top edge.
    panel._widget:SetPoint("TOPLEFT", host._widget, "TOPRIGHT", GAP, 0)
  end

  -- Clamp the whole cluster to the screen as one unit: the drag moves the host, so extend the host's
  -- clamp rect to cover the panels that stick out past it (the room to its right, both below it).
  -- WoW's clamp-inset signs differ per edge: a POSITIVE right and a NEGATIVE bottom both grow the
  -- rect outward (verified in-game; matches Blizzard's own Blizzard_PTRFeedback / survey frames).
  -- Only the room's own frame is measured, NOT the look-builder pane (AppearancePicker, a toggled
  -- child that juts a further ~PICKERW right when open) — so with the builder open the cluster can be
  -- dragged until that pane alone crosses the right edge. Accepted by design: the pane toggles, and
  -- reserving its width in the clamp would leave a dead gap on the right whenever it's closed.
  local ph = panel._widget:GetHeight()
  local right = (kind == "room") and (GAP + panel._widget:GetWidth()) or 0
  local below = (kind == "library") and (GAP + ph) or math.max(0, ph - host._widget:GetHeight())
  host._clampRight = math.max(host._clampRight or 0, right)
  host._clampBelow = math.max(host._clampBelow or 0, below)
  host._widget:SetClampedToScreen(true)
  host._widget:SetClampRectInsets(0, host._clampRight, 0, -host._clampBelow)
end
