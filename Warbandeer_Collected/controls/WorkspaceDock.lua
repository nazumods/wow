---@type Warbandeer_Collected
local ns = select(2, ...)

-- Docks the outfit library and the dressing room onto the collection window a set was opened from
-- (#708) — the standalone /collected window, or the embedded collected view's host (Warbandeer's
-- main window), whichever the click came from. Each panel is made a child of that host and anchored
-- to its edge, so it follows when the host is dragged (the proven look-builder relationship; see the
-- anchor-vs-parentage gotcha in CONTEXT.md, #706). The three lock into one rigid cluster: a panel's
-- own body drag is off and its titlebar is retargeted to drag the HOST, so grabbing any window moves
-- all three together and none can be pulled out of position.
--
-- A drag by a PANEL titlebar saves the host's position from here (#764) — it cannot ride on
-- RememberPosition, because `setDragTarget` moves the host by StartMoving, which fires neither
-- script that hooks (the host's own OnDragStop, the host's own titlebar OnMouseUp). Since #713 a
-- panel titlebar is the EXPECTED way to move the cluster, so the lost-on-reload move was the common
-- case, not an edge one. Both host types answer `SavePosition()`, so no branching is needed here:
-- Warbandeer's MainWindow overrides it, and LibNUI's TitleFrame exposes it (#779) for precisely this
-- — a drag the window class never sees.

---@class Warbandeer_Collected
---@field DockHost TitleFrame?  the collection window the workspace currently docks onto
---@field RefreshDockClamp fun()  recompute the host's clamp rect from the panels currently docked+shown
---@field ShownDockHost fun(): TitleFrame?  the current host if one is already on screen; opens nothing
---@field UndockPanel fun(panel: TitleFrame, kind: string, store: table)  release a panel back to a free-floating window

local GAP = 6
-- How far left of screen centre a never-yet-floated panel's right edge sits (see UndockPanel).
local FLOAT_GAP = 40
local max = math.max

ns.DockHost = nil

-- Every panel this file has docked, by kind. The clamp is recomputed from THESE, filtered to the
-- ones currently shown, rather than accumulated as panels arrive (#764) — `math.max` only ever grew,
-- so closing the room left the host reserving its ~578px for the rest of the session.
local _panels = {}

-- What each host's clamp looked like before we first touched it, so it can be handed back. The host
-- may belong to another addon (Warbandeer's MainWindow), and imposing `SetClampedToScreen(true)` plus
-- our insets on it permanently rewrote a geometry contract that isn't ours to keep (#764).
local _hostClamp = {}

-- Frames whose scripts we've already hooked, kept here rather than as a flag on the frame so a
-- foreign host gains no fields from us at all.
local _hooked = {}

---What the panels docked onto `hostWidget` and currently shown need reserved beyond it.
---@param hostWidget table
---@return number right, number below, boolean any
local function reservedFor(hostWidget)
  local right, below, any = 0, 0, false
  for kind, panel in pairs(_panels) do
    local pw = panel._widget
    -- IsShown, deliberately NOT IsVisible (#767 L-2 changed the room's own checks, not this one).
    -- A panel is a child of the host, so hiding the host makes every panel invisible while their
    -- own flags stay set. Under IsVisible that reads as "no shown panel", which hands the host its
    -- clamp back and drops `_hostClamp` — and nothing re-applies it when the host returns, because
    -- the panel's OnShow never fires (its own flag never changed).
    if pw:IsShown() and pw:GetParent() == hostWidget then
      any = true
      local ph = pw:GetHeight()
      if kind == "room" then
        right = max(right, GAP + pw:GetWidth())
        -- Against the host's CURRENT height, not its height when the room docked: `_fitToGrid`
        -- resizes the host on every filter/sort/PTR change, and a stale measurement here let the
        -- cluster be dragged until the room's bottom went off-screen.
        below = max(below, max(0, ph - hostWidget:GetHeight()))
      else
        below = max(below, GAP + ph)
      end
    end
  end
  return right, below, any
end

---Recompute the dock clamp: extend the current host's rect to cover the panels sticking out past it,
---and give any host we no longer occupy its own clamp back.
---
---WoW's clamp-inset signs differ per edge: a POSITIVE right and a NEGATIVE bottom both grow the rect
---outward (verified in-game; matches Blizzard's own Blizzard_PTRFeedback / survey frames).
---
---Only the room's own frame is measured, NOT the look-builder pane (AppearancePicker, a toggled child
---that juts a further ~PICKERW right when open) — so with the builder open the cluster can be dragged
---until that pane alone crosses the right edge. Accepted by design: the pane toggles, and reserving
---its width would leave a dead gap on the right whenever it's closed.
function ns.RefreshDockClamp()
  -- Hand back any host that no longer carries a shown panel — including one we've since re-docked
  -- away from, which would otherwise keep our insets forever.
  for host, saved in pairs(_hostClamp) do
    local _, _, any = reservedFor(host._widget)
    if not any then
      host._widget:SetClampRectInsets(saved.left, saved.right, saved.top, saved.bottom)
      host._widget:SetClampedToScreen(saved.clamped)
      _hostClamp[host] = nil
    end
  end

  local host = ns.DockHost
  if not host then return end
  local right, below, any = reservedFor(host._widget)
  if not any then return end
  -- Captured before the first write, so what we restore is the host's own setting rather than ours.
  if not _hostClamp[host] then
    local l, r, t, b = host._widget:GetClampRectInsets()
    _hostClamp[host] = { left = l, right = r, top = t, bottom = b,
                         clamped = host._widget:IsClampedToScreen() }
  end
  host._widget:SetClampedToScreen(true)
  host._widget:SetClampRectInsets(0, right, 0, -below)
end

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
---The current dock host **only if one is already on screen** — never opens anything. The half of
---`ResolveDockHost` a caller wants when "no host" is a legitimate answer rather than a reason to
---put a several-hundred-row collection window on screen (#767 L-3).
---@return TitleFrame?
function ns.ShownDockHost()
  local h = ns.DockHost
  -- IsShown, deliberately NOT IsVisible (#767 L-2). A host is top-level, so the two agree except
  -- when the whole UI is hidden — Alt-Z, a cinematic — and under IsVisible that would read as "no
  -- host" and open a SECOND collection window behind the hidden UI.
  if h and h._widget:IsShown() then return h end
end

function ns.ResolveDockHost(preferred)
  if preferred then ns.DockHost = preferred end
  local h = ns.ShownDockHost()
  if h then return h end
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
  -- ...and persist where that drag left the host (#764). Re-hooked on every dock rather than guarded
  -- like the hooks below: `setDragTarget` is a SetScript, so it discards the previous hook chain on
  -- this script — re-hooking leaves exactly one hook, closed over the host a re-dock just switched to.
  panel.titlebar._widget:HookScript("OnMouseUp", function() host:SavePosition() end)
  panel._widget:ClearAllPoints()
  if kind == "library" then
    -- Beneath the host, matching its width — share both the left and right edges.
    panel._widget:SetPoint("TOPLEFT",  host._widget, "BOTTOMLEFT",  0, -GAP)
    panel._widget:SetPoint("TOPRIGHT", host._widget, "BOTTOMRIGHT", 0, -GAP)
  else
    -- To the right of the host, sharing the top edge.
    panel._widget:SetPoint("TOPLEFT", host._widget, "TOPRIGHT", GAP, 0)
  end

  -- Clamp the whole cluster to the screen as one unit: the drag moves the host, so the host's clamp
  -- rect has to cover the panels that stick out past it (the room to its right, both below it).
  _panels[kind] = panel
  -- Showing or hiding a panel changes what has to be reserved, and the host resizing changes how far
  -- the room hangs below it (`_fitToGrid` on every filter/sort/PTR change). Hooked once each, and on
  -- the host generically rather than through either host type's own resize path.
  if not _hooked[panel] then
    _hooked[panel] = true
    panel._widget:HookScript("OnShow", ns.RefreshDockClamp)
    panel._widget:HookScript("OnHide", ns.RefreshDockClamp)
  end
  if not _hooked[host] then
    _hooked[host] = true
    host._widget:HookScript("OnSizeChanged", ns.RefreshDockClamp)
    -- Close the workspace WITH its host (#767 L-2). Panels are children, so hiding the host already
    -- takes them off screen — but their own shown flags stay set, so they silently come back when it
    -- reopens and every "is this open?" test lies about them. That is the actual defect behind the
    -- room returning on the last-picked race: `ShowDressingRoom` asks whether the room is on screen
    -- to decide on a race reset, and by then the reopened host had already made it so. Testing
    -- visibility instead of shown-state does NOT fix that on its own — the state itself has to be
    -- honest, which means really hiding them.
    host._widget:HookScript("OnHide", function()
      for _, p in pairs(_panels) do
        if p._widget:GetParent() == host._widget then p:Hide() end
      end
    end)
  end
  ns.RefreshDockClamp()
end

-- Panels already given their position store back, so a repeated undock doesn't stack another
-- `RememberPosition` OnDragStop hook on the same frame each time.
local _remembered = {}

---Release `panel` from the cluster back into a free-floating window — the exact inverse of
---`DockPanel`. Used when the library is opened with no collection window on screen (#767 L-3): it
---used to force one open through `ResolveDockHost`, putting a several-hundred-row grid behind
---Blizzard's transmog UI when all the user asked for was the library.
---
---`store` revives per-window position persistence, which docking made pointless and #708/#713
---dropped. A panel that has been docked can't simply be re-shown: `DockPanel` reparented it, killed
---its body drag, and pointed its titlebar at the HOST, so all three have to be handed back.
---@param panel TitleFrame
---@param kind string  "library" | "room"
---@param store table  DB-backed point store (e.g. `ns.db.libraryPos`)
function ns.UndockPanel(panel, kind, store)
  _panels[kind] = nil            -- stop counting toward the host's clamp
  local pw = panel._widget
  pw:SetParent(UIParent)
  pw:SetClampedToScreen(true)    -- on its own again, so it should stay on screen on its own
  pw:RegisterForDrag("LeftButton")
  -- Point the titlebar back at THIS window. It also discards the host-saving hook DockPanel put on
  -- this script (#764), which is what we want — there is no host to save any more.
  panel.titlebar:setDragTarget(pw)
  -- Re-apply the remembered point on EVERY undock; docking cleared the anchors, so a panel that
  -- has floated before must be put back where the user left it rather than re-centred.
  pw:ClearAllPoints()
  if store.point then
    pw:SetPoint(store.point, UIParent, store.relPoint, store.x, store.y)
  else
    -- Never floated before: sit LEFT of screen centre rather than dead centre, because the place a
    -- floating library lands is usually on top of Blizzard's transmogrifier — and its 3D character
    -- preview draws straight through ours. That is not fixable by layering: measured in game, our
    -- preview at DIALOG/602 still lost to theirs at MEDIUM/2, because two 3D model scenes do not
    -- order against each other by strata or frame level at all. So the answer is to not overlap.
    -- Only a default; the dragged point is remembered from here on, and SetClampedToScreen keeps
    -- the window on screen if it doesn't fit to the left.
    pw:SetPoint("RIGHT", UIParent, "CENTER", -FLOAT_GAP, 0)
  end
  -- Hooks only once. RememberPosition HookScripts the body's OnDragStop, and hooks accumulate —
  -- calling it on every undock would stack a duplicate save per round trip.
  if not _remembered[panel] then
    _remembered[panel] = true
    panel:RememberPosition(store)
  end
  ns.RefreshDockClamp()          -- hand the host we just left its own clamp back
end
